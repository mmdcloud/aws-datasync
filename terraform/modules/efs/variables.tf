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

variable "create_access_point" {
  description = "Whether to create an EFS access point"
  type        = bool
  default     = false
}

variable "access_point_posix_user" {
  description = "POSIX user configuration for access point"
  type = object({
    gid = number
    uid = number
  })
  default = {
    gid = 1000
    uid = 1000
  }
}

variable "access_point_root_directory" {
  description = "Root directory configuration for access point"
  type = object({
    path        = string
    owner_gid   = number
    owner_uid   = number
    permissions = string
  })
  default = {
    path        = "/data"
    owner_gid   = 1000
    owner_uid   = 1000
    permissions = "755"
  }
}