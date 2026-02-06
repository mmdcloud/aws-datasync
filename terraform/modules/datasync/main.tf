# S3 location for DataSync
resource "aws_datasync_location_s3" "this" {
  s3_bucket_arn    = var.s3_bucket_arn
  s3_storage_class = var.s3_storage_class
  subdirectory     = var.s3_subdirectory
  
  s3_config {
    bucket_access_role_arn = var.s3_bucket_access_role_arn
  }

  tags = var.tags
}

# EFS location for DataSync
resource "aws_datasync_location_efs" "this" {
  efs_file_system_arn         = var.efs_file_system_arn
  file_system_access_role_arn = var.efs_access_role_arn
  access_point_arn            = var.efs_access_point_arn
  subdirectory                = var.efs_subdirectory
  
  ec2_config {
    security_group_arns = var.security_group_arns
    subnet_arn          = var.subnet_arn
  }
  
  in_transit_encryption = var.in_transit_encryption
  
  tags = var.tags
}

# DataSync task
resource "aws_datasync_task" "this" {
  name                     = var.task_name
  source_location_arn      = var.source_location_arn != null ? var.source_location_arn : aws_datasync_location_efs.this.arn
  destination_location_arn = var.destination_location_arn != null ? var.destination_location_arn : aws_datasync_location_s3.this.arn
  
  options {
    verify_mode            = var.task_options.verify_mode
    preserve_deleted_files = var.task_options.preserve_deleted_files
    preserve_devices       = var.task_options.preserve_devices
    posix_permissions      = var.task_options.posix_permissions
    uid                    = var.task_options.uid
    gid                    = var.task_options.gid
    atime                  = var.task_options.atime
    mtime                  = var.task_options.mtime
    transfer_mode          = var.task_options.transfer_mode
    overwrite_mode         = var.task_options.overwrite_mode
    task_queueing          = var.task_options.task_queueing
    log_level              = var.task_options.log_level
  }
  
  cloudwatch_log_group_arn = var.cloudwatch_log_group_arn
  
  tags = var.tags
}