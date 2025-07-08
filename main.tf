# Root module configuration for PHI S3 bucket
# This is an example of how to use the modules together

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
  
  # Backend configuration for state management
  # Uncomment and configure for production use
  # backend "s3" {
  #   bucket         = "terraform-state-bucket"
  #   key            = "phi-s3-bucket/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  #   kms_key_id     = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  # }
}

# Primary region provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = local.common_tags
  }
}

# Replication region provider
provider "aws" {
  alias  = "replica"
  region = var.replication_region
  
  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = merge(
    var.tags,
    {
      Terraform   = "true"
      Environment = var.environment
      Project     = var.project_name
    }
  )
}

# Main S3 bucket for PHI storage
module "phi_s3_bucket" {
  source = "./modules/s3-phi-bucket"
  
  bucket_name                = var.bucket_name
  environment                = var.environment
  
  # Security features
  enable_replication         = var.enable_replication
  replication_region         = var.replication_region
  enable_access_logging      = true
  enable_lifecycle_rules     = true
  enable_intelligent_tiering = true
  versioning_enabled         = true
  mfa_delete                 = var.enable_mfa_delete
  block_public_access        = true
  sse_algorithm              = "aws:kms"
  
  # Access control
  access_point_configs = var.access_point_configs
  
  # Lifecycle configuration
  lifecycle_rules = var.lifecycle_rules
  
  # Analytics and inventory
  analytics_configuration = var.analytics_configuration
  inventory_configuration = var.inventory_configuration
  
  # Event notifications
  event_notification_configs = var.event_notification_configs
  
  # Cost optimization
  transfer_acceleration      = var.enable_transfer_acceleration
  
  tags = local.common_tags
  
  providers = {
    aws         = aws
    aws.replica = aws.replica
  }
}

# Security Hub and compliance monitoring
module "security_compliance" {
  source = "./modules/security-hub"
  
  bucket_name  = module.phi_s3_bucket.bucket_id
  bucket_arn   = module.phi_s3_bucket.bucket_arn
  kms_key_arn  = module.phi_s3_bucket.kms_key_arn
  environment  = var.environment
  
  enable_security_hub = var.enable_security_hub
  enable_config       = var.enable_config
  enable_guardduty    = var.enable_guardduty
  enable_macie        = var.enable_macie
  
  tags = local.common_tags
}

# Monitoring and alerting
module "monitoring" {
  source = "./modules/monitoring"
  
  bucket_name  = module.phi_s3_bucket.bucket_id
  bucket_arn   = module.phi_s3_bucket.bucket_arn
  environment  = var.environment
  
  enable_sns_notifications = var.enable_sns_notifications
  notification_email       = var.notification_email
  enable_cloudwatch_alarms = var.enable_cloudwatch_alarms
  
  tags = local.common_tags
}

# Variables
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "phi-storage"
}

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
  description = "Name of the S3 bucket for PHI data"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "enable_replication" {
  description = "Enable cross-region replication"
  type        = bool
  default     = true
}

variable "enable_mfa_delete" {
  description = "Enable MFA delete for versioned objects"
  type        = bool
  default     = false
}

variable "enable_transfer_acceleration" {
  description = "Enable S3 Transfer Acceleration"
  type        = bool
  default     = false
}

variable "access_point_configs" {
  description = "S3 Access Point configurations"
  type = list(object({
    name   = string
    vpc_id = string
    policy = optional(string)
  }))
  default = []
}

variable "lifecycle_rules" {
  description = "Lifecycle rules for the bucket"
  type = list(object({
    id                     = string
    enabled                = bool
    prefix                 = optional(string)
    tags                   = optional(map(string))
    transition_days        = optional(number)
    transition_storage_class = optional(string)
    expiration_days        = optional(number)
    noncurrent_version_expiration_days = optional(number)
  }))
  default = [
    {
      id                     = "archive-old-data"
      enabled                = true
      transition_days        = 90
      transition_storage_class = "GLACIER"
      noncurrent_version_expiration_days = 730
    }
  ]
}

variable "analytics_configuration" {
  description = "S3 analytics configuration"
  type = object({
    id            = string
    prefix        = optional(string)
    output_bucket = string
    output_prefix = optional(string)
  })
  default = null
}

variable "inventory_configuration" {
  description = "S3 inventory configuration"
  type = object({
    id                       = string
    included_object_versions = optional(string, "All")
    output_bucket            = string
    output_prefix            = optional(string)
    output_format            = optional(string, "CSV")
    schedule_frequency       = optional(string, "Weekly")
    optional_fields          = optional(list(string))
  })
  default = null
}

variable "event_notification_configs" {
  description = "Event notification configurations"
  type = list(object({
    id            = string
    events        = list(string)
    filter_prefix = optional(string)
    filter_suffix = optional(string)
  }))
  default = []
}

variable "enable_security_hub" {
  description = "Enable AWS Security Hub"
  type        = bool
  default     = true
}

variable "enable_config" {
  description = "Enable AWS Config"
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Enable Amazon GuardDuty"
  type        = bool
  default     = true
}

variable "enable_macie" {
  description = "Enable Amazon Macie"
  type        = bool
  default     = true
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
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
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
  sensitive   = true
}

output "replica_bucket_id" {
  description = "The name of the replica bucket"
  value       = module.phi_s3_bucket.replica_bucket_id
}

output "access_points" {
  description = "S3 Access Points created"
  value       = module.phi_s3_bucket.access_points
}

output "compliance_status" {
  description = "Compliance and security service status"
  value = {
    bucket_compliance   = module.phi_s3_bucket.compliance_features
    security_services   = module.security_compliance.compliance_status
    monitoring_enabled  = module.monitoring.sns_topic_arn != null
  }
}

output "monitoring_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.monitoring.dashboard_url
}