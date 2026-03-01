#!/bin/bash
sudo apt-get update -y
sudo mkdir -p /mnt/efs
sudo apt-get install -y amazon-efs-utils    # no build needed

# Wait for EFS mount target to be ready
sleep 30

sudo mount -t efs -o tls ${efs_id}:/ /mnt/efs

sudo chown ubuntu:ubuntu /mnt/efs
sudo chmod 777 /mnt/efs

for i in {1..10}; do
  base64 /dev/urandom | head -c 200 | sudo tee /mnt/efs/file_$i.txt > /dev/null
done

sudo chown -R ubuntu:ubuntu /mnt/efs
sudo chmod -R 777 /mnt/efs/*.txt

# Signal completion
sudo touch /mnt/efs/.setup-complete

echo "${efs_id}:/ /mnt/efs efs _netdev,tls 0 0" | sudo tee -a /etc/fstab