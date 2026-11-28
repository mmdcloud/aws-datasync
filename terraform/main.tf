data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

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
  enable_s3_endpoint      = true
  tags = {
    Environment = "prod"
    Project     = "efs-to-s3-datasync"
  }
}

# Security Group
module "datasync_sg" {
  source        = "./modules/security-groups"
  name          = "datasync-sg"
  vpc_id        = module.vpc.vpc_id
  ingress_rules = []
  egress_rules = [
    {
      description = "Allow all outbound traffic for DataSync ENIs"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  tags = {
    Name = "datasync-sg"
  }
}

module "efs_sg" {
  source = "./modules/security-groups"
  name   = "efs-sg"
  vpc_id = module.vpc.vpc_id
  ingress_rules = [
    {
      description     = "NFS access from VPC CIDR"
      from_port       = 2049
      to_port         = 2049
      protocol        = "tcp"
      security_groups = []
      cidr_blocks     = ["10.0.0.0/16"]
      self            = false
    },
    {
      description     = "NFS access from DataSync SG"
      from_port       = 2049
      to_port         = 2049
      protocol        = "tcp"
      security_groups = [module.datasync_sg.id]
      cidr_blocks     = []
      self            = false
    },
    {
      description     = "NFS access within EFS SG"
      from_port       = 2049
      to_port         = 2049
      protocol        = "tcp"
      security_groups = []
      cidr_blocks     = []
      self            = true
    },
    {
      description     = "SSH access from VPC"
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      security_groups = []
      cidr_blocks     = ["10.0.0.0/16"]
      self            = false
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

module "efs" {
  source             = "./modules/efs"
  name               = "efs-datasync"
  creation_token     = "efs"
  encrypted          = true
  performance_mode   = "generalPurpose"
  throughput_mode    = "bursting"
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [module.efs_sg.id]

  # create_access_point = true
  # access_point_posix_user = {
  #   gid = 0
  #   uid = 0
  # }
  # access_point_root_directory = {
  #   path        = "/mnt/efs"
  #   owner_gid   = 1000
  #   owner_uid   = 1000
  #   permissions = "777"
  # }

  tags = {
    Environment = "prod"
  }
}

# -----------------------------------------------------------------------------------------
# EC2 Configuration
# -----------------------------------------------------------------------------------------
data "aws_ami" "datasync" {
  most_recent = true
  owners      = ["self"]
  filter {
    name   = "name"
    values = [var.ami_name]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# EC2 IAM Instance Profile
module "instance_profile_role" {
  source             = "./modules/iam"
  role_name          = "instance-profile-role"
  role_description   = "Least-privilege IAM role for EFS mount EC2 instance"
  policy_name        = "instance-profile-role-policy"
  policy_description = "Least-privilege EFS client access policy for mount instance"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowEC2AssumeRole"
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEFSMountAndWrite"
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeMountTargets"
        ]
        Resource = module.efs.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = module.instance_profile_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = "iam-instance-profile"
  role = module.instance_profile_role.name
}

module "efs_mount_instance" {
  source                      = "./modules/ec2"
  name                        = "efs-mount-instance"
  ami_id                      = data.aws_ami.datasync.id
  instance_type               = "t3.micro"
  key_name                    = "mohitd"
  associate_public_ip_address = false
  user_data = templatefile("${path.module}/scripts/user_data.sh", {
    efs_id = module.efs.id
    region = var.region
    efs_ip = module.efs.mount_target_ips[0]
  })
  instance_profile = aws_iam_instance_profile.iam_instance_profile.name
  subnet_id        = module.vpc.private_subnets[0]
  security_groups  = [module.efs_sg.id]

  depends_on = [module.efs]
}


resource "null_resource" "wait_for_efs_setup" {
  count      = var.private_key_path != "" ? (fileexists(var.private_key_path) ? 1 : 0) : 0
  depends_on = [module.efs_mount_instance]

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for EFS mount...'",
      # Wait max 10 minutes, check every 5 seconds
      "timeout 600 bash -c 'until mountpoint -q /mnt/efs; do sleep 5; done'",
      "echo 'EFS mounted. Waiting for setup complete marker...'",
      "timeout 300 bash -c 'until [ -f /mnt/efs/.setup-complete ]; do sleep 5; done'",
      "echo 'EFS setup confirmed complete!'"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = fileexists(var.private_key_path) ? file(var.private_key_path) : ""
      host        = module.efs_mount_instance.private_ip
    }
  }
}

# -----------------------------------------------------------------------------------------
# S3 Configuration
# -----------------------------------------------------------------------------------------
locals {
  bucket_name = "destination-bucket-${random_id.id.hex}"
}

module "s3_access_role" {
  source             = "./modules/iam"
  role_name          = "datasync-s3-access-role"
  role_description   = "IAM Role for DataSync to write objects into S3"
  policy_name        = "datasync-s3-access-policy"
  policy_description = "DataSync S3 access policy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Principal = { Service = "datasync.amazonaws.com" }
      Effect    = "Allow"
    }]
  })
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "DataSyncBucketPermissions"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${local.bucket_name}"
      },
      {
        Sid = "DataSyncObjectPermissions"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:GetObjectTagging",
          "s3:GetObjectVersion",
          "s3:GetObjectVersionTagging",
          "s3:ListMultipartUploadParts",
          "s3:PutObject",
          "s3:PutObjectTagging"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${local.bucket_name}/*"
      }
    ]
  })
}

module "destination_bucket" {
  source             = "./modules/s3"
  bucket_name        = local.bucket_name
  objects            = []
  versioning_enabled = "Enabled"
  cors               = []
  bucket_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DataSyncBucketAccess"
        Effect = "Allow"
        Principal = {
          AWS = module.s3_access_role.arn
        }
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads"
        ]
        Resource = "arn:aws:s3:::${local.bucket_name}"
      },
      {
        Sid    = "DataSyncObjectAccess"
        Effect = "Allow"
        Principal = {
          AWS = module.s3_access_role.arn
        }
        Action = [
          "s3:AbortMultipartUpload",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:GetObjectTagging",
          "s3:GetObjectVersion",
          "s3:GetObjectVersionTagging",
          "s3:ListMultipartUploadParts",
          "s3:PutObject",
          "s3:PutObjectTagging"
        ]
        Resource = "arn:aws:s3:::${local.bucket_name}/*"
      }
    ]
  })
  force_destroy = true
  bucket_notification = {
    queue           = []
    lambda_function = []
  }
}

# -----------------------------------------------------------------------------------------
# DataSync Configuration
# -----------------------------------------------------------------------------------------
# CloudWatch Log Group
module "datasync_logs" {
  source            = "./modules/cloudwatch/cloudwatch-log-group"
  log_group_name    = "/aws/datasync/efs-to-s3-sync"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_resource_policy" "datasync_logs_policy" {
  policy_name = "datasync-log-policy"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DataSyncLogsToCloudWatch"
      Effect    = "Allow"
      Principal = { Service = "datasync.amazonaws.com" }
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${trimsuffix(module.datasync_logs.arn, ":*")}:*"
    }]
  })
}

module "datasync" {
  source = "./modules/datasync/efs-to-s3"

  task_name = "efs-to-s3-sync"

  # S3 Location
  s3_bucket_arn             = module.destination_bucket.arn
  s3_storage_class          = "STANDARD"
  s3_subdirectory           = "/"
  s3_bucket_access_role_arn = module.s3_access_role.arn

  # EFS Location
  efs_file_system_arn   = module.efs.arn
  efs_subdirectory      = "/"
  security_group_arns   = [module.datasync_sg.arn]
  subnet_arn            = module.vpc.private_subnet_arns[0]
  in_transit_encryption = "TLS1_2"

  # Task Options
  task_options = {
    verify_mode            = "ONLY_FILES_TRANSFERRED"
    preserve_deleted_files = "PRESERVE"
    preserve_devices       = "NONE"
    uid                    = "NONE"
    gid                    = "NONE"
    posix_permissions      = "NONE"
    atime                  = "BEST_EFFORT"
    mtime                  = "PRESERVE"
    transfer_mode          = "ALL"
    overwrite_mode         = "ALWAYS"
    task_queueing          = "ENABLED"
    log_level              = "TRANSFER"
  }

  cloudwatch_log_group_arn = "${module.datasync_logs.arn}:*"

  tags = {
    Environment = "prod"
    Project     = "efs-to-s3-datasync"
  }

  depends_on = [
    module.efs,
    module.efs_mount_instance,
    null_resource.wait_for_efs_setup
  ]
}