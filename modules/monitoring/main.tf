variable "bucket_name" {
  description = "Name of the S3 bucket to monitor"
  type        = string
}

variable "bucket_arn" {
  description = "ARN of the S3 bucket to monitor"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "enable_sns_notifications" {
  description = "Enable SNS notifications for security events"
  type        = bool
  default     = true
}

variable "notification_email" {
  description = "Email address for security notifications"
  type        = string
  default     = ""
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for security metrics"
  type        = bool
  default     = true
}

locals {
  common_tags = merge(
    var.tags,
    {
      Module = "monitoring"
      Environment = var.environment
    }
  )
}

# KMS key for SNS encryption (if not provided)
resource "aws_kms_key" "sns" {
  count = var.enable_sns_notifications && var.kms_key_arn == null ? 1 : 0

  description              = "KMS key for ${var.bucket_name} SNS topic encryption"
  deletion_window_in_days  = 30
  enable_key_rotation      = true
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.bucket_name}-sns-kms-key"
    }
  )
}

resource "aws_kms_alias" "sns" {
  count = var.enable_sns_notifications && var.kms_key_arn == null ? 1 : 0

  name          = "alias/${var.bucket_name}-sns"
  target_key_id = aws_kms_key.sns[0].key_id
}

# SNS Topic for security alerts
resource "aws_sns_topic" "security_alerts" {
  count = var.enable_sns_notifications ? 1 : 0

  name              = "${var.bucket_name}-security-alerts"
  kms_master_key_id = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.sns[0].arn

  tags = merge(
    local.common_tags,
    {
      Name = "${var.bucket_name}-security-alerts"
    }
  )
}

# SNS Topic Subscription
resource "aws_sns_topic_subscription" "security_alerts_email" {
  count = var.enable_sns_notifications && var.notification_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.security_alerts[0].arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# EventBridge Rule for unauthorized access attempts
resource "aws_cloudwatch_event_rule" "unauthorized_access" {
  name        = "${var.bucket_name}-unauthorized-access"
  description = "Detect unauthorized access attempts to PHI bucket"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["s3.amazonaws.com"]
      requestParameters = {
        bucketName = [var.bucket_name]
      }
      errorCode = [
        "AccessDenied",
        "UnauthorizedAccess",
        "Forbidden"
      ]
    }
  })

  tags = local.common_tags
}

# EventBridge Target for unauthorized access
resource "aws_cloudwatch_event_target" "unauthorized_access_sns" {
  count = var.enable_sns_notifications ? 1 : 0

  rule      = aws_cloudwatch_event_rule.unauthorized_access.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts[0].arn
}

# EventBridge Rule for object deletion attempts
resource "aws_cloudwatch_event_rule" "object_deletion" {
  name        = "${var.bucket_name}-object-deletion"
  description = "Detect object deletion attempts in PHI bucket"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["s3.amazonaws.com"]
      eventName = [
        "DeleteObject",
        "DeleteObjects",
        "DeleteObjectVersion"
      ]
      requestParameters = {
        bucketName = [var.bucket_name]
      }
    }
  })

  tags = local.common_tags
}

# EventBridge Target for object deletion
resource "aws_cloudwatch_event_target" "object_deletion_sns" {
  count = var.enable_sns_notifications ? 1 : 0

  rule      = aws_cloudwatch_event_rule.object_deletion.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts[0].arn
}

# EventBridge Rule for bucket policy changes
resource "aws_cloudwatch_event_rule" "bucket_policy_change" {
  name        = "${var.bucket_name}-policy-change"
  description = "Detect bucket policy changes"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["s3.amazonaws.com"]
      eventName = [
        "PutBucketPolicy",
        "DeleteBucketPolicy",
        "PutBucketAcl",
        "PutObjectAcl"
      ]
      requestParameters = {
        bucketName = [var.bucket_name]
      }
    }
  })

  tags = local.common_tags
}

# EventBridge Target for policy changes
resource "aws_cloudwatch_event_target" "bucket_policy_change_sns" {
  count = var.enable_sns_notifications ? 1 : 0

  rule      = aws_cloudwatch_event_rule.bucket_policy_change.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts[0].arn
}

# EventBridge Rule for encryption configuration changes
resource "aws_cloudwatch_event_rule" "encryption_change" {
  name        = "${var.bucket_name}-encryption-change"
  description = "Detect encryption configuration changes"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["s3.amazonaws.com"]
      eventName = [
        "PutBucketEncryption",
        "DeleteBucketEncryption"
      ]
      requestParameters = {
        bucketName = [var.bucket_name]
      }
    }
  })

  tags = local.common_tags
}

# EventBridge Target for encryption changes
resource "aws_cloudwatch_event_target" "encryption_change_sns" {
  count = var.enable_sns_notifications ? 1 : 0

  rule      = aws_cloudwatch_event_rule.encryption_change.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts[0].arn
}

