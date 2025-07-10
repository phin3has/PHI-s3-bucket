# Example: Using the module without replication
# This is the simplest way to use the module

terraform {
  required_version = ">= 1.6.0"
  
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

# Use the module without replication
module "secure_bucket" {
  source = "github.com/phin3has/PHI-s3-bucket?ref=v1.0.0"
  
  bucket_name    = var.bucket_name
  environment    = var.environment
  
  # Disable replication - no replica provider needed
  enable_replication = false
  
  # Security configuration
  trusted_principal_arns = var.trusted_principal_arns
  
  tags = var.tags
}

# Variables
variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
  default     = "my-secure-bucket"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "trusted_principal_arns" {
  description = "List of IAM principal ARNs that should have access"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default = {
    Example = "without-replication"
  }
}

# Outputs
output "bucket_id" {
  value = module.secure_bucket.bucket_id
}

output "bucket_arn" {
  value = module.secure_bucket.bucket_arn
}

output "kms_key_arn" {
  value = module.secure_bucket.kms_key_arn
}