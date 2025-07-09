# Basic PHI S3 Bucket Configuration
# This example creates a HIPAA-compliant S3 bucket with all security features enabled

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

module "phi_s3_bucket" {
  source = "../../modules/s3-phi-bucket"

  bucket_name  = var.bucket_name
  environment  = var.environment
  
  # Enable all security features
  enable_replication         = true
  replication_region         = var.replication_region
  enable_access_logging      = true
  enable_lifecycle_rules     = true
  enable_intelligent_tiering = true
  versioning_enabled         = true
  mfa_delete                 = false # Enable in production with MFA device
  
  # Default lifecycle rules for cost optimization
  lifecycle_rules = [
    {
      id                     = "archive-old-data"
      enabled                = true
      transition_days        = 90
      transition_storage_class = "GLACIER"
      noncurrent_version_expiration_days = 730
    },
    {
      id                     = "delete-incomplete-uploads"
      enabled                = true
      prefix                 = ""
      abort_incomplete_multipart_upload_days = 7
    }
  ]
  
  tags = merge(
    var.common_tags,
    {
      Module      = "basic-example"
      DataType    = "PHI"
      Compliance  = "HIPAA"
    }
  )

  providers = {
    aws         = aws
    aws.replica = aws.replica
  }
}

# Security Hub Integration
module "security_hub" {
  source = "../../modules/security-hub"
  
  bucket_name  = module.phi_s3_bucket.bucket_id
  bucket_arn   = module.phi_s3_bucket.bucket_arn
  kms_key_arn  = module.phi_s3_bucket.kms_key_arn
  environment  = var.environment
  
  enable_security_hub = true
  enable_config       = true
  enable_guardduty    = true
  enable_macie        = true
  
  tags = var.common_tags
}

# Monitoring Integration
module "monitoring" {
  source = "../../modules/monitoring"
  
  bucket_name  = module.phi_s3_bucket.bucket_id
  bucket_arn   = module.phi_s3_bucket.bucket_arn
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
  description = "Name of the S3 bucket"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "notification_email" {
  description = "Email for security notifications"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {
    Project    = "PHI-Storage"
    ManagedBy  = "Terraform"
  }
}

# Outputs
output "bucket_id" {
  description = "The name of the PHI bucket"
  value       = module.phi_s3_bucket.bucket_id
}

output "bucket_arn" {
  description = "The ARN of the PHI bucket"
  value       = module.phi_s3_bucket.bucket_arn
}

output "kms_key_id" {
  description = "The KMS key ID used for encryption"
  value       = module.phi_s3_bucket.kms_key_id
}

output "replica_bucket_id" {
  description = "The name of the replica bucket"
  value       = module.phi_s3_bucket.replica_bucket_id
}

output "security_dashboard_url" {
  description = "URL to the CloudWatch security dashboard"
  value       = module.monitoring.dashboard_url
}

output "compliance_status" {
  description = "Compliance services status"
  value       = module.security_hub.compliance_status
}