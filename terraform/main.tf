data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------------------
# Random suffix for bucket name
# -----------------------------------------------------------------------------------------
resource "random_id" "id" {
  byte_length = 4
}

# -----------------------------------------------------------------------------------------
# VPC Configuration
# -----------------------------------------------------------------------------------------
module "vpc" {
  source                  = "./modules/vpc"
  vpc_name                = "vpc"
  vpc_cidr                = "10.0.0.0/16"
  azs                     = var.azs
  public_subnets          = var.public_subnets
  private_subnets         = var.private_subnets
  enable_dns_hostnames    = true
  enable_dns_support      = true
  create_igw              = true
  map_public_ip_on_launch = true
  enable_nat_gateway      = false
  single_nat_gateway      = false
  one_nat_gateway_per_az  = false
  tags = {
    Environment = "prod"
    Project     = "efs-to-s3-datasync"
  }
}

# Security Group
module "efs_sg" {
  source = "./modules/security-groups"
  name   = "efs-sg"
  vpc_id = module.vpc.vpc_id
  ingress_rules = [
    {
      description     = "NFS access"
      from_port       = 2049
      to_port         = 2049
      protocol        = "tcp"
      security_groups = []
      cidr_blocks     = ["0.0.0.0/0"]
    },
    {
      description     = "SSH access"
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      security_groups = []
      cidr_blocks     = ["0.0.0.0/0"]
    }
  ]
  egress_rules = [
    {
      description = "Allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  tags = {
    Name = "efs-sg"
  }
}

# -----------------------------------------------------------------------------------------
# EFS Configuration
# -----------------------------------------------------------------------------------------
resource "aws_efs_file_system" "efs" {
  creation_token = "efs"
  tags = {
    Name = "efs"
  }
}

resource "aws_efs_mount_target" "efs_mt" {
  count           = length(var.public_subnets)
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = module.vpc.public_subnets[count.index]
  security_groups = [module.efs_sg.id]
}

# -----------------------------------------------------------------------------------------
# EC2 Configuration
# -----------------------------------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 IAM Instance Profile
module "instance_profile_role" {
  source             = "./modules/iam"
  role_name          = "instance-profile-role"
  role_description   = "Instance Profile IAM Role"
  policy_name        = "instance-profile-role-policy"
  policy_description = "Instance Profile IAM Role Policy"
  assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                  "Service": "datasync.amazonaws.com"
                },
                "Effect": "Allow",
                "Sid": ""
            }
        ]
    }
    EOF
  policy             = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [            
            {
              "Action" : [
                "s3:*",                
              ],
              "Effect"   : "Allow",
              "Resource" : "*"
            },
            {
              "Action" : [
                "cloudwatch:*",                
              ],
              "Effect"   : "Allow",
              "Resource" : "*"
            },
        ]
    }
    EOF
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = "iam-instance-profile"
  role = module.instance_profile.name
}

module "efs_mount_instance" {
  source                      = "./modules/ec2"
  name                        = "efs-mount-instance"
  ami_id                      = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  key_name                    = "madmaxkeypair"
  associate_public_ip_address = true
  user_data = templatefile("${path.module}/scripts/user_data.sh", {
    efs_id = "${aws_efs_file_system.efs.id}"
  })
  instance_profile = aws_iam_instance_profile.iam_instance_profile.name
  subnet_id        = module.vpc.public_subnets[0]
  security_groups  = [module.efs_sg.id]
}

# -----------------------------------------------------------------------------------------
# S3 Configuration
# -----------------------------------------------------------------------------------------
module "destination_bucket" {
  source             = "./modules/s3"
  bucket_name        = "destination-bucket-${random_id.id.hex}"
  objects            = []
  versioning_enabled = "Enabled"
  cors = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["PUT"]
      allowed_origins = ["*"]
      max_age_seconds = 3000
    },
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET"]
      allowed_origins = ["*"]
      max_age_seconds = 3000
    }
  ]
  bucket_policy = ""
  force_destroy = true
  bucket_notification = {
    queue           = []
    lambda_function = []
  }
}

