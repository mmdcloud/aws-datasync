#!/bin/bash

# Don't use set -e — handle errors explicitly
exec > /var/log/efs-setup.log 2>&1

echo "Setup started at $(date)"

# Wait for background apt processes (unattended-upgrades) to release locks
echo "Waiting for background apt processes to release locks..."
while fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/lib/dpkg/lock >/dev/null 2>&1; do
  echo "Apt lock held, waiting..."
  sleep 3
done

# Install nfs-common with lock timeout and retry
if ! dpkg -l nfs-common &>/dev/null; then
  echo "Installing nfs-common..."
  for i in {1..5}; do
    apt-get update -y && apt-get install -y -o DPkg::Lock::Timeout=120 nfs-common && break
    sleep 5
  done
fi

mkdir -p /mnt/efs

EFS_HOST="${efs_id}.efs.${region}.amazonaws.com"

# Wait for EFS DNS to resolve
echo "Waiting for DNS resolution of $EFS_HOST..."
for i in {1..30}; do
  if getent hosts "$EFS_HOST" >/dev/null 2>&1; then
    echo "DNS resolved: $(getent hosts "$EFS_HOST")"
    break
  fi
  sleep 5
done

# Retry mount up to 30 attempts (EFS mount targets take 60-90s to become available)
for attempt in {1..30}; do
  echo "Mount attempt $attempt..."
  mount -t nfs4 \
    -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport \
    "$EFS_HOST:/" \
    /mnt/efs && break
  sleep 5
done

if ! mountpoint -q /mnt/efs; then
  echo "ERROR: EFS mount failed after 30 attempts. Aborting."
  exit 1
fi

echo "EFS mounted successfully."

# Persist mount in /etc/fstab
if ! grep -q "$EFS_HOST:/" /etc/fstab; then
  echo "$EFS_HOST:/ /mnt/efs nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0" >> /etc/fstab
fi

chown ubuntu:ubuntu /mnt/efs
chmod 777 /mnt/efs

# Generate test files directly on EFS
echo "Generating test files on EFS..."
for i in {1..10}; do
  dd if=/dev/urandom bs=200 count=1 2>/dev/null | base64 > /mnt/efs/file_$i.txt
done

chown -R ubuntu:ubuntu /mnt/efs
chmod -R 777 /mnt/efs

touch /mnt/efs/.setup-complete
echo "Setup complete at $(date). EFS files created:"
ls -la /mnt/efs/