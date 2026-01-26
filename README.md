# 🚀 EFS to S3 DataSync Infrastructure

Production-grade Terraform infrastructure for automated synchronization of Amazon Elastic File System (EFS) data to Amazon S3 using AWS DataSync.

## Overview

This infrastructure automates the transfer of files from Amazon EFS to S3 with encryption in transit, CloudWatch logging, and POSIX metadata preservation. It's designed for backup workflows, data archival, and disaster recovery scenarios.

## Architecture

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│   EC2       │────────▶│     EFS      │────────▶│  DataSync   │
│   Instance  │  Mount  │  File System │  Source │    Task     │
└─────────────┘         └──────────────┘         └──────┬──────┘
                                                         │
                                                         ▼
                                                  ┌─────────────┐
                                                  │     S3      │
                                                  │   Bucket    │
                                                  └─────────────┘
```

### Components

- **VPC**: Isolated network environment with public subnets
- **EFS**: Source file system with mount targets across availability zones
- **EC2 Instance**: Ubuntu-based instance for EFS mounting and testing
- **S3 Bucket**: Destination storage with versioning enabled
- **DataSync**: Managed data transfer service with CloudWatch integration
- **IAM Roles**: Least-privilege access for DataSync operations

## Features

- ✅ **Automated Data Transfer**: Scheduled or on-demand EFS to S3 synchronization
- ✅ **Encryption in Transit**: TLS 1.2 encryption for data transfer
- ✅ **POSIX Metadata Preservation**: Maintains file permissions and timestamps
- ✅ **CloudWatch Logging**: Comprehensive transfer logs with 7-day retention
- ✅ **S3 Versioning**: Enabled for data protection and recovery
- ✅ **Multi-AZ Support**: EFS mount targets across availability zones
- ✅ **Point-in-Time Consistency**: Ensures data integrity during transfer

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.0
- AWS CLI configured
- SSH key pair (default: `madmaxkeypair`)

## Module Structure

```
.
├── main.tf                    # Main configuration
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── scripts/
│   └── user_data.sh          # EC2 initialization script
└── modules/
    ├── vpc/                  # VPC and networking
    ├── ec2/                  # EC2 instances
    ├── s3/                   # S3 bucket configuration
    ├── iam/                  # IAM roles and policies
    └── security-groups/      # Security group rules
```

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd efs-to-s3-datasync
```

### 2. Configure Variables

Create a `terraform.tfvars` file:

```hcl
region          = "us-east-1"
azs             = ["us-east-1a", "us-east-1b"]
public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review Plan

```bash
terraform plan
```

### 5. Deploy Infrastructure

```bash
terraform apply
```

### 6. Access EC2 Instance

```bash
# Get instance public IP from outputs
terraform output ec2_public_ip

# SSH into instance
ssh -i /path/to/madmaxkeypair.pem ubuntu@<instance-ip>
```

## Configuration

### Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `region` | AWS region | - | Yes |
| `azs` | Availability zones | - | Yes |
| `public_subnets` | Public subnet CIDR blocks | - | Yes |
| `private_subnets` | Private subnet CIDR blocks | - | Yes |

### DataSync Task Options

The DataSync task is configured with the following settings:

- **Verify Mode**: `POINT_IN_TIME_CONSISTENT` - Ensures data consistency
- **Preserve Deleted Files**: `PRESERVE` - Keeps deleted files in destination
- **POSIX Permissions**: `PRESERVE` - Maintains file permissions
- **Log Level**: `TRANSFER` - Logs all file transfers
- **Task Queueing**: `ENABLED` - Allows multiple executions

### Modifying DataSync Behavior

Edit the `aws_datasync_task` resource in `main.tf`:

```hcl
options {
  verify_mode            = "POINT_IN_TIME_CONSISTENT"  # or "ONLY_FILES_TRANSFERRED"
  preserve_deleted_files = "PRESERVE"                  # or "REMOVE"
  preserve_devices       = "NONE"                      # or "PRESERVE"
  posix_permissions      = "PRESERVE"                  # or "NONE"
  log_level              = "TRANSFER"                  # or "BASIC"
}
```

## Usage

### Running a DataSync Task

#### Via AWS Console
1. Navigate to AWS DataSync
2. Select the task `s3-to-efs-sync`
3. Click "Start" to execute

#### Via AWS CLI
```bash
# Get task ARN
TASK_ARN=$(aws datasync list-tasks --query 'Tasks[0].TaskArn' --output text)

