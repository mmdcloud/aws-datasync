#!/bin/bash
sudo apt-get update
sudo mkdir -p /mnt/efs
sudo apt-get -y install git binutils rustc cargo pkg-config libssl-dev gettext
git clone https://github.com/aws/efs-utils
cd efs-utils
./build-deb.sh
sudo apt-get -y install ./build/amazon-efs-utils*deb
sudo mount -t efs fs-12345678:/ /mnt/efs