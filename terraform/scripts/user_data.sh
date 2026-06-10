#!/bin/bash

# Don't use set -e — handle errors explicitly
exec > /var/log/efs-setup.log 2>&1

echo "Setup started at $(date)"

# nfs-common is pre-installed on Ubuntu 22.04, but ensure it's present
if ! dpkg -l nfs-common &>/dev/null; then
  apt-get update -y
  apt-get install -y nfs-common
fi

mkdir -p /mnt/efs

# Retry mount up to 5 times (EFS DNS can take a moment after instance start)
for attempt in {1..5}; do
  echo "Mount attempt $attempt..."
  mount -t nfs4 \
    -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport \
    ${efs_id}.efs.${region}.amazonaws.com:/ \
    /mnt/efs && break
  sleep 10
done

if ! mountpoint -q /mnt/efs; then
  echo "ERROR: EFS mount failed after 5 attempts. Aborting."
  exit 1
fi

echo "EFS mounted successfully."

chown ubuntu:ubuntu /mnt/efs
chmod 777 /mnt/efs

# Fix: use dd instead of base64+head to avoid SIGPIPE with set -e
for i in {1..10}; do
  dd if=/dev/urandom bs=200 count=1 2>/dev/null | base64 > /mnt/efs/file_$i.txt
done

chown -R ubuntu:ubuntu /mnt/efs
chmod -R 777 /mnt/efs

touch /mnt/efs/.setup-complete
echo "Setup complete at $(date)"