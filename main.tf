# main.tf - Simple PHI S3 Bucket Configuration for MVP
# Using PHI-s3-bucket module v1.1.1

# Configure the AWS Provider
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Backend configuration for remote state storage
  backend "s3" {
    bucket = "mvp-phi-storage-terraform-state"
    key    = "phi-s3-bucket/terraform.tfstate"
    region = "us-east-1"  # Update this to match your bucket's region
    
    # Optional but recommended for state locking
    # dynamodb_table = "terraform-state-lock"
    
    # Enable encryption
    encrypt = true
  }
}

# Configure AWS Provider with your region
provider "aws" {
  region = var.aws_region
}

# Variables for customization
variable "aws_region" {
  description = "AWS region for the S3 bucket"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for tagging and naming"
  type        = string
  default     = "mvp-healthcare"
}

variable "notification_email" {
  description = "Email for security notifications"
  type        = string
  default     = "security@example.com"
}

# Local values for consistent naming
locals {
  bucket_name = "${var.project_name}-${var.environment}-phi-data"
  
  common_tags = {
    Environment           = var.environment
    Project              = var.project_name
    ManagedBy            = "Terraform"
    Purpose              = "PHI-Data-Storage"
    DataClassification   = "PHI"
  }
}

# PHI S3 Bucket Module - Basic Configuration
module "phi_bucket" {
  source = "github.com/phin3has/PHI-s3-bucket//modules/s3-phi-bucket?ref=v1.1.2"
  
  # Required parameters
  bucket_name        = local.bucket_name
  environment        = var.environment
  notification_email = var.notification_email
  
  # Replication is now disabled by default (v1.1.2)
  # No need to configure replica provider for MVP
  
  # Tags
  tags = local.common_tags
}

# Outputs for reference
output "bucket_id" {
  description = "The ID of the PHI S3 bucket"
  value       = try(module.phi_bucket.bucket_id, "Not available")
}

output "bucket_arn" {
  description = "The ARN of the PHI S3 bucket"
  value       = try(module.phi_bucket.bucket_arn, "Not available")
}

output "bucket_name" {
  description = "The name of the PHI S3 bucket"
  value       = local.bucket_name
}

# Optional: README content
output "next_steps" {
  description = "Next steps for using the bucket"
  value = <<EOF
PHI S3 Bucket created successfully!

Next steps:
1. Update the notification_email to receive security alerts
2. Configure IAM roles/users for bucket access
3. Review the Security Hub findings for compliance
4. Set up monitoring dashboards in CloudWatch

Important: This bucket is configured for PHI data storage with:
- Encryption at rest (KMS)
- Versioning enabled
- Access logging
- HIPAA compliance controls
- Multi-region replication (if enabled in module)

For production use, consider:
- Enabling cross-region replication
- Setting up S3 Access Points for different teams
- Configuring lifecycle policies for cost optimization
EOF
}
