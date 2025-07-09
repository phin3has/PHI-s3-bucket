locals {
  bucket_name = "${var.bucket_name}-${var.environment}"
  
  common_tags = merge(
    var.tags,
    {
      Environment       = var.environment
      ManagedBy        = "terraform"
      Purpose          = "phi-storage"
      ComplianceScope  = "HIPAA"
      DataClassification = "PHI"
    }
  )
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# S3 Bucket
# checkov:skip=CKV_AWS_145:Encryption is configured in aws_s3_bucket_server_side_encryption_configuration resource
resource "aws_s3_bucket" "phi_bucket" {
  bucket              = local.bucket_name
  object_lock_enabled = var.enable_object_lock

  tags = merge(
    local.common_tags,
    {
      Name = local.bucket_name
    }
  )
}

# Bucket Ownership Controls
resource "aws_s3_bucket_ownership_controls" "phi_bucket" {
  bucket = aws_s3_bucket.phi_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "phi_bucket" {
  bucket = aws_s3_bucket.phi_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning
resource "aws_s3_bucket_versioning" "phi_bucket" {
  bucket = aws_s3_bucket.phi_bucket.id

  versioning_configuration {
    status     = var.versioning_enabled ? "Enabled" : "Suspended"
    mfa_delete = var.mfa_delete ? "Enabled" : "Disabled"
  }
}

# Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "phi_bucket" {
  bucket = aws_s3_bucket.phi_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.sse_algorithm
      kms_master_key_id = var.sse_algorithm == "aws:kms" ? (var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.phi_bucket[0].arn) : null
    }
    bucket_key_enabled = var.sse_algorithm == "aws:kms" ? true : false
  }
}

# KMS Key for encryption (if not provided)
resource "aws_kms_key" "phi_bucket" {
  count = var.sse_algorithm == "aws:kms" && var.kms_key_arn == null ? 1 : 0

  description              = "KMS key for ${local.bucket_name} PHI encryption"
  deletion_window_in_days  = 30
  enable_key_rotation      = true
  is_enabled              = true
  key_usage               = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.bucket_name}-kms-key"
    }
  )
}

# KMS Key Alias
resource "aws_kms_alias" "phi_bucket" {
  count = var.sse_algorithm == "aws:kms" && var.kms_key_arn == null ? 1 : 0

  name          = "alias/${local.bucket_name}"
  target_key_id = aws_kms_key.phi_bucket[0].key_id
}

# KMS Key Policy
resource "aws_kms_key_policy" "phi_bucket" {
  count = var.sse_algorithm == "aws:kms" && var.kms_key_arn == null ? 1 : 0

  key_id = aws_kms_key.phi_bucket[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-policy-${local.bucket_name}"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 to use the key"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail to use the key"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lifecycle Rules
resource "aws_s3_bucket_lifecycle_configuration" "phi_bucket" {
  count = var.enable_lifecycle_rules ? 1 : 0

  bucket = aws_s3_bucket.phi_bucket.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      dynamic "filter" {
        for_each = rule.value.prefix != null || rule.value.tags != null ? [1] : []
        content {
          prefix = rule.value.prefix

          dynamic "tag" {
            for_each = rule.value.tags != null ? rule.value.tags : {}
            content {
              key   = tag.key
              value = tag.value
            }
          }
        }
      }

      dynamic "transition" {
        for_each = rule.value.transition_days != null ? [1] : []
        content {
          days          = rule.value.transition_days
          storage_class = rule.value.transition_storage_class
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration_days != null ? [1] : []
        content {
          days = rule.value.expiration_days
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration_days != null ? [1] : []
        content {
          noncurrent_days = rule.value.noncurrent_version_expiration_days
        }
      }
    }
  }
}

# Intelligent Tiering Configuration
resource "aws_s3_bucket_intelligent_tiering_configuration" "phi_bucket" {
  count = var.enable_intelligent_tiering ? 1 : 0

  bucket = aws_s3_bucket.phi_bucket.id
  name   = "${local.bucket_name}-intelligent-tiering"

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }
}

# Object Lock Configuration
resource "aws_s3_bucket_object_lock_configuration" "phi_bucket" {
  count = var.enable_object_lock && var.object_lock_configuration != null ? 1 : 0

  bucket = aws_s3_bucket.phi_bucket.id

  rule {
    default_retention {
      mode  = var.object_lock_configuration.mode
      days  = var.object_lock_configuration.days
      years = var.object_lock_configuration.years
    }
  }
}

# Logging Bucket (for access logs)
# checkov:skip=CKV_AWS_145:Encryption is configured in aws_s3_bucket_server_side_encryption_configuration resource
resource "aws_s3_bucket" "log_bucket" {
  count = var.enable_access_logging ? 1 : 0

  bucket = "${local.bucket_name}-logs"

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.bucket_name}-logs"
      Purpose = "access-logs"
    }
  )
}