# EventBridge Rule for public access configuration changes
resource "aws_cloudwatch_event_rule" "public_access_change" {
  name        = "${var.bucket_name}-public-access-change"
  description = "Detect public access configuration changes"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["s3.amazonaws.com"]
      eventName = [
        "PutBucketPublicAccessBlock",
        "DeleteBucketPublicAccessBlock"
      ]
      requestParameters = {
        bucketName = [var.bucket_name]
      }
    }
  })

  tags = local.common_tags
}

# EventBridge Target for public access changes
resource "aws_cloudwatch_event_target" "public_access_change_sns" {
  count = var.enable_sns_notifications ? 1 : 0

  rule      = aws_cloudwatch_event_rule.public_access_change.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts[0].arn
}

# EventBridge Rule for large file uploads (potential data exfiltration)
resource "aws_cloudwatch_event_rule" "large_file_upload" {
  name        = "${var.bucket_name}-large-file-upload"
  description = "Detect large file uploads that might indicate data exfiltration"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["s3.amazonaws.com"]
      eventName   = ["PutObject", "CompleteMultipartUpload"]
      requestParameters = {
        bucketName = [var.bucket_name]
      }
    }
  })

  tags = local.common_tags
}

# Lambda function for analyzing large uploads
resource "aws_iam_role" "large_upload_lambda" {
  name = "${var.bucket_name}-large-upload-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "large_upload_lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.large_upload_lambda.name
}

resource "aws_iam_role_policy" "large_upload_lambda_s3" {
  name = "${var.bucket_name}-large-upload-lambda-s3"
  role = aws_iam_role.large_upload_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectAttributes",
          "s3:HeadObject"
        ]
        Resource = "${var.bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.enable_sns_notifications ? aws_sns_topic.security_alerts[0].arn : "*"
      }
    ]
  })
}

# CloudWatch Metrics and Alarms
resource "aws_cloudwatch_metric_alarm" "unauthorized_access_alarm" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.bucket_name}-unauthorized-access"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnauthorizedAPICallsCount"
  namespace           = "CloudTrailMetrics"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors unauthorized API calls"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.enable_sns_notifications ? [aws_sns_topic.security_alerts[0].arn] : []

  tags = local.common_tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "phi_bucket" {
  dashboard_name = "${var.bucket_name}-security-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/S3", "NumberOfObjects", "BucketName", var.bucket_name, "StorageType", "AllStorageTypes"],
            [".", "BucketSizeBytes", ".", ".", ".", "StandardStorage", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Bucket Size and Object Count"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/S3", "AllRequests", "BucketName", var.bucket_name],
            [".", "GetRequests", ".", "."],
            [".", "PutRequests", ".", "."],
            [".", "DeleteRequests", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Request Metrics"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/S3", "4xxErrors", "BucketName", var.bucket_name, { stat = "Sum" }],
            [".", "5xxErrors", ".", ".", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Error Rates"
        }
      }
    ]
  })
}

# Enable CloudTrail for S3 data events
resource "aws_cloudtrail" "phi_bucket" {
  name                          = "${var.bucket_name}-trail"
  s3_bucket_name               = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_logging               = true
  enable_log_file_validation   = true
  kms_key_id                   = var.kms_key_arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${var.bucket_arn}/*"]
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.bucket_name}-trail"
    }
  )
}

# S3 bucket for CloudTrail logs
# checkov:skip=CKV_AWS_145:Encryption is configured in aws_s3_bucket_server_side_encryption_configuration resource
resource "aws_s3_bucket" "cloudtrail" {
  bucket = "${var.bucket_name}-cloudtrail-logs"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.bucket_name}-cloudtrail-logs"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

# Logging bucket for CloudTrail bucket access logs
# checkov:skip=CKV_AWS_145:Encryption is configured in aws_s3_bucket_server_side_encryption_configuration resource
# checkov:skip=CKV2_AWS_6:Public access block is configured in aws_s3_bucket_public_access_block resource
# checkov:skip=CKV_AWS_18:This is the access logs bucket itself
# checkov:skip=CKV2_AWS_61:Lifecycle not needed for access logs
# checkov:skip=CKV2_AWS_62:Event notifications not needed for access logs
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "${var.bucket_name}-cloudtrail-access-logs"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.bucket_name}-cloudtrail-access-logs"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_logging" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  target_bucket = aws_s3_bucket.cloudtrail_logs.id
  target_prefix = "cloudtrail-access-logs/"
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

data "aws_region" "current" {}

# Outputs
output "sns_topic_arn" {
  description = "ARN of the SNS topic for security alerts"
  value       = var.enable_sns_notifications ? aws_sns_topic.security_alerts[0].arn : null
}

output "cloudtrail_name" {
  description = "Name of the CloudTrail"
  value       = aws_cloudtrail.phi_bucket.name
}

output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.phi_bucket.dashboard_name}"
}