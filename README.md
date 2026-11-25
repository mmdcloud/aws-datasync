# 🚀 EFS to S3 DataSync Infrastructure

Production-grade, fully automated Terraform infrastructure for synchronizing Amazon Elastic File System (EFS) data to Amazon Simple Storage Service (S3) using AWS DataSync, deployed within a secure private network architecture.

---

## 📌 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [📸 Visual Verification & Proof of Deployment](#-visual-verification--proof-of-deployment)
  - [1. Secure Private EC2 Deployment & Test Data](#1-secure-private-ec2-deployment--test-data)
  - [2. Amazon EFS File System Status](#2-amazon-efs-file-system-status)
  - [3. AWS DataSync Locations & Task Setup](#3-aws-datasync-locations--task-setup)
  - [4. DataSync Execution & Verification Metrics](#4-datasync-execution--verification-metrics)
  - [5. S3 Destination Bucket Verification](#5-s3-destination-bucket-verification)
- [Features](#features)
- [Repository Structure](#repository-structure)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [DataSync Task Options](#datasync-task-options)
- [Operational Commands](#operational-commands)
- [Security & Best Practices](#security--best-practices)
- [Troubleshooting & Lessons Learned](#troubleshooting--lessons-learned)
- [License](#license)

---

## Overview

This project provides an automated, enterprise-ready data pipeline to migrate and replicate files from **Amazon EFS** to **Amazon S3** using **AWS DataSync**.

Key highlights:
- **100% Private Workloads**: EC2 test instances, EFS mount targets, and DataSync network interfaces (ENIs) are isolated in private subnets with no public IPv4 exposure.
- **S3 Gateway VPC Endpoint**: High-throughput, zero-data-egress-cost private communication between DataSync and Amazon S3.
- **Passwordless & Keyless Access**: Managed via AWS Systems Manager (SSM) Session Manager, eliminating open SSH (port 22) and key management risks.
- **Zero-Touch Automated Testing**: EC2 initialization automatically installs NFS utilities, mounts EFS via private mount target IP, generates sample data files, and initiates the DataSync transfer.

---

## Architecture

```
                                  VPC (10.0.0.0/16)
 ┌─────────────────────────────────────────────────────────────────────────────────┐
 │                                                                                 │
 │   Public Subnets (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24)                        │
 │   ┌──────────────────────────┐                                                  │
 │   │       NAT Gateway        │◀── (Outbound apt / package updates)              │
 │   └─────────────▲────────────┘                                                  │
 │                 │                                                               │
 │   Private Subnets (10.0.4.0/24, 10.0.5.0/24, 10.0.6.0/24)                       │
 │   ┌───────────────────┐        ┌───────────────────┐    ┌────────────────────┐  │
 │   │   EC2 Instance    │  NFS   │    Amazon EFS     │    │   AWS DataSync     │  │
 │   │ (efs-mount-inst)  ├───────▶│ (efs-datasync-fs) │◀───┤ Task & Private ENI │  │
 │   │  [No Public IP]   │        │  [Mount Targets]  │    │ (efs-to-s3-sync)   │  │
 │   └─────────▲─────────┘        └───────────────────┘    └─────────┬──────────┘  │
 │             │                                                     │             │
 │    AWS SSM Session Manager                                        │             │
 │    (Private secure shell)                                         │             │
 └───────────────────────────────────────────────────────────────────┼─────────────┘
                                                                     │
                                                      S3 Gateway VPC Endpoint
                                                       (Private, Free, TLS)
                                                                     │
                                                                     ▼
                                                           ┌───────────────────┐
                                                           │     Amazon S3     │
                                                           │ Destination Bucket│
                                                           │ (12/12 Transferred│
                                                           │  & Verified)      │
                                                           └───────────────────┘
```

---

## 📸 Visual Verification & Proof of Deployment

The following screenshots demonstrate the end-to-end deployment, verification, and successful execution of the EFS-to-S3 DataSync pipeline.

### 1. Secure Private EC2 Deployment & Test Data

The EC2 instance is provisioned in a private subnet with no public IPv4 address and configured with AWS Systems Manager (SSM) Session Manager for secure, keyless access.

#### Private EC2 Instance Configuration
The instance `efs-mount-instance` runs inside private subnet `subnet-034ec332fc3ce66fa` (Private IP: `10.0.4.30`) with no public IP assigned:

![EC2 Instance running in Private Subnet](screenshots/Screenshot%20from%202026-11-25%2007-33-23.png)

#### EC2 Terminal & EFS Mount Verification
Connected via AWS Systems Manager Session Manager, verifying the EFS file system is mounted at `/mnt/efs` and 10 sample test files (`file_1.txt` – `file_10.txt`) plus `.setup-complete` were generated:

![EC2 Terminal displaying mounted EFS files](screenshots/Screenshot%20from%202026-11-25%2007-26-41.png)

---

### 2. Amazon EFS File System Status

#### EFS Console Overview
The Amazon EFS file system `efs-datasync` (`fs-02c036fa669a1d743`) in `Available` state with metered storage size confirming test files are written:

![EFS Console showing Available state and metered size](screenshots/Screenshot%20from%202026-11-25%2007-27-14.png)

#### EFS General Settings & Regional Configuration
General details showing Regional availability, encryption at rest, and DNS endpoint (`fs-02c036fa669a1d743.efs.ap-south-1.amazonaws.com`):

![EFS General Details and Regional Configuration](screenshots/Screenshot%20from%202026-11-25%2007-27-45.png)

---

### 3. AWS DataSync Locations & Task Setup

#### DataSync Locations
DataSync configured with private source location (Amazon EFS `loc-09af6e7507f08c46b`) and destination location (Amazon S3 `loc-0822fe0a6d51540ab`):

![AWS DataSync Locations for EFS and S3](screenshots/Screenshot%20from%202026-11-25%2007-28-39.png)

#### DataSync Tasks Overview
The task `efs-to-s3-sync` (`task-0fdce5e0f34199454`) in `Available` state ready for execution:

![AWS DataSync Tasks Table](screenshots/Screenshot%20from%202026-11-25%2007-28-07.png)

#### Task Execution Start
DataSync task execution initiated, transitioning to `Running` status with private ENI and TLS 1.2 in-transit encryption:

![AWS DataSync Task Execution Overview Running](screenshots/Screenshot%20from%202026-11-25%2007-28-26.png)

#### DataSync Task Transfer Options
Transfer configuration settings including TLS 1.2 encryption, full data transfer, file verification, POSIX permissions preservation, and CloudWatch logging:

![AWS DataSync Task Transfer Options](screenshots/Screenshot%20from%202026-11-25%2007-32-29.png)

---

### 4. DataSync Execution & Verification Metrics

#### Execution History: Status Success
Execution `exec-07cea352b139a26f5` completed in **5 seconds** with status **Success** and an average throughput of 2.93 file/s:

![AWS DataSync Execution History Status Success](screenshots/Screenshot%20from%202026-11-25%2007-31-27.png)

#### Detailed Execution Performance & File Counts
Detailed performance metrics showing **12 files transferred**, **12 files verified**, and 2.66 KiB transferred with zero errors:

![AWS DataSync Detailed Execution Performance Metrics](screenshots/Screenshot%20from%202026-11-25%2007-32-15.png)

---

### 5. S3 Destination Bucket Verification

#### All 12 Objects Verified in S3 Destination Bucket
Amazon S3 Console showing the destination bucket `destination-bucket-e07653c2` containing all 12 transferred objects (`file_1.txt` through `file_10.txt`, `.setup-complete`, and `.aws-datasync-metadata/`):

![Amazon S3 Destination Bucket showing all 12 transferred objects](screenshots/Screenshot%20from%202026-11-25%2007-32-54.png)

---

## Features

- ✅ **100% Private Architecture**: All compute, storage, and transfer ENIs reside in private subnets.
- ✅ **Automatic EFS Mount & Data Seeding**: EC2 user data installs NFS utilities, mounts via direct Mount Target IP, and generates test files.
- ✅ **S3 Gateway Endpoint**: Traffic between DataSync and S3 stays on the AWS private network backbone, bypassing NAT gateways and saving transfer costs.
- ✅ **AWS SSM Integration**: Instant shell access via Session Manager without SSH keys or open inbound ports.
- ✅ **In-Transit Encryption**: TLS 1.2 encryption for EFS mount and DataSync transfer.
- ✅ **POSIX Metadata & Permissions**: File timestamps, ownership, and mode flags are preserved in S3.
- ✅ **Automated Triggering**: Terraform automatically triggers DataSync execution post-deployment with configurable delay.
- ✅ **CloudWatch Logging**: Real-time logging of all file transfers, verification results, and operational errors.

---

## Repository Structure

```
.
├── README.md                      # Comprehensive documentation and visual walkthrough
├── screenshots/                   # Verification screenshots from live AWS deployment
└── terraform/                     # Complete Terraform codebase
    ├── provider.tf                # AWS provider configuration
    ├── terraform.tfvars           # Environment variable definitions
    ├── variables.tf               # Input variable declarations
    ├── main.tf                    # Core orchestration (VPC, EFS, DataSync, EC2, S3)
    ├── outputs.tf                 # Actionable outputs and operational commands
    ├── scripts/
    │   └── user_data.sh           # Resilient EC2 mount and file generator script
    └── modules/
        ├── vpc/                   # Custom VPC with public/private subnets & endpoints
        ├── efs/                   # Amazon EFS with mount targets
        ├── ec2/                   # EC2 instance with IAM role
        ├── s3/                    # S3 bucket with versioning & policies
        ├── datasync/              # AWS DataSync task and locations
        ├── iam/                   # Least-privilege IAM roles and policies
        └── security-groups/       # Security groups for EFS, EC2, and DataSync
```

---

## Quick Start

### 1. Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with valid administrator or deployment credentials
- [Session Manager Plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) installed for AWS CLI

### 2. Configure Variables

Navigate to the `terraform/` directory:

```bash
cd terraform
```

Review or modify `terraform.tfvars`:

```hcl
region          = "ap-south-1"
azs             = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnets = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
```

### 3. Initialize & Deploy

```bash
# Initialize providers and modules
terraform init

# Review execution plan
terraform plan

# Deploy infrastructure
terraform apply -auto-approve
```

---

## Configuration

### Input Variables

| Variable | Description | Type | Default |
|---|---|---|---|
| `region` | AWS region to deploy into | `string` | `"ap-south-1"` |
| `azs` | List of Availability Zones | `list(string)` | `["ap-south-1a", "ap-south-1b", "ap-south-1c"]` |
| `public_subnets` | Public subnet CIDRs (for NAT Gateway) | `list(string)` | `["10.0.1.0/24", ...]` |
| `private_subnets` | Private subnet CIDRs (EC2, EFS, DataSync) | `list(string)` | `["10.0.4.0/24", ...]` |
| `datasync_auto_start` | Automatically trigger task execution on apply | `bool` | `true` |
| `datasync_wait_seconds` | Wait time for EC2 user_data before DataSync start | `number` | `180` |

---

## DataSync Task Options

The DataSync task is configured in `terraform/main.tf` with the following enterprise settings:

- **Verification Mode**: `ONLY_FILES_TRANSFERRED` (or `POINT_IN_TIME_CONSISTENT`)
- **Preserve Deleted Files**: `PRESERVE`
- **POSIX Permissions**: `PRESERVE`
- **Preserve Timestamps**: `PRESERVE`
- **In-Transit Encryption**: `TLS1_2`
- **Log Level**: `TRANSFER` (Full transfer logs sent to CloudWatch)

---

## Operational Commands

Terraform exports actionable commands directly in its outputs:

### 1. Connect to Private EC2 Instance via SSM
```bash
aws ssm start-session --target <instance-id> --region ap-south-1
```

### 2. Check EFS Mount & Files on EC2 in One Command
```bash
aws ssm start-session --target <instance-id> --region ap-south-1 \
  --document-name AWS-StartInteractiveCommand \
  --parameters command="ls -la /mnt/efs && cat /var/log/efs-setup.log"
```

### 3. Trigger DataSync Task Manually
```bash
aws datasync start-task-execution --task-arn <datasync-task-arn> --region ap-south-1
```

### 4. Verify Transferred Objects in S3
```bash
aws s3 ls s3://<destination-bucket-name>/ --region ap-south-1
```

---

## Security & Best Practices

1. **Zero Public Ingress**: The EC2 instance and EFS mount targets reside in private subnets with no public IP.
2. **SSM Session Manager**: No SSH keys, no bastion hosts, and no open port 22 in security groups.
3. **VPC Gateway Endpoint for S3**: All S3 traffic remains within AWS's internal private network, eliminating internet egress costs and external exposure.
4. **Least-Privilege IAM Roles**:
   - `datasync_s3_role`: Restricted to Put/Get/List on the specific destination bucket.
   - `datasync_efs_role`: Restricted to ClientMount, ClientWrite, and Describe on the EFS file system.
   - `ec2_instance_role`: Attached with `AmazonSSMManagedInstanceCore` for Session Manager operations.

---

## Troubleshooting & Lessons Learned

| Problem | Root Cause | Solution Applied |
|---|---|---|
| **EFS mount failed on EC2** (`bad option; for several filesystems (e.g. nfs, cifs) you might need a /sbin/mount.<type> helper program`) | `user_data.sh` used `if ! dpkg -l nfs-common`, which returned exit code 0 even when uninstalled, skipping package installation. | Updated user data to verify binary existence using `command -v mount.nfs4`. |
| **EFS mount timed out during boot** | EC2 attempted NFS mount before VPC DNS was fully propagated or available. | Passed Mount Target Private IP (`efs_ip = module.efs.mount_target_ips[0]`) for direct IP mounting (`10.0.4.17:/`) with automatic fallback to DNS. |
| **Only `.aws-datasync-metadata` transferred to S3** | DataSync ran before files were populated on EFS, transferring an empty root folder. | Automated synchronization with EC2 setup flag (`.setup-complete`) and added `datasync_wait_seconds` buffer. |
| **SSH Permission Denied** | Key pair mismatch or security group blocking port 22. | Replaced SSH with AWS SSM Session Manager (`AmazonSSMManagedInstanceCore`), providing instant, passwordless access. |

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.
