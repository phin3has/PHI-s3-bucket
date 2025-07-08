# Analytics Platform Configuration for PHI Data
# This example creates an analytics-optimized PHI storage with multi-team access

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

module "phi_analytics" {
  source = "../../modules/s3-phi-bucket"

  bucket_name  = "${var.bucket_name}-analytics"
  environment  = var.environment
  
  # Analytics optimizations
  enable_intelligent_tiering = true
  transfer_acceleration      = true
  request_payer             = var.enable_requester_pays ? "Requester" : "BucketOwner"
  
  # Enable features for analytics workloads
  enable_replication    = true
  replication_region    = var.replication_region
  enable_access_logging = true
  versioning_enabled    = true
  
  # CORS configuration for web-based analytics tools
  cors_rules = [
    {
      allowed_methods = ["GET", "HEAD", "POST"]
      allowed_origins = var.analytics_tool_domains
      allowed_headers = ["Authorization", "Content-Type", "x-amz-*"]
      expose_headers  = ["ETag", "x-amz-server-side-encryption", "x-amz-request-id"]
      max_age_seconds = 3600
    }
  ]
  
  # Multiple access points for different teams and tools
  access_point_configs = [
    {
      name   = "data-scientists"
      vpc_id = var.data_science_vpc_id
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = {
              AWS = var.data_scientist_role_arns
            }
            Action = [
              "s3:GetObject",
              "s3:ListBucket",
              "s3:GetObjectVersion",
              "s3:GetBucketLocation"
            ]
            Resource = ["*"]
          },
          {
            Effect = "Allow"
            Principal = {
              AWS = var.data_scientist_role_arns
            }
            Action = ["s3:PutObject"]
            Resource = ["*"]
            Condition = {
              StringLike = {
                "s3:x-amz-storage-class" = ["INTELLIGENT_TIERING", "STANDARD_IA"]
              }
            }
          }
        ]
      })
    },
    {
      name   = "bi-tools"
      vpc_id = var.bi_tools_vpc_id
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect = "Allow"
          Principal = {
            AWS = var.bi_service_role_arns
          }
          Action = [
            "s3:GetObject",
            "s3:ListBucket",
            "s3:GetBucketLocation"
          ]
          Resource = ["*"]
          Condition = {
            StringLike = {
              "s3:prefix" = ["reports/*", "dashboards/*", "aggregated/*"]
            }
          }
        }]
      })
    },
    {
      name   = "etl-pipelines"
      vpc_id = var.etl_vpc_id
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = {
              AWS = var.etl_role_arns
            }
            Action = [
              "s3:GetObject",
              "s3:PutObject",
              "s3:DeleteObject",
              "s3:ListBucket"
            ]
            Resource = ["*"]
            Condition = {
              StringLike = {
                "s3:prefix" = ["staging/*", "processed/*", "raw/*"]
              }
            }
          }
        ]
      })
    },
    {
      name   = "ml-platform"
      vpc_id = var.ml_platform_vpc_id
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = {
              AWS = var.ml_platform_role_arns
            }
            Action = [
              "s3:GetObject",
              "s3:ListBucket",
              "s3:GetObjectVersion"
            ]
            Resource = ["*"]
            Condition = {
              StringLike = {
                "s3:prefix" = ["training-data/*", "models/*", "features/*"]
              }
            }
          },
          {
            Effect = "Allow"
            Principal = {
              AWS = var.ml_platform_role_arns
            }
            Action = ["s3:PutObject"]
            Resource = ["*"]
            Condition = {
              StringLike = {
                "s3:prefix" = ["models/*", "predictions/*"]
              }
            }
          }
        ]
      })
    }
  ]
  
  # Analytics-specific lifecycle rules
  lifecycle_rules = [
    {
      id                       = "raw-data-lifecycle"
      enabled                  = true
      prefix                   = "raw/"
      transition_days          = 30
      transition_storage_class = "INTELLIGENT_TIERING"
      expiration_days          = 365
    },
    {
      id                               = "processed-data-lifecycle"
      enabled                          = true
      prefix                           = "processed/"
      transition_days                  = 7
      transition_storage_class         = "STANDARD_IA"
      noncurrent_version_expiration_days = 90
    },
    {
      id                       = "archive-old-reports"
      enabled                  = true
      prefix                   = "reports/"
      transition_days          = 180
      transition_storage_class = "GLACIER"
      tags = {
        ArchiveStatus = "true"
      }
    }
  ]
  
  # S3 Analytics configuration
  analytics_configuration = {
    id            = "analytics-access-patterns"
    output_bucket = var.analytics_output_bucket
    output_prefix = "s3-analytics/${var.bucket_name}/"
  }
  
  # S3 Inventory for data governance
  inventory_configuration = {
    id                       = "weekly-data-inventory"
    output_bucket            = var.inventory_output_bucket
    output_prefix            = "inventory/${var.bucket_name}/"
    schedule_frequency       = "Weekly"
    included_object_versions = "All"
    output_format            = "Parquet"  # For analytics queries
    optional_fields = [
      "Size",
      "LastModifiedDate",
      "StorageClass",
      "ETag",
      "IsMultipartUploaded",
      "ReplicationStatus",
      "EncryptionStatus",
      "ObjectLockRetainUntilDate",
      "ObjectLockMode",
      "ObjectLockLegalHoldStatus",
      "IntelligentTieringAccessTier",
      "BucketKeyStatus"
    ]
  }
  
  # Event notifications for analytics workflows
  event_notification_configs = [
    {
      id            = "new-raw-data"
      events        = ["s3:ObjectCreated:*"]
      filter_prefix = "raw/"
    },
    {
      id            = "etl-completion"
      events        = ["s3:ObjectCreated:*"]
      filter_prefix = "processed/"
      filter_suffix = ".success"
    },
    {
      id            = "model-updates"
      events        = ["s3:ObjectCreated:Put", "s3:ObjectCreated:Post"]
      filter_prefix = "models/"
      filter_suffix = ".pkl"
    }
  ]
  
  tags = merge(
    var.common_tags,
    {
      Module        = "analytics-platform"
      DataType      = "PHI-Analytics"
      Platform      = "multi-tenant"
      CostAllocation = "per-team"
    }
  )

  providers = {
    aws         = aws
    aws.replica = aws.replica
  }
}

