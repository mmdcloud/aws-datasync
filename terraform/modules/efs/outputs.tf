output "id" {
  description = "The ID of the EFS file system"
  value       = aws_efs_file_system.this.id
}

output "arn" {
  description = "The ARN of the EFS file system"
  value       = aws_efs_file_system.this.arn
}

output "dns_name" {
  description = "The DNS name of the EFS file system"
  value       = aws_efs_file_system.this.dns_name
}

output "mount_target_ids" {
  description = "List of mount target IDs"
  value       = aws_efs_mount_target.this[*].id
}

output "access_point_id" {
  description = "The ID of the EFS access point"
  value       = var.create_access_point ? aws_efs_access_point.this[0].id : null
}

output "access_point_arn" {
  description = "The ARN of the EFS access point"
  value       = var.create_access_point ? aws_efs_access_point.this[0].arn : null
}