# -----------------------------------------------------------------------------------------
# DataSync Configuration
# -----------------------------------------------------------------------------------------
module "s3_access_role" {
  source             = "./modules/iam"
  role_name          = "datasync-s3-access-role"
  role_description   = "datasync-s3-access-role"
  policy_name        = "datasync-s3-access-policy"
  policy_description = "datasync-s3-access-policy"
  assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                  "Service": "datasync.amazonaws.com"
                },
                "Effect": "Allow",
                "Sid": ""
            }
        ]
    }
    EOF
  policy             = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
              "Action" : [
                "s3:GetBucketLocation",
                "s3:ListBucket",
                "s3:ListBucketV2",
                "s3:ListBucketMultipartUploads",
                "s3:AbortMultipartUpload",
                "s3:DeleteObject",
                "s3:GetObject",
                "s3:ListMultipartUploadParts",
                "s3:PutObjectTagging",
                "s3:GetObjectTagging",
                "s3:PutObject"
              ],
              "Effect" : "Allow",
              "Resource" : [
                "${module.destination_bucket.arn}",
                "${module.destination_bucket.arn}/*"
              ]
            },
            {
              "Action" : [
                "ec2:DescribeSubnets",
                "ec2:DescribeNetworkInterfaces",
                "ec2:CreateNetworkInterface",
                "ec2:DeleteNetworkInterface",
                "ec2:DescribeSecurityGroups"
              ],
              "Effect"   : "Allow",
              "Resource" : "*"
            }
        ]
    }
    EOF
}

module "efs_access_role" {
  source             = "./modules/iam"
  role_name          = "datasync-efs-access-role"
  role_description   = "datasync-efs-access-role"
  policy_name        = "datasync-efs-access-policy"
  policy_description = "datasync-efs-access-policy"
  assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                  "Service": "datasync.amazonaws.com"
                },
                "Effect": "Allow",
                "Sid": ""
            }
        ]
    }
    EOF
  policy             = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [            
            {
              "Action" : [
                "elasticfilesystem:ClientMount",
                "elasticfilesystem:ClientWrite",
                "elasticfilesystem:ClientRootAccess",
                "elasticfilesystem:ClientRead"
              ],
              "Effect"   : "Allow",
              "Resource" : "${aws_efs_file_system.efs.arn}"
            },
            {
              "Action" : [
                "ec2:DescribeSubnets",
                "ec2:DescribeNetworkInterfaces",
                "ec2:CreateNetworkInterface",
                "ec2:DeleteNetworkInterface",
                "ec2:DescribeSecurityGroups"
              ],
              "Effect"   : "Allow",
              "Resource" : "*"
            }
        ]
    }
    EOF
}

# S3 location for DataSync (Destination)
resource "aws_datasync_location_s3" "s3_location" {
  s3_bucket_arn = module.destination_bucket.arn
  subdirectory  = "/"
  s3_config {
    bucket_access_role_arn = module.s3_access_role.arn
  }
}

# EFS location for DataSync (Source)
resource "aws_datasync_location_efs" "efs_location" {
  efs_file_system_arn         = aws_efs_file_system.efs.arn
  file_system_access_role_arn = module.efs_access_role.arn
  subdirectory                = "/"
  ec2_config {
    security_group_arns = [module.efs_sg.arn]
    subnet_arn          = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:subnet/${module.vpc.public_subnets[0]}"
  }
  in_transit_encryption = "TLS1_2"
  depends_on = [aws_efs_mount_target.efs_mt]
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "datasync_logs" {
  name              = "/aws/datasync/s3-to-efs-sync"
  retention_in_days = 7
}

# DataSync task
resource "aws_datasync_task" "s3_to_efs" {
  name                     = "s3-to-efs-sync"
  source_location_arn      = aws_datasync_location_efs.efs_location.arn
  destination_location_arn = aws_datasync_location_s3.s3_location.arn
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