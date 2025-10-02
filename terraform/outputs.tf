output "destination_bucket_name" {
  value = module.destination_bucket.bucket
}

output "efs_id" {
  value = aws_efs_file_system.efs.id
}

output "datasync_task_arn" {
  value = aws_datasync_task.s3_to_efs.arn
}