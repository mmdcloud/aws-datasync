# Create an S3 bucket as source
resource "aws_s3_bucket" "source_bucket" {
  bucket = "my-datasync-source-bucket-${random_id.bucket_suffix.hex}"
  tags = {
    Name = "DataSync Source Bucket"
  }
}

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

# IAM role for DataSync
resource "aws_iam_role" "datasync_role" {
  name = "DataSyncS3EFSRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "datasync.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for DataSync
resource "aws_iam_policy" "datasync_policy" {
  name        = "DataSyncS3EFSPolicy"
  description = "Policy for DataSync to access S3 and EFS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:AbortMultipartUpload",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListMultipartUploadParts",
          "s3:PutObjectTagging",
          "s3:GetObjectTagging",
          "s3:PutObject"
        ],
        Effect = "Allow",
        Resource = [
          aws_s3_bucket.source_bucket.arn,
          "${aws_s3_bucket.source_bucket.arn}/*"
        ]
      },
      {
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess"
        ],
        Effect   = "Allow",
        Resource = aws_efs_file_system.destination_efs.arn
      },
      {
        Action = [
          "ec2:DescribeSubnets",
          "ec2:DescribeNetworkInterfaces",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSecurityGroups"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "datasync_attach" {
  role       = aws_iam_role.datasync_role.name
  policy_arn = aws_iam_policy.datasync_policy.arn
}

# Create S3 location for DataSync
resource "aws_datasync_location_s3" "s3_location" {
  s3_bucket_arn = aws_s3_bucket.source_bucket.arn
  subdirectory  = "/"

  s3_config {
    bucket_access_role_arn = aws_iam_role.datasync_role.arn
  }

  depends_on = [aws_iam_role_policy_attachment.datasync_attach]
}

# Create EFS location for DataSync
resource "aws_datasync_location_efs" "efs_location" {
  efs_file_system_arn = aws_efs_mount_target.efs_mount.file_system_arn

  ec2_config {
    security_group_arns = [aws_security_group.efs_sg.arn]
    subnet_arn          = aws_subnet.example.arn
  }
}

# Add this resource for CloudWatch Log Group
resource "aws_cloudwatch_log_group" "datasync_logs" {
  name              = "/aws/datasync/s3-to-efs-sync"
  retention_in_days = 7
}

# Create DataSync task
resource "aws_datasync_task" "s3_to_efs" {
  name                     = "s3-to-efs-sync"
  source_location_arn      = aws_datasync_location_s3.s3_location.arn
  destination_location_arn = aws_datasync_location_efs.efs_location.arn

  options {
    verify_mode            = "POINT_IN_TIME_CONSISTENT"
    preserve_deleted_files = "PRESERVE"
    preserve_devices       = "NONE"
    posix_permissions      = "PRESERVE"
    uid                    = "NONE"
    gid                    = "NONE"
    atime                  = "BEST_EFFORT"
    mtime                  = "PRESERVE"
    task_queueing          = "ENABLED"
    log_level              = "TRANSFER"
  }

  cloudwatch_log_group_arn = aws_cloudwatch_log_group.datasync_logs.arn

  depends_on = [
    aws_datasync_location_s3.s3_location,
    aws_datasync_location_efs.efs_location
  ]
}

# Random suffix for bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Supporting VPC resources (simplified)
resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "example" {
  vpc_id     = aws_vpc.example.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_security_group" "efs_sg" {
  name        = "efs-sg"
  description = "Security group for EFS"
  vpc_id      = aws_vpc.example.id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