# Start task execution
aws datasync start-task-execution --task-arn $TASK_ARN
```

### Monitoring Transfer Progress

#### CloudWatch Logs
```bash
aws logs tail /aws/datasync/s3-to-efs-sync --follow
```

#### Task Execution Status
```bash
aws datasync describe-task-execution --task-execution-arn <execution-arn>
```

### Adding Files to EFS

```bash
# SSH into EC2 instance
ssh -i madmaxkeypair.pem ubuntu@<instance-ip>

# Navigate to EFS mount point
cd /mnt/efs

# Add files
echo "Test data" > test-file.txt
```

## Security

### IAM Roles

Three IAM roles are created with least-privilege access:

1. **DataSync S3 Access Role**: S3 read/write permissions
2. **DataSync EFS Access Role**: EFS client mount/read/write permissions
3. **EC2 Instance Profile Role**: CloudWatch and S3 access

### Network Security

- **Security Group**: Allows NFS (2049) and SSH (22) traffic
- **Encryption**: TLS 1.2 for data in transit
- **VPC Isolation**: Resources deployed in dedicated VPC

### Best Practices

- ⚠️ **Update Security Groups**: Restrict SSH and NFS to specific IP ranges
- ⚠️ **Rotate SSH Keys**: Use AWS Systems Manager Session Manager instead of SSH
- ⚠️ **Enable S3 Encryption**: Add server-side encryption to S3 bucket
- ⚠️ **VPC Endpoints**: Use VPC endpoints for S3 to avoid internet gateway traffic
- ⚠️ **Enable MFA**: Require MFA for destructive operations

## Outputs

After deployment, Terraform provides:

- VPC ID and subnet IDs
- EFS file system ID and DNS name
- S3 bucket name and ARN
- EC2 instance public IP
- DataSync task ARN
- IAM role ARNs

## Monitoring and Troubleshooting

### CloudWatch Metrics

Monitor these DataSync metrics:

- `BytesCompressed`
- `BytesTransferred`
- `FilesTransferred`
- `BytesVerified`

### Common Issues

**Issue**: DataSync task fails with "Access Denied"
- **Solution**: Verify IAM role policies and trust relationships

**Issue**: EFS mount fails on EC2
- **Solution**: Check security group rules and EFS mount target status

**Issue**: Task completes but no files transferred
- **Solution**: Verify files exist in EFS and subdirectory configuration

## Cost Optimization

- **DataSync**: Charged per GB transferred ($0.0125/GB)
- **EFS**: Consider Infrequent Access storage class for cold data
- **S3**: Use Intelligent-Tiering or Glacier for archival
- **CloudWatch Logs**: Reduce retention period to minimize costs

## Maintenance

### Updating Infrastructure

```bash
# Update Terraform code
git pull origin main

# Review changes
terraform plan

# Apply updates
terraform apply
```

### Destroying Infrastructure

```bash
# Remove all resources
terraform destroy
```

⚠️ **Warning**: This will delete the S3 bucket and all data due to `force_destroy = true`.

## Backup and Recovery

### S3 Versioning

The destination bucket has versioning enabled. To restore a previous version:

```bash
aws s3api list-object-versions --bucket <bucket-name> --prefix <key>
aws s3api copy-object --copy-source <bucket>/<key>?versionId=<version-id> --bucket <bucket> --key <key>
```

### EFS Backup

Consider AWS Backup for automated EFS backups:

```hcl
resource "aws_backup_plan" "efs_backup" {
  name = "efs-backup-plan"
  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.vault.name
    schedule          = "cron(0 2 * * ? *)"
  }
}
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/improvement`)
3. Commit changes (`git commit -am 'Add improvement'`)
4. Push to branch (`git push origin feature/improvement`)
5. Create Pull Request

## License

This project is licensed under the MIT License - see LICENSE file for details.

## Support

For issues and questions:
- Open a GitHub issue
- Review AWS DataSync documentation
- Check CloudWatch logs for error details

## References

- [AWS DataSync Documentation](https://docs.aws.amazon.com/datasync/)
- [Amazon EFS Documentation](https://docs.aws.amazon.com/efs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS DataSync Pricing](https://aws.amazon.com/datasync/pricing/)

---

**Version**: 1.0.0  
**Last Updated**: December 2025  
**Maintained By**: DevOps Team
