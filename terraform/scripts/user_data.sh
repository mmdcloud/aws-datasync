#!/bin/bash

# Don't use set -e — handle errors explicitly
exec > /var/log/efs-setup.log 2>&1

echo "Setup started at $(date)"

# Disable background apt update timers to avoid lock contention and timeouts without NAT Gateway
systemctl stop apt-daily.timer apt-daily-upgrade.timer >/dev/null 2>&1 || true
systemctl disable apt-daily.timer apt-daily-upgrade.timer >/dev/null 2>&1 || true

# Verify nfs-common / mount.nfs4 helper binary (pre-installed in custom AMI)
if command -v mount.nfs4 >/dev/null 2>&1; then
  echo "mount.nfs4 helper binary verified from AMI."
else
  echo "WARNING: mount.nfs4 helper not found. Attempting install fallback..."
  for i in {1..3}; do
    apt-get update -y && apt-get install -y -o DPkg::Lock::Timeout=120 nfs-common && break || sleep 5
  done
fi

mkdir -p /mnt/efs

EFS_IP="${efs_ip}"
EFS_HOST="${efs_id}.efs.${region}.amazonaws.com"

echo "EFS Mount Target IP: $EFS_IP"
echo "EFS DNS Hostname: $EFS_HOST"

# Mount options for AWS EFS with standard NFSv4.1
MOUNT_OPTS="nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport"

# Retry mount up to 30 attempts (EFS mount targets take 60-90s to become available in AWS)
for attempt in {1..30}; do
  echo "Mount attempt $attempt/30 at $(date)..."

  # Try mounting via direct Mount Target IP first (fastest, immune to DNS delays, 100% private)
  if [ -n "$EFS_IP" ]; then
    echo "Attempting mount via IP: $EFS_IP:/..."
    if mount -t nfs4 -o "$MOUNT_OPTS" "$EFS_IP:/" /mnt/efs; then
      echo "Successfully mounted via IP: $EFS_IP:/"
      MOUNT_SOURCE="$EFS_IP:/"
      break
    fi
  fi

  # Fallback: Try mounting via DNS hostname
  echo "Attempting mount via DNS: $EFS_HOST:/..."
  if mount -t nfs4 -o "$MOUNT_OPTS" "$EFS_HOST:/" /mnt/efs; then
    echo "Successfully mounted via DNS: $EFS_HOST:/"
    MOUNT_SOURCE="$EFS_HOST:/"
    break
  fi

  echo "Mount attempt $attempt failed. Waiting 5s..."
  sleep 5
done

if ! mountpoint -q /mnt/efs; then
  echo "ERROR: EFS mount failed after 30 attempts. Aborting."
  exit 1
fi

echo "EFS mounted successfully on /mnt/efs."

# Persist mount in /etc/fstab
if ! grep -q "/mnt/efs" /etc/fstab; then
  echo "$${MOUNT_SOURCE:-$EFS_HOST:/} /mnt/efs nfs4 $MOUNT_OPTS,_netdev 0 0" >> /etc/fstab
fi

chown ubuntu:ubuntu /mnt/efs
chmod 777 /mnt/efs

# Generate test files directly on EFS
echo "Generating test files on EFS..."
for i in {1..10}; do
  dd if=/dev/urandom bs=200 count=1 2>/dev/null | base64 > /mnt/efs/file_$i.txt
done

sync

chown -R ubuntu:ubuntu /mnt/efs
chmod -R 777 /mnt/efs

sync

touch /mnt/efs/.setup-complete
echo "Setup complete at $(date). EFS files created:"
ls -la /mnt/efs/