# Enhanced monitoring for analytics workloads
module "analytics_monitoring" {
  source = "../../modules/monitoring"
  
  bucket_name  = module.phi_analytics.bucket_id
  bucket_arn   = module.phi_analytics.bucket_arn
  environment  = var.environment
  
  enable_sns_notifications = true
  notification_email       = var.notification_email
  enable_cloudwatch_alarms = true
  
  tags = var.common_tags
}

# Security Hub with focus on data governance
module "security_hub" {
  source = "../../modules/security-hub"
  
  bucket_name  = module.phi_analytics.bucket_id
  bucket_arn   = module.phi_analytics.bucket_arn
  kms_key_arn  = module.phi_analytics.kms_key_arn
  environment  = var.environment
  
  enable_security_hub = true
  enable_config       = true
  enable_guardduty    = true
  enable_macie        = true  # Important for PHI discovery in analytics
  
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

variable "enable_requester_pays" {
  description = "Enable requester pays for cross-account analytics"
  type        = bool
  default     = false
}

variable "analytics_tool_domains" {
  description = "List of domains for analytics tools (for CORS)"
  type        = list(string)
  default     = []
}

variable "data_science_vpc_id" {
  description = "VPC ID for data science team access"
  type        = string
}

variable "bi_tools_vpc_id" {
  description = "VPC ID for BI tools access"
  type        = string
}

variable "etl_vpc_id" {
  description = "VPC ID for ETL pipelines"
  type        = string
}

variable "ml_platform_vpc_id" {
  description = "VPC ID for ML platform"
  type        = string
}

variable "data_scientist_role_arns" {
  description = "IAM role ARNs for data scientists"
  type        = list(string)
}

variable "bi_service_role_arns" {
  description = "IAM role ARNs for BI services"
  type        = list(string)
}

variable "etl_role_arns" {
  description = "IAM role ARNs for ETL pipelines"
  type        = list(string)
}

variable "ml_platform_role_arns" {
  description = "IAM role ARNs for ML platform"
  type        = list(string)
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
  description = "Email for security and operational notifications"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Outputs
output "bucket_id" {
  description = "The name of the analytics bucket"
  value       = module.phi_analytics.bucket_id
}

output "access_points" {
  description = "Access points for different teams and services"
  value       = module.phi_analytics.access_points
  sensitive   = true
}

output "data_paths" {
  description = "Standard data paths in the bucket"
  value = {
    raw_data    = "s3://${module.phi_analytics.bucket_id}/raw/"
    staging     = "s3://${module.phi_analytics.bucket_id}/staging/"
    processed   = "s3://${module.phi_analytics.bucket_id}/processed/"
    reports     = "s3://${module.phi_analytics.bucket_id}/reports/"
    models      = "s3://${module.phi_analytics.bucket_id}/models/"
    features    = "s3://${module.phi_analytics.bucket_id}/features/"
    predictions = "s3://${module.phi_analytics.bucket_id}/predictions/"
  }
}

output "analytics_configuration" {
  description = "Analytics configuration status"
  value = {
    s3_analytics_enabled = true
    inventory_enabled    = true
    inventory_format     = "Parquet"
    inventory_frequency  = "Weekly"
  }
}

output "team_access_matrix" {
  description = "Access matrix for different teams"
  value = {
    data_scientists = {
      access_point = "data-scientists"
      permissions  = ["read", "write-with-conditions"]
    }
    bi_tools = {
      access_point = "bi-tools"
      permissions  = ["read-only", "specific-prefixes"]
    }
    etl_pipelines = {
      access_point = "etl-pipelines"
      permissions  = ["read", "write", "delete", "specific-prefixes"]
    }
    ml_platform = {
      access_point = "ml-platform"
      permissions  = ["read", "write-models", "write-predictions"]
    }
  }
}