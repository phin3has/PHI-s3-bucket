# Backup and Archive Configuration for PHI Storage
# This example creates a cost-optimized backup and archive solution with compliance retention

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

module "phi_backup_archive" {
  source = "../../modules/s3-phi-bucket"

  bucket_name  = "${var.bucket_name}-backup-archive"
  environment  = var.environment
  
  # Enable object lock for compliance retention
  enable_object_lock = true
  object_lock_configuration = {
    mode  = "COMPLIANCE"
    days  = var.retention_days  # Default 7 years (2555 days)
  }
  
  # Enable replication for backup redundancy
  enable_replication = true
  replication_region = var.replication_region
  
  # Cost optimization - immediate transition to cold storage
  enable_intelligent_tiering = false  # Not needed for archive
  enable_lifecycle_rules     = true
  
  lifecycle_rules = [
    {
      id                       = "immediate-deep-archive"
      enabled                  = true
      prefix                   = "archive/"
      transition_days          = 0
      transition_storage_class = "DEEP_ARCHIVE"
    },
    {
      id                       = "backup-to-glacier"
      enabled                  = true
      prefix                   = "backup/"
      transition_days          = 1
      transition_storage_class = "GLACIER"
      noncurrent_version_expiration_days = 2555  # Keep all versions for 7 years
    },
    {
      id                       = "incremental-to-standard-ia"
      enabled                  = true
      prefix                   = "incremental/"
      transition_days          = 7
      transition_storage_class = "STANDARD_IA"
      expiration_days          = 90  # Keep incrementals for 90 days
    }
  ]
  
  # Access points for backup and restore operations
  access_point_configs = [
    {
      name   = "backup-writer"
      vpc_id = var.backup_vpc_id
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect = "Allow"
          Principal = {
            AWS = var.backup_service_role_arn
          }
          Action = [
            "s3:PutObject",
            "s3:PutObjectLegalHold",
            "s3:PutObjectRetention",
            "s3:GetBucketLocation",
            "s3:ListBucket"
          ]
          Resource = ["*"]
        }]
      })
    },
    {
      name   = "restore-reader"
      vpc_id = var.restore_vpc_id
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect = "Allow"
          Principal = {
            AWS = var.restore_service_role_arn
          }
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:ListBucket",
            "s3:ListBucketVersions",
            "s3:RestoreObject"
          ]
          Resource = ["*"]
        }]
      })
    }
  ]
  
  # Disable features not needed for backup/archive
  enable_access_logging      = true  # Keep for compliance
  transfer_acceleration      = false # Not needed for scheduled backups
  
  # Event notifications for backup job monitoring
  event_notification_configs = [
    {
      id            = "backup-completion"
      events        = ["s3:ObjectCreated:CompleteMultipartUpload", "s3:ObjectCreated:Put"]
      filter_prefix = "backup/"
      filter_suffix = ".complete"
    },
    {
      id            = "restore-request"
      events        = ["s3:ObjectRestore:Post"]
      filter_prefix = "archive/"
    }
  ]
  
  # Request payer for cross-account restore operations
  request_payer = var.enable_cross_account_restore ? "Requester" : "BucketOwner"
  
  tags = merge(
    var.common_tags,
    {
      Module           = "backup-archive"
      DataType         = "PHI-Backup"
      RetentionYears   = "7"
      ComplianceScope  = "HIPAA-Archive"
    }
  )

  providers = {
    aws         = aws
    aws.replica = aws.replica
  }
}

# Monitoring focused on backup operations
module "backup_monitoring" {
  source = "../../modules/monitoring"
  
  bucket_name  = module.phi_backup_archive.bucket_id
  bucket_arn   = module.phi_backup_archive.bucket_arn
  environment  = var.environment
  
  enable_sns_notifications = true
  notification_email       = var.notification_email
  enable_cloudwatch_alarms = true
  
  tags = var.common_tags
}

# Security Hub for compliance monitoring
module "security_hub" {
  source = "../../modules/security-hub"
  
  bucket_name  = module.phi_backup_archive.bucket_id
  bucket_arn   = module.phi_backup_archive.bucket_arn
  kms_key_arn  = module.phi_backup_archive.kms_key_arn
  environment  = var.environment
  
  enable_security_hub = true
  enable_config       = true
  enable_guardduty    = false  # Less critical for cold storage
  enable_macie        = false  # Not needed for encrypted backups
  
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

variable "retention_days" {
  description = "Compliance retention period in days"
  type        = number
  default     = 2555  # 7 years
}

variable "backup_vpc_id" {
  description = "VPC ID for backup writer access point"
  type        = string
}

variable "restore_vpc_id" {
  description = "VPC ID for restore reader access point"
  type        = string
}

variable "backup_service_role_arn" {
  description = "IAM role ARN for backup service"
  type        = string
}

variable "restore_service_role_arn" {
  description = "IAM role ARN for restore service"
  type        = string
}

variable "notification_email" {
  description = "Email for backup operation notifications"
  type        = string
}

variable "enable_cross_account_restore" {
  description = "Enable cross-account restore with requester pays"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Outputs
output "bucket_id" {
  description = "The name of the backup archive bucket"
  value       = module.phi_backup_archive.bucket_id
}

output "object_lock_enabled" {
  description = "Object lock configuration status"
  value       = true
}

output "retention_configuration" {
  description = "Retention configuration details"
  value = {
    mode           = "COMPLIANCE"
    retention_days = var.retention_days
  }
}

output "access_points" {
  description = "Access points for backup and restore operations"
  value       = module.phi_backup_archive.access_points
}

output "storage_classes" {
  description = "Storage class configuration for cost optimization"
  value = {
    archive_tier     = "DEEP_ARCHIVE"
    backup_tier      = "GLACIER"
    incremental_tier = "STANDARD_IA"
  }
}

output "estimated_monthly_cost" {
  description = "Estimated monthly storage cost per TB (varies by storage class)"
  value = {
    deep_archive_per_tb = "$0.99"
    glacier_per_tb      = "$4.00"
    standard_ia_per_tb  = "$12.50"
  }
}