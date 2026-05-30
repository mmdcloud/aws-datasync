#!/bin/bash
set -e

apt-get update -y
apt-get install -y nfs-common

mkdir -p /mnt/efs

# Mount using NFS directly — no efs-utils needed
mount -t nfs4 \
  -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport \
  ${efs_id}.efs.${region}.amazonaws.com:/ \
  /mnt/efs

# Verify mount succeeded
if ! mountpoint -q /mnt/efs; then
  echo "ERROR: EFS mount failed. Aborting." >&2
  exit 1
fi

chown ubuntu:ubuntu /mnt/efs
chmod 777 /mnt/efs

for i in {1..10}; do
  base64 /dev/urandom | head -c 200 | tee /mnt/efs/file_$i.txt > /dev/null
done

chown -R ubuntu:ubuntu /mnt/efs
chmod -R 777 /mnt/efs/*.txt

touch /mnt/efs/.setup-complete
echo "Setup complete at $(date)" >> /var/log/efs-setup.log