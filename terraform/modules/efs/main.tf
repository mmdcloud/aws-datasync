# Create an EFS filesystem as destination
resource "aws_efs_file_system" "destination_efs" {
  creation_token = "my-datasync-destination"

  tags = {
    Name = "DataSync Destination EFS"
  }
}

# Create a mount target for the EFS
resource "aws_efs_mount_target" "efs_mount" {
  file_system_id  = aws_efs_file_system.destination_efs.id
  subnet_id       = aws_subnet.example.id
  security_groups = [aws_security_group.efs_sg.id]
}