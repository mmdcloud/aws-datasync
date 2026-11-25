variable "name" {
  description = "Name of the EFS file system"
  type        = string
}

variable "creation_token" {
  description = "A unique name used as reference when creating the EFS"
  type        = string
}

variable "encrypted" {
  description = "Enable encryption at rest"
  type        = bool
  default     = true
}

variable "performance_mode" {
  description = "The performance mode of the file system"
  type        = string
  default     = "generalPurpose"
  validation {
    condition     = contains(["generalPurpose", "maxIO"], var.performance_mode)
    error_message = "Performance mode must be either generalPurpose or maxIO."
  }
}

variable "throughput_mode" {
  description = "Throughput mode for the file system"
  type        = string
  default     = "bursting"
  validation {
    condition     = contains(["bursting", "provisioned", "elastic"], var.throughput_mode)
    error_message = "Throughput mode must be bursting, provisioned, or elastic."
  }
}

variable "subnet_ids" {
  description = "List of subnet IDs for mount targets"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for mount targets"
  type        = list(string)
}

variable "tags" {
  description = "Additional tags for the EFS file system"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------------------
# Backup Policy Variables
# -----------------------------------------------------------------------------------------
variable "enable_backup_policy" {
  description = "Whether to create a backup policy for the EFS file system"
  type        = bool
  default     = false
}

variable "backup_policy_status" {
  description = "Status of the backup policy. Valid values: ENABLED, DISABLED"
  type        = string
  default     = "ENABLED"
  validation {
    condition     = contains(["ENABLED", "DISABLED"], var.backup_policy_status)
    error_message = "Backup policy status must be ENABLED or DISABLED."
  }
}

# -----------------------------------------------------------------------------------------
# File System Policy Variables
# -----------------------------------------------------------------------------------------
variable "policy" {
  description = "The JSON formatted file system policy for the EFS file system"
  type        = string
  default     = null
}

variable "bypass_policy_lockout_safety_check" {
  description = "A flag to indicate whether to bypass the aws_efs_file_system_policy lockout safety check"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------------------
# Replication Configuration Variables
# -----------------------------------------------------------------------------------------
variable "create_replication_configuration" {
  description = "Whether to create an EFS replication configuration"
  type        = bool
  default     = false
}

variable "replication_destination" {
  description = "Destination configuration for EFS replication (e.g. region, kms_key_id, availability_zone_name, file_system_id)"
  type        = any
  default     = null
}

# -----------------------------------------------------------------------------------------
# Access Point Variables
# -----------------------------------------------------------------------------------------
variable "create_access_point" {
  description = "Whether to create an EFS access point"
  type        = bool
  default     = false
}

variable "access_point_posix_user" {
  description = "POSIX user configuration for access point (e.g. uid, gid, secondary_gids)"
  type        = any
  default = {
    gid = 1000
    uid = 1000
  }
}

variable "access_point_root_directory" {
  description = "Root directory configuration for access point (e.g. path, owner_gid, owner_uid, permissions)"
  type        = any
  default = {
    path        = "/data"
    owner_gid   = 1000
    owner_uid   = 1000
    permissions = "755"
  }
}
