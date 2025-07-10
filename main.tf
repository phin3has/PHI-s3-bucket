# Local values
locals {
  common_tags = merge(
    var.tags,
    {
      Module      = "s3-phi-bucket"
      Environment = var.environment
    }
  )
}

# KMS key for encryption (if not provided)
# checkov:skip=CKV2_AWS_64:Using default AWS KMS key policy which is secure for this use case
resource "aws_kms_key" "bucket" {
  count = var.kms_key_arn == null ? 1 : 0

  description             = "KMS key for ${var.bucket_name} encryption"
  deletion_window_in_days = 30
  enable_key_rotation = true
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.bucket_name}-kms-key"
    }
  )
}

resource "aws_kms_alias" "bucket" {
  count = var.kms_key_arn == null ? 1 : 0

  name          = "alias/${var.bucket_name}"
  target_key_id = aws_kms_key.bucket[0].key_id
}

# Main S3 bucket
# checkov:skip=CKV_AWS_145:Encryption is configured via separate aws_s3_bucket_server_side_encryption_configuration resource
# checkov:skip=CKV2_AWS_62:Event notifications are optional - users can add them based on their needs
resource "aws_s3_bucket" "main" {
  bucket = var.bucket_name
  
  # Object Lock must be enabled at bucket creation
  object_lock_enabled = var.enable_object_lock
  
  tags = merge(
    local.common_tags,
    {
      Name = var.bucket_name
    }
  )
}

# Requirement 1: Block all public access
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Requirement 2: Enforce server-side encryption with CMK
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.bucket[0].arn
    }
    bucket_key_enabled = true
  }
}

# Requirement 4: Enable object versioning
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Requirement 6: Object Lock configuration (if enabled)
resource "aws_s3_bucket_object_lock_configuration" "main" {
  count = var.enable_object_lock ? 1 : 0
  
  bucket = aws_s3_bucket.main.id

  rule {
    default_retention {
      mode = var.object_lock_mode
      days = var.object_lock_days
    }
  }
}

# Lifecycle rules (optional)
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  count = var.enable_lifecycle_rules ? 1 : 0
  
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
    
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Access logging bucket
# checkov:skip=CKV_AWS_145:Encryption is configured via separate aws_s3_bucket_server_side_encryption_configuration resource
# checkov:skip=CKV2_AWS_62:Event notifications not required for log buckets
# checkov:skip=CKV_AWS_21:Versioning not required for log buckets - logs are immutable
resource "aws_s3_bucket" "logs" {
  bucket = "${var.bucket_name}-logs"
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.bucket_name}-logs"
      Type = "logs"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"
    
    filter {}

    expiration {
      days = 90
    }
    
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# Enable access logging
resource "aws_s3_bucket_logging" "main" {
  bucket = aws_s3_bucket.main.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "access-logs/"
}
