# Bucket Policy
data "aws_iam_policy_document" "bucket_policy" {
  # Deny unencrypted object uploads
  statement {
    sid    = "DenyUnencryptedObjectUploads"
    effect = "Deny"
    
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    
    actions = ["s3:PutObject"]
    
    resources = ["${aws_s3_bucket.phi_bucket.arn}/*"]
    
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = [var.sse_algorithm == "aws:kms" ? "aws:kms" : "AES256"]
    }
  }

  # Deny non-SSL requests
  statement {
    sid    = "DenyInsecureConnections"
    effect = "Deny"
    
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    
    actions = ["s3:*"]
    
    resources = [
      aws_s3_bucket.phi_bucket.arn,
      "${aws_s3_bucket.phi_bucket.arn}/*"
    ]
    
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Deny requests that don't use the specified KMS key
  dynamic "statement" {
    for_each = var.sse_algorithm == "aws:kms" ? [1] : []
    
    content {
      sid    = "DenyIncorrectEncryptionKey"
      effect = "Deny"
      
      principals {
        type        = "*"
        identifiers = ["*"]
      }
      
      actions = ["s3:PutObject"]
      
      resources = ["${aws_s3_bucket.phi_bucket.arn}/*"]
      
      condition {
        test     = "StringNotEqualsIfExists"
        variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
        values   = [var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.phi_bucket[0].arn]
      }
    }
  }

  # Deny deletion of objects for compliance
  statement {
    sid    = "DenyObjectDeletion"
    effect = "Deny"
    
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    
    actions = [
      "s3:DeleteObject",
      "s3:DeleteObjectVersion"
    ]
    
    resources = ["${aws_s3_bucket.phi_bucket.arn}/*"]
    
    condition {
      test     = "StringNotLike"
      variable = "aws:userid"
      values   = ["AIDAI*"] # Replace with specific IAM user/role IDs that should have delete permissions
    }
  }

  # Require MFA for delete operations (if MFA delete is enabled)
  dynamic "statement" {
    for_each = var.mfa_delete ? [1] : []
    
    content {
      sid    = "RequireMFAForDelete"
      effect = "Deny"
      
      principals {
        type        = "*"
        identifiers = ["*"]
      }
      
      actions = [
        "s3:DeleteObject",
        "s3:DeleteObjectVersion"
      ]
      
      resources = ["${aws_s3_bucket.phi_bucket.arn}/*"]
      
      condition {
        test     = "BoolIfExists"
        variable = "aws:MultiFactorAuthPresent"
        values   = ["false"]
      }
    }
  }

  # Allow CloudTrail to write logs (if this bucket is used for CloudTrail)
  statement {
    sid    = "AllowCloudTrailAclCheck"
    effect = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    
    actions = ["s3:GetBucketAcl"]
    
    resources = [aws_s3_bucket.phi_bucket.arn]
  }

  # Allow AWS Config to read bucket permissions
  statement {
    sid    = "AllowConfigBucketPermissionsCheck"
    effect = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    
    actions = [
      "s3:GetBucketAcl",
      "s3:ListBucket"
    ]
    
    resources = [aws_s3_bucket.phi_bucket.arn]
  }

  # Deny public read/write
  statement {
    sid    = "DenyPublicReadWrite"
    effect = "Deny"
    
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    
    resources = ["${aws_s3_bucket.phi_bucket.arn}/*"]
    
    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

# Apply the bucket policy
resource "aws_s3_bucket_policy" "phi_bucket" {
  bucket = aws_s3_bucket.phi_bucket.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}