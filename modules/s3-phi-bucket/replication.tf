# Replication Configuration
resource "aws_iam_role" "replication" {
  count = var.enable_replication ? 1 : 0

  name = "${local.bucket_name}-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.bucket_name}-replication-role"
    }
  )
}

resource "aws_iam_role_policy" "replication" {
  count = var.enable_replication ? 1 : 0

  name = "${local.bucket_name}-replication-policy"
  role = aws_iam_role.replication[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.phi_bucket.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${aws_s3_bucket.phi_bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = "${aws_s3_bucket.replica[0].arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.sse_algorithm == "aws:kms" ? [
          var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.phi_bucket[0].arn
        ] : []
      },
      {
        Effect = "Allow"
        Action = [
          "kms:GenerateDataKey",
          "kms:Encrypt"
        ]
        Resource = var.sse_algorithm == "aws:kms" ? [
          var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.replica[0].arn
        ] : []
      }
    ]
  })
}

# Provider aws.replica is passed from the parent module

# Replica bucket
# checkov:skip=CKV_AWS_145:Encryption is configured in aws_s3_bucket_server_side_encryption_configuration resource
resource "aws_s3_bucket" "replica" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.replica

  bucket = "${local.bucket_name}-replica"

  tags = merge(
    local.common_tags,
    {
      Name            = "${local.bucket_name}-replica"
      ReplicaOf       = local.bucket_name
      ReplicationRole = "destination"
    }
  )
}

# Replica bucket versioning
resource "aws_s3_bucket_versioning" "replica" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.replica

  bucket = aws_s3_bucket.replica[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Replica bucket public access block
resource "aws_s3_bucket_public_access_block" "replica" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.replica

  bucket = aws_s3_bucket.replica[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# KMS Key for replica bucket
resource "aws_kms_key" "replica" {
  count    = var.enable_replication && var.sse_algorithm == "aws:kms" && var.kms_key_arn == null ? 1 : 0
  provider = aws.replica

  description              = "KMS key for ${local.bucket_name}-replica PHI encryption"
  deletion_window_in_days  = 30
  enable_key_rotation      = true
  is_enabled              = true
  key_usage               = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"

  tags = merge(
    local.common_tags,
    {
      Name            = "${local.bucket_name}-replica-kms-key"
      ReplicationRole = "destination"
    }
  )
}

# KMS Key Alias for replica
resource "aws_kms_alias" "replica" {
  count    = var.enable_replication && var.sse_algorithm == "aws:kms" && var.kms_key_arn == null ? 1 : 0
  provider = aws.replica

  name          = "alias/${local.bucket_name}-replica"
  target_key_id = aws_kms_key.replica[0].key_id
}

# KMS Key Policy for replica
resource "aws_kms_key_policy" "replica" {
  count    = var.enable_replication && var.sse_algorithm == "aws:kms" && var.kms_key_arn == null ? 1 : 0
  provider = aws.replica

  key_id = aws_kms_key.replica[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-policy-${local.bucket_name}-replica"
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
        Sid    = "Allow S3 replication to use the key"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.replication[0].arn
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

# Replica bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "replica" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.replica

  bucket = aws_s3_bucket.replica[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.sse_algorithm
      kms_master_key_id = var.sse_algorithm == "aws:kms" ? (var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.replica[0].arn) : null
    }
    bucket_key_enabled = var.sse_algorithm == "aws:kms" ? true : false
  }
}

# Replication configuration
resource "aws_s3_bucket_replication_configuration" "phi_bucket" {
  count = var.enable_replication ? 1 : 0

  role   = aws_iam_role.replication[0].arn
  bucket = aws_s3_bucket.phi_bucket.id

  rule {
    id       = "replicate-all-objects"
    status   = "Enabled"
    priority = 1

    filter {}

    delete_marker_replication {
      status = "Enabled"
    }

    destination {
      bucket        = aws_s3_bucket.replica[0].arn
      storage_class = "STANDARD_IA"

      encryption_configuration {
        replica_kms_key_id = var.sse_algorithm == "aws:kms" ? (var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.replica[0].arn) : null
      }

      metrics {
        status = "Enabled"
        event_threshold {
          minutes = 15
        }
      }

      replication_time {
        status = "Enabled"
        time {
          minutes = 15
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.phi_bucket]
}