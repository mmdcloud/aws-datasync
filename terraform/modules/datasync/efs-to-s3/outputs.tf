output "s3_location_arn" {
  description = "ARN of the S3 DataSync location"
  value       = aws_datasync_location_s3.this.arn
}

output "s3_location_uri" {
  description = "URI of the S3 DataSync location"
  value       = aws_datasync_location_s3.this.uri
}

output "efs_location_arn" {
  description = "ARN of the EFS DataSync location"
  value       = aws_datasync_location_efs.this.arn
}

output "efs_location_uri" {
  description = "URI of the EFS DataSync location"
  value       = aws_datasync_location_efs.this.uri
}

output "task_arn" {
  description = "ARN of the DataSync task"
  value       = aws_datasync_task.this.arn
}

output "task_id" {
  description = "ID of the DataSync task"
  value       = aws_datasync_task.this.id
}