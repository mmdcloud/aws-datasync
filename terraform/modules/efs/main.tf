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

# -----------------------------------------------------------------------------------------
# EFS Backup Policy
# -----------------------------------------------------------------------------------------
resource "aws_efs_backup_policy" "this" {
  count          = var.enable_backup_policy ? 1 : 0
  file_system_id = aws_efs_file_system.this.id

  backup_policy {
    status = var.backup_policy_status
  }
}

# -----------------------------------------------------------------------------------------
# EFS File System Policy
# -----------------------------------------------------------------------------------------
resource "aws_efs_file_system_policy" "this" {
  count                              = var.policy != null && var.policy != "" ? 1 : 0
  file_system_id                     = aws_efs_file_system.this.id
  policy                             = var.policy
  bypass_policy_lockout_safety_check = var.bypass_policy_lockout_safety_check
}

# -----------------------------------------------------------------------------------------
# EFS Replication Configuration
# -----------------------------------------------------------------------------------------
resource "aws_efs_replication_configuration" "this" {
  count                 = var.create_replication_configuration && var.replication_destination != null ? 1 : 0
  source_file_system_id = aws_efs_file_system.this.id

  destination {
    region                 = lookup(var.replication_destination, "region", null)
    kms_key_id             = lookup(var.replication_destination, "kms_key_id", null)
    availability_zone_name = lookup(var.replication_destination, "availability_zone_name", null)
    file_system_id         = lookup(var.replication_destination, "file_system_id", null)
  }
}

# -----------------------------------------------------------------------------------------
# EFS Access Point
# -----------------------------------------------------------------------------------------
resource "aws_efs_access_point" "this" {
  count          = var.create_access_point ? 1 : 0
  file_system_id = aws_efs_file_system.this.id

  dynamic "posix_user" {
    for_each = var.access_point_posix_user != null ? [var.access_point_posix_user] : []
    content {
      gid            = posix_user.value.gid
      uid            = posix_user.value.uid
      secondary_gids = lookup(posix_user.value, "secondary_gids", null)
    }
  }

  dynamic "root_directory" {
    for_each = var.access_point_root_directory != null ? [var.access_point_root_directory] : []
    content {
      path = lookup(root_directory.value, "path", "/")

      dynamic "creation_info" {
        for_each = lookup(root_directory.value, "owner_uid", null) != null && lookup(root_directory.value, "owner_gid", null) != null ? [root_directory.value] : []
        content {
          owner_gid   = creation_info.value.owner_gid
          owner_uid   = creation_info.value.owner_uid
          permissions = lookup(creation_info.value, "permissions", "755")
        }
      }
    }
  }

  tags = merge(
    {
      Name = "${var.name}-ap"
    },
    var.tags
  )
}
