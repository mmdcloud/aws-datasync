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

output "mount_target_ips" {
  description = "List of mount target IP addresses"
  value       = aws_efs_mount_target.this[*].ip_address
}

output "backup_policy_id" {
  description = "The ID of the EFS backup policy"
  value       = try(aws_efs_backup_policy.this[0].id, null)
}

output "file_system_policy_id" {
  description = "The ID of the EFS file system policy"
  value       = try(aws_efs_file_system_policy.this[0].id, null)
}

output "replication_configuration_id" {
  description = "The ID of the EFS replication configuration"
  value       = try(aws_efs_replication_configuration.this[0].id, null)
}

output "access_point_id" {
  description = "The ID of the EFS access point"
  value       = try(aws_efs_access_point.this[0].id, null)
}

output "access_point_arn" {
  description = "The ARN of the EFS access point"
  value       = try(aws_efs_access_point.this[0].arn, null)
}
