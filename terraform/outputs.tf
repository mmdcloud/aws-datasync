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

output "ec2_instance_id" {
  description = "Instance ID of the EC2 mount instance"
  value       = module.efs_mount_instance.id
}

output "ec2_private_ip" {
  description = "Private IP of the EC2 mount instance"
  value       = module.efs_mount_instance.private_ip
}

output "ssm_connect_command" {
  description = "Connect to EC2 without SSH keys via AWS SSM Session Manager"
  value       = "aws ssm start-session --target ${module.efs_mount_instance.id} --region ${var.region}"
}

output "datasync_start_command" {
  description = "AWS CLI command to run DataSync task manually anytime"
  value       = "aws datasync start-task-execution --task-arn ${module.datasync.task_arn} --region ${var.region}"
}

output "check_s3_files_command" {
  description = "AWS CLI command to check transferred files in S3"
  value       = "aws s3 ls s3://${module.destination_bucket.bucket}/ --region ${var.region}"
}

output "check_ec2_efs_command" {
  description = "Command to verify EFS mount and files on EC2 via AWS SSM"
  value       = "aws ssm start-session --target ${module.efs_mount_instance.id} --region ${var.region} --document-name AWS-StartInteractiveCommand --parameters command='ls -la /mnt/efs && cat /var/log/efs-setup.log'"
}