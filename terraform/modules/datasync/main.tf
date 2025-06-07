# Create S3 location for DataSync
resource "aws_datasync_location_s3" "s3_location" {
  s3_bucket_arn = aws_s3_bucket.source_bucket.arn
  subdirectory  = "/"

  s3_config {
    bucket_access_role_arn = aws_iam_role.datasync_role.arn
  }

  depends_on = [aws_iam_role_policy_attachment.datasync_attach]
}

# Create EFS location for DataSync
resource "aws_datasync_location_efs" "efs_location" {
  efs_file_system_arn = aws_efs_mount_target.efs_mount.file_system_arn

  ec2_config {
    security_group_arns = [aws_security_group.efs_sg.arn]
    subnet_arn          = aws_subnet.example.arn
  }
}

# Create DataSync task
resource "aws_datasync_task" "s3_to_efs" {
  name                     = "s3-to-efs-sync"
  source_location_arn      = aws_datasync_location_s3.s3_location.arn
  destination_location_arn = aws_datasync_location_efs.efs_location.arn

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