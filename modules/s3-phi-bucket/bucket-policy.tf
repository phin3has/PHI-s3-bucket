# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Bucket policy that enforces encryption in transit and restricts access
data "aws_iam_policy_document" "bucket" {
  # Requirement 3: Deny all requests that aren't using HTTPS
  statement {
    sid    = "DenyInsecureConnections"
    effect = "Deny"
    
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    
    actions = ["s3:*"]
    
    resources = [
      aws_s3_bucket.main.arn,
      "${aws_s3_bucket.main.arn}/*"
    ]
    
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Requirement 5: Allow access only from trusted principals
  statement {
    sid    = "AllowTrustedPrincipalsOnly"
    effect = "Allow"
    
    principals {
      type        = "AWS"
      identifiers = length(var.trusted_principal_arns) > 0 ? var.trusted_principal_arns : [data.aws_caller_identity.current.arn]
    }
    
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning"
    ]
    
    resources = [
      aws_s3_bucket.main.arn,
      "${aws_s3_bucket.main.arn}/*"
    ]
  }

  # Deny unencrypted object uploads
  statement {
    sid    = "DenyUnencryptedObjectUploads"
    effect = "Deny"
    
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    
    actions = ["s3:PutObject"]
    
    resources = ["${aws_s3_bucket.main.arn}/*"]
    
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }

  # Deny incorrect KMS key usage
  statement {
    sid    = "DenyIncorrectKMSKey"
    effect = "Deny"
    
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    
    actions = ["s3:PutObject"]
    
    resources = ["${aws_s3_bucket.main.arn}/*"]
    
    condition {
      test     = "StringNotEqualsIfExists"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = [var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.bucket[0].arn]
    }
  }
}

resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id
  policy = data.aws_iam_policy_document.bucket.json
  
  depends_on = [aws_s3_bucket_public_access_block.main]
}