# Logging Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "log_bucket" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.log_bucket[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Logging Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.log_bucket[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.sse_algorithm == "aws:kms" ? "aws:kms" : "AES256"
      kms_master_key_id = var.sse_algorithm == "aws:kms" ? (var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.phi_bucket[0].arn) : null
    }
  }
}

# Logging Bucket Lifecycle
resource "aws_s3_bucket_lifecycle_configuration" "log_bucket" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.log_bucket[0].id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}

# Bucket Logging
resource "aws_s3_bucket_logging" "phi_bucket" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.phi_bucket.id

  target_bucket = aws_s3_bucket.log_bucket[0].id
  target_prefix = "access-logs/"
}

# Request Payment Configuration
resource "aws_s3_bucket_request_payment_configuration" "phi_bucket" {
  bucket = aws_s3_bucket.phi_bucket.id
  payer  = var.request_payer
}

# Transfer Acceleration
resource "aws_s3_bucket_accelerate_configuration" "phi_bucket" {
  count = var.transfer_acceleration ? 1 : 0

  bucket = aws_s3_bucket.phi_bucket.id
  status = "Enabled"
}

# CORS Configuration
resource "aws_s3_bucket_cors_configuration" "phi_bucket" {
  count = length(var.cors_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.phi_bucket.id

  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      allowed_headers = cors_rule.value.allowed_headers
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      expose_headers  = cors_rule.value.expose_headers
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}

# Analytics Configuration
resource "aws_s3_bucket_analytics_configuration" "phi_bucket" {
  count = var.analytics_configuration != null ? 1 : 0

  bucket = aws_s3_bucket.phi_bucket.id
  name   = var.analytics_configuration.id

  dynamic "filter" {
    for_each = var.analytics_configuration.prefix != null ? [1] : []
    content {
      prefix = var.analytics_configuration.prefix
    }
  }

  storage_class_analysis {
    data_export {
      destination {
        s3_bucket_destination {
          bucket_arn = "arn:aws:s3:::${var.analytics_configuration.output_bucket}"
          prefix     = var.analytics_configuration.output_prefix
        }
      }
    }
  }
}

# Inventory Configuration
resource "aws_s3_bucket_inventory" "phi_bucket" {
  count = var.inventory_configuration != null ? 1 : 0

  bucket = aws_s3_bucket.phi_bucket.id
  name   = var.inventory_configuration.id

  included_object_versions = var.inventory_configuration.included_object_versions

  schedule {
    frequency = var.inventory_configuration.schedule_frequency
  }

  destination {
    bucket {
      format     = var.inventory_configuration.output_format
      bucket_arn = "arn:aws:s3:::${var.inventory_configuration.output_bucket}"
      prefix     = var.inventory_configuration.output_prefix

      encryption {
        sse_s3 {
          # Uses S3-managed encryption for inventory files
        }
      }
    }
  }

  optional_fields = var.inventory_configuration.optional_fields
}

# EventBridge Notifications
resource "aws_s3_bucket_notification" "phi_bucket" {
  count = length(var.event_notification_configs) > 0 ? 1 : 0

  bucket      = aws_s3_bucket.phi_bucket.id
  eventbridge = true
}

# S3 Access Points
resource "aws_s3_access_point" "phi_bucket" {
  for_each = { for ap in var.access_point_configs : ap.name => ap }

  bucket = aws_s3_bucket.phi_bucket.id
  name   = each.value.name

  vpc_configuration {
    vpc_id = each.value.vpc_id
  }

  public_access_block_configuration {
    block_public_acls       = each.value.public_access_block
    block_public_policy     = each.value.public_access_block
    ignore_public_acls      = each.value.public_access_block
    restrict_public_buckets = each.value.public_access_block
  }
}

# Access Point Policies
resource "aws_s3control_access_point_policy" "phi_bucket" {
  for_each = { 
    for ap in var.access_point_configs : ap.name => ap 
    if ap.policy != null 
  }

  access_point_arn = aws_s3_access_point.phi_bucket[each.key].arn
  policy           = each.value.policy
}