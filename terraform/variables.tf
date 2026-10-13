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