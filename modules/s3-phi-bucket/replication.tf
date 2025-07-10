# Requirement 7: Cross-region replication

# IAM role for replication
resource "aws_iam_role" "replication" {
  count = var.enable_replication ? 1 : 0

  name               = "${var.bucket_name}-replication-role"
  assume_role_policy = data.aws_iam_policy_document.replication_assume_role[0].json
  
  tags = local.common_tags
}

data "aws_iam_policy_document" "replication_assume_role" {
  count = var.enable_replication ? 1 : 0

  statement {
    effect = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    
    actions = ["sts:AssumeRole"]
  }
}

# IAM policy for replication
resource "aws_iam_role_policy" "replication" {
  count = var.enable_replication ? 1 : 0

  name   = "${var.bucket_name}-replication-policy"
  role   = aws_iam_role.replication[0].id
  policy = data.aws_iam_policy_document.replication[0].json
}

data "aws_iam_policy_document" "replication" {
  count = var.enable_replication ? 1 : 0

  statement {
    effect = "Allow"
    
    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket"
    ]
    
    resources = [aws_s3_bucket.main.arn]
  }

  statement {
    effect = "Allow"
    
    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging"
    ]
    
    resources = ["${aws_s3_bucket.main.arn}/*"]
  }

  statement {
    effect = "Allow"
    
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags"
    ]
    
    resources = ["${aws_s3_bucket.replica[0].arn}/*"]
  }

  statement {
    effect = "Allow"
    
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    
    resources = [var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.bucket[0].arn]
  }

  statement {
    effect = "Allow"
    
    actions = [
      "kms:Encrypt",
      "kms:GenerateDataKey"
    ]
    
    resources = [aws_kms_key.replica[0].arn]
  }
}

# Replica bucket in different region
resource "aws_s3_bucket" "replica" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.replica

  bucket = "${var.bucket_name}-replica"
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.bucket_name}-replica"
      Type = "replica"
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

# KMS key for replica bucket
resource "aws_kms_key" "replica" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.replica

  description             = "KMS key for ${var.bucket_name} replica encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.bucket_name}-replica-kms-key"
    }
  )
}

resource "aws_kms_alias" "replica" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.replica

  name          = "alias/${var.bucket_name}-replica"
  target_key_id = aws_kms_key.replica[0].key_id
}

# Replica bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "replica" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.replica
  
  bucket = aws_s3_bucket.replica[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.replica[0].arn
    }
    bucket_key_enabled = true
  }
}

# Replication configuration
resource "aws_s3_bucket_replication_configuration" "main" {
  count = var.enable_replication ? 1 : 0

  role   = aws_iam_role.replication[0].arn
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "replicate-all"
    status = "Enabled"

    delete_marker_replication {
      status = "Enabled"
    }

    filter {}

    destination {
      bucket        = aws_s3_bucket.replica[0].arn
      storage_class = "STANDARD_IA"

      encryption_configuration {
        replica_kms_key_id = aws_kms_key.replica[0].arn
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.main]
}