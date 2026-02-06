resource "aws_efs_file_system" "this" {
  creation_token   = var.creation_token
  encrypted        = var.encrypted
  performance_mode = var.performance_mode
  throughput_mode  = var.throughput_mode
  
  tags = merge(
    {
      Name = var.name
    },
    var.tags
  )
}

resource "aws_efs_mount_target" "this" {
  count           = length(var.subnet_ids)
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = var.security_group_ids
}

resource "aws_efs_access_point" "this" {
  count          = var.create_access_point ? 1 : 0
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    gid = var.access_point_posix_user.gid
    uid = var.access_point_posix_user.uid
  }

  root_directory {
    path = var.access_point_root_directory.path
    creation_info {
      owner_gid   = var.access_point_root_directory.owner_gid
      owner_uid   = var.access_point_root_directory.owner_uid
      permissions = var.access_point_root_directory.permissions
    }
  }
}