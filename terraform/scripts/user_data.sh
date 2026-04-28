#!/bin/bash
sudo apt-get update -y
sudo mkdir -p /mnt/efs
sudo apt-get install -y amazon-efs-utils

# Wait long enough for EFS mount target to be available
sleep 90

sudo mount -t efs ${efs_id}:/ /mnt/efs

# ✅ CRITICAL: Verify mount actually succeeded before writing anything
if ! mountpoint -q /mnt/efs; then
  echo "ERROR: EFS mount failed. Aborting." >&2
  exit 1
fi

sudo chown ubuntu:ubuntu /mnt/efs
sudo chmod 777 /mnt/efs

for i in {1..10}; do
  base64 /dev/urandom | head -c 200 | sudo tee /mnt/efs/file_$i.txt > /dev/null
done

sudo chown -R ubuntu:ubuntu /mnt/efs
sudo chmod -R 777 /mnt/efs/*.txt

# Only signal completion AFTER verified write to EFS
sudo touch /mnt/efs/.setup-complete

echo "${efs_id}:/ /mnt/efs efs _netdev,tls 0 0" | sudo tee -a /etc/fstab