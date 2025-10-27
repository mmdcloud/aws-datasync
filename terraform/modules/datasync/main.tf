# Create S3 location for DataSync
resource "aws_datasync_location_s3" "s3_location" {
  s3_bucket_arn = module.destination_bucket.arn
  subdirectory  = "/"
  s3_config {
    bucket_access_role_arn = module.datasync_role.arn
  }
}

# Create EFS location for DataSync
resource "aws_datasync_location_efs" "efs_location" {
  efs_file_system_arn = aws_efs_file_system.efs.arn
  ec2_config {
    security_group_arns = [module.efs_sg.arn]
    subnet_arn          = module.public_subnets.subnets[0].arn
  }
  depends_on = [aws_efs_mount_target.efs_mt]
}

# Add this resource for CloudWatch Log Group
resource "aws_cloudwatch_log_group" "datasync_logs" {
  name              = "/aws/datasync/s3-to-efs-sync"
  retention_in_days = 7
}

# Create DataSync task
resource "aws_datasync_task" "s3_to_efs" {
  name                     = "s3-to-efs-sync"
  source_location_arn      = aws_datasync_location_efs.efs_location.arn
  destination_location_arn = aws_datasync_location_s3.s3_location.arn
  options {
    verify_mode            = "POINT_IN_TIME_CONSISTENT"
    preserve_deleted_files = "PRESERVE"
    preserve_devices       = "NONE"
    posix_permissions      = "PRESERVE"
    uid                    = "NONE"
    gid                    = "NONE"
    atime                  = "BEST_EFFORT"
    mtime                  = "PRESERVE"
    task_queueing          = "ENABLED"
    log_level              = "TRANSFER"
  }
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.datasync_logs.arn
  depends_on = [
    aws_datasync_location_s3.s3_location,
    aws_datasync_location_efs.efs_location
  ]
}