output "destination_bucket_name" {
  value = module.destination_bucket.bucket
}

output "efs_id" {
  value = module.efs.id
}

output "datasync_task_arn" {
  description = "ARN of the DataSync task"
  value       = module.datasync.task_arn
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 mount instance"
  value       = module.efs_mount_instance.public_ip
}