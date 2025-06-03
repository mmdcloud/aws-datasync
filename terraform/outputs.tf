output "source_bucket_name" {
  value = aws_s3_bucket.source_bucket.bucket
}

output "efs_id" {
  value = aws_efs_file_system.destination_efs.id
}

output "datasync_task_arn" {
  value = aws_datasync_task.s3_to_efs.arn
}