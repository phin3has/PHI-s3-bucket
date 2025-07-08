# Data Lake Configuration for PHI Storage
# This example creates a PHI-compliant data lake with analytics capabilities

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "replica"
  region = var.replication_region
}

module "phi_data_lake" {
  source = "../../modules/s3-phi-bucket"

  bucket_name  = "${var.bucket_name}-data-lake"
  environment  = var.environment
  
  # Data lake optimizations
  enable_intelligent_tiering = true
  transfer_acceleration      = true
  enable_replication         = true
  replication_region         = var.replication_region
  
  # Analytics configuration for usage patterns
  analytics_configuration = {
    id            = "access-patterns-analysis"
    output_bucket = var.analytics_output_bucket
    output_prefix = "s3-analytics/${var.bucket_name}/"
  }
  
  # Weekly inventory for data catalog
  inventory_configuration = {
    id                       = "weekly-data-catalog"
    output_bucket            = var.inventory_output_bucket
    output_prefix            = "inventory/${var.bucket_name}/"
    schedule_frequency       = "Weekly"
    included_object_versions = "Current"
    optional_fields          = [
      "Size", 
      "LastModifiedDate", 
      "StorageClass", 
      "ETag", 
      "IsMultipartUploaded", 
      "ReplicationStatus", 
      "EncryptionStatus",
      "IntelligentTieringAccessTier"
    ]
  }
  
  # Multiple access points for different analytics workloads
  access_point_configs = [
    {
      name   = "batch-analytics"
      vpc_id = var.analytics_vpc_id
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect = "Allow"
          Principal = {
            AWS = var.batch_analytics_role_arn
          }
          Action = [
            "s3:GetObject",
            "s3:ListBucket",
            "s3:GetObjectVersion"
          ]
          Resource = ["*"]
        }]
      })
    },
    {
      name   = "streaming-analytics"
      vpc_id = var.streaming_vpc_id
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect = "Allow"
          Principal = {
            AWS = var.streaming_analytics_role_arn
          }
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:ListBucket"
          ]
          Resource = ["*"]
        }]
      })
    },
    {
      name   = "ml-training"
      vpc_id = var.ml_vpc_id
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect = "Allow"
          Principal = {
            AWS = var.ml_training_role_arn
          }
          Action = [
            "s3:GetObject",
            "s3:ListBucket",
            "s3:GetObjectVersion"
          ]
          Resource = ["*"]
          Condition = {
            StringLike = {
              "s3:prefix" = ["training-data/*", "models/*"]
            }
          }
        }]
      })
    }
  ]
  
  # Custom lifecycle rules for data lake tiers
  lifecycle_rules = [
    {
      id                       = "hot-data-tier"
      enabled                  = true
      prefix                   = "hot/"
      transition_days          = 30
      transition_storage_class = "STANDARD_IA"
    },
    {
      id                               = "warm-data-tier"
      enabled                          = true
      prefix                           = "warm/"
      transition_days                  = 90
      transition_storage_class         = "INTELLIGENT_TIERING"
      noncurrent_version_expiration_days = 365
    },
    {
      id                       = "cold-data-tier"
      enabled                  = true
      prefix                   = "cold/"
      transition_days          = 180
      transition_storage_class = "GLACIER"
      expiration_days          = 2555  # 7 years for compliance
    }
  ]
  
  # Event notifications for data processing pipelines
  event_notification_configs = [
    {
      id            = "new-data-arrival"
      events        = ["s3:ObjectCreated:*"]
      filter_prefix = "incoming/"
      filter_suffix = ".parquet"
    },
    {
      id            = "data-deletion"
      events        = ["s3:ObjectRemoved:*"]
      filter_prefix = "archive/"
    }
  ]
  
  # CORS for web-based analytics tools
  cors_rules = [
    {
      allowed_methods = ["GET", "HEAD", "POST"]
      allowed_origins = ["https://analytics.${var.domain_name}"]
      allowed_headers = ["*"]
      expose_headers  = ["ETag", "x-amz-server-side-encryption"]
      max_age_seconds = 3600
    }
  ]
  
  tags = merge(
    var.common_tags,
    {
      Module       = "data-lake"
      DataType     = "PHI"
      Purpose      = "analytics"
      Architecture = "lakehouse"
    }
  )

  providers = {
    aws         = aws
    aws.replica = aws.replica
  }
}

# Security and compliance modules
module "security_hub" {
  source = "../../modules/security-hub"
  
  bucket_name  = module.phi_data_lake.bucket_id
  bucket_arn   = module.phi_data_lake.bucket_arn
  kms_key_arn  = module.phi_data_lake.kms_key_arn
  environment  = var.environment
  
  enable_security_hub = true
  enable_config       = true
  enable_guardduty    = true
  enable_macie        = true
  
  tags = var.common_tags
}

module "monitoring" {
  source = "../../modules/monitoring"
  
  bucket_name  = module.phi_data_lake.bucket_id
  bucket_arn   = module.phi_data_lake.bucket_arn
  environment  = var.environment
  
  enable_sns_notifications = true
  notification_email       = var.notification_email
  enable_cloudwatch_alarms = true
  
  tags = var.common_tags
}

# Variables
variable "aws_region" {
  description = "AWS region for the primary bucket"
  type        = string
  default     = "us-east-1"
}

variable "replication_region" {
  description = "AWS region for the replica bucket"
  type        = string
  default     = "us-west-2"
}

variable "bucket_name" {
  description = "Base name of the S3 bucket"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "domain_name" {
  description = "Domain name for CORS configuration"
  type        = string
}

variable "analytics_vpc_id" {
  description = "VPC ID for batch analytics access point"
  type        = string
}

variable "streaming_vpc_id" {
  description = "VPC ID for streaming analytics access point"
  type        = string
}

variable "ml_vpc_id" {
  description = "VPC ID for ML training access point"
  type        = string
}

variable "batch_analytics_role_arn" {
  description = "IAM role ARN for batch analytics"
  type        = string
}

variable "streaming_analytics_role_arn" {
  description = "IAM role ARN for streaming analytics"
  type        = string
}

variable "ml_training_role_arn" {
  description = "IAM role ARN for ML training"
  type        = string
}

variable "analytics_output_bucket" {
  description = "Bucket for S3 analytics output"
  type        = string
}

variable "inventory_output_bucket" {
  description = "Bucket for S3 inventory output"
  type        = string
}

variable "notification_email" {
  description = "Email for security notifications"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Outputs
output "bucket_id" {
  description = "The name of the data lake bucket"
  value       = module.phi_data_lake.bucket_id
}

output "access_points" {
  description = "Access point details for different workloads"
  value       = module.phi_data_lake.access_points
}

output "analytics_configuration" {
  description = "S3 analytics configuration details"
  value = {
    enabled       = true
    output_bucket = var.analytics_output_bucket
    output_prefix = "s3-analytics/${var.bucket_name}/"
  }
}

output "inventory_configuration" {
  description = "S3 inventory configuration details"
  value = {
    enabled       = true
    output_bucket = var.inventory_output_bucket
    output_prefix = "inventory/${var.bucket_name}/"
    frequency     = "Weekly"
  }
}