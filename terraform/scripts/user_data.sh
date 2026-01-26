# #!/bin/bash
# sudo apt-get update
# sudo mkdir -p /mnt/efs
# sudo apt-get -y install git binutils rustc cargo pkg-config libssl-dev gettext
# git clone https://github.com/aws/efs-utils
# cd efs-utils
# sudo ./build-deb.sh
# sudo apt-get -y install ./build/amazon-efs-utils*deb
# sudo mount -t efs -o tls ${efs_id}:/ /mnt/efs
# cd /mnt/efs
# for i in {1..10}; do
#   base64 /dev/urandom | head -c 200 > "file_$i.txt"
# done
#!/bin/bash
set -e  # Exit on any error
set -x  # Debug logging

# Log everything
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting user-data script..."

# Update and install dependencies
sudo apt-get update -y
sudo mkdir -p /mnt/efs

echo "Installing dependencies..."
sudo apt-get install -y git binutils rustc cargo pkg-config libssl-dev gettext

# Build and install efs-utils
echo "Cloning efs-utils..."
cd /tmp
git clone https://github.com/aws/efs-utils
cd efs-utils
sudo ./build-deb.sh
sudo apt-get install -y ./build/amazon-efs-utils*deb

# Wait for EFS mount targets to be ready
echo "Waiting for EFS to be available..."
sleep 60

# Mount EFS with retry logic
echo "Mounting EFS ${efs_id}..."
MAX_ATTEMPTS=5
ATTEMPT=1
while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
  if sudo mount -t efs -o tls ${efs_id}:/ /mnt/efs; then
    echo "EFS mounted successfully"
    break
  else
    echo "Mount attempt $ATTEMPT failed, retrying..."
    ATTEMPT=$((ATTEMPT + 1))
    sleep 10
  fi
done

# Verify mount
if ! mountpoint -q /mnt/efs; then
  echo "ERROR: Failed to mount EFS after $MAX_ATTEMPTS attempts"
  exit 1
fi

# Create test files
echo "Creating test files..."
cd /mnt/efs
for i in {1..10}; do
  base64 /dev/urandom | head -c 200 > "file_$i.txt"
  echo "Created file_$i.txt"
done

# Create a subdirectory with more files
mkdir -p /mnt/efs/data
cd /mnt/efs/data
for i in {1..5}; do
  base64 /dev/urandom | head -c 500 > "data_file_$i.txt"
  echo "Created data_file_$i.txt"
done

# Verify files were created
echo "Files created in EFS:"
ls -lah /mnt/efs/
ls -lah /mnt/efs/data/

echo "User-data script completed successfully!"