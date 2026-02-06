variable "task_name" {
  description = "Name of the DataSync task"
  type        = string
}

# S3 Location Variables
variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  type        = string
}

variable "s3_storage_class" {
  description = "S3 storage class"
  type        = string
  default     = "STANDARD"
}

variable "s3_subdirectory" {
  description = "Subdirectory in S3 bucket"
  type        = string
  default     = "/"
}

variable "s3_bucket_access_role_arn" {
  description = "ARN of the IAM role for S3 access"
  type        = string
}

# EFS Location Variables
variable "efs_file_system_arn" {
  description = "ARN of the EFS file system"
  type        = string
}

variable "efs_access_role_arn" {
  description = "ARN of the IAM role for EFS access"
  type        = string
}

variable "efs_access_point_arn" {
  description = "ARN of the EFS access point"
  type        = string
  default     = null
}

variable "efs_subdirectory" {
  description = "Subdirectory in EFS"
  type        = string
  default     = "/data"
}

variable "security_group_arns" {
  description = "List of security group ARNs for EFS access"
  type        = list(string)
}

variable "subnet_arn" {
  description = "ARN of the subnet for EFS access"
  type        = string
}

variable "in_transit_encryption" {
  description = "Encryption in transit for EFS"
  type        = string
  default     = "TLS1_2"
  validation {
    condition     = contains(["NONE", "TLS1_2"], var.in_transit_encryption)
    error_message = "In transit encryption must be NONE or TLS1_2."
  }
}

# Task Variables
variable "source_location_arn" {
  description = "ARN of the source location (if not using the EFS location created by this module)"
  type        = string
  default     = null
}

variable "destination_location_arn" {
  description = "ARN of the destination location (if not using the S3 location created by this module)"
  type        = string
  default     = null
}

variable "task_options" {
  description = "DataSync task options"
  type = object({
    verify_mode            = string
    preserve_deleted_files = string
    preserve_devices       = string
    posix_permissions      = string
    uid                    = string
    gid                    = string
    atime                  = string
    mtime                  = string
    transfer_mode          = string
    overwrite_mode         = string
    task_queueing          = string
    log_level              = string
  })
  default = {
    verify_mode            = "ONLY_FILES_TRANSFERRED"
    preserve_deleted_files = "REMOVE"
    preserve_devices       = "NONE"
    posix_permissions      = "PRESERVE"
    uid                    = "NONE"
    gid                    = "NONE"
    atime                  = "BEST_EFFORT"
    mtime                  = "PRESERVE"
    transfer_mode          = "CHANGED"
    overwrite_mode         = "ALWAYS"
    task_queueing          = "ENABLED"
    log_level              = "TRANSFER"
  }
}

variable "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for DataSync logs"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to DataSync resources"
  type        = map(string)
  default     = {}
}