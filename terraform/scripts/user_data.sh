#!/bin/bash
sudo apt-get update
sudo mkdir -p /mnt/efs
sudo apt-get -y install git binutils rustc cargo pkg-config libssl-dev gettext
git clone https://github.com/aws/efs-utils
cd efs-utils
sudo ./build-deb.sh
sudo apt-get -y install ./build/amazon-efs-utils*deb
sudo mount -t efs -o tls ${efs_id}:/ /mnt/efs
cd /mnt/efs
for i in {1..10}; do
  base64 /dev/urandom | head -c 200 > "file_$i.txt"
done