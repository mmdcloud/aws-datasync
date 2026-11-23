variable "region" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "azs" {
  type = list(string)
}

variable "private_key_path" {
  description = "Path to SSH private key for EC2 verification (leave empty to skip SSH check)"
  type        = string
  default     = ""
}

variable "datasync_auto_start" {
  description = "Whether to automatically trigger DataSync task execution on apply"
  type        = bool
  default     = true
}

variable "datasync_wait_seconds" {
  description = "Seconds to wait for EC2 user_data to finish mounting EFS before triggering DataSync execution"
  type        = number
  default     = 180
}