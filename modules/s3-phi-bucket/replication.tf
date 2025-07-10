# Requirement 7: Cross-region replication
# This file handles replication configuration when enabled
# Note: Requires aws.replica provider to be configured when enable_replication = true

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
    
    resources = ["${aws_s3_bucket.main.arn}/*"]
  }

  statement {
    effect = "Allow"
    
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    
    resources = [var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.bucket[0].arn]
  }
}

# Replication configuration (without creating replica bucket)
resource "aws_s3_bucket_replication_configuration" "main" {
  count = var.enable_replication && var.replica_bucket_arn != null ? 1 : 0

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
      bucket        = var.replica_bucket_arn
      storage_class = "STANDARD_IA"

      dynamic "encryption_configuration" {
        for_each = var.replica_kms_key_arn != null ? [1] : []
        content {
          replica_kms_key_id = var.replica_kms_key_arn
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.main]
}