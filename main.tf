# Secure S3 Bucket Terraform Module
# This module creates a secure S3 bucket with HIPAA-compliant settings

terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Primary AWS provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Module      = "secure-s3-bucket"
      ManagedBy   = "Terraform"
      Environment = var.environment
      Project     = var.project_name
    }
  }
}

# Provider for replication region
provider "aws" {
  alias  = "replica"
  region = var.replication_region
  
  default_tags {
    tags = {
      Module      = "secure-s3-bucket"
      ManagedBy   = "Terraform"
      Environment = var.environment
      Project     = var.project_name
      Type        = "Replica"
    }
  }
}

# Main S3 bucket module
module "secure_s3_bucket" {
  source = "./modules/s3-phi-bucket"
  
  bucket_name                = var.bucket_name
  environment                = var.environment
  
  # KMS encryption
  kms_key_arn                = var.kms_key_arn
  
  # Trusted principals for bucket access
  trusted_principal_arns     = var.trusted_principal_arns
  
  # Replication settings
  enable_replication         = var.enable_replication
  replication_region         = var.replication_region
  
  # Object Lock settings
  enable_object_lock         = var.enable_object_lock
  object_lock_mode           = var.object_lock_mode
  object_lock_days           = var.object_lock_days
  
  # Lifecycle settings
  enable_lifecycle_rules     = var.enable_lifecycle_rules
  
  # Tags
  tags = var.tags
  
  providers = {
    aws         = aws
    aws.replica = aws.replica
  }
}

# Outputs
output "bucket_id" {
  description = "The name of the S3 bucket"
  value       = module.secure_s3_bucket.bucket_id
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = module.secure_s3_bucket.bucket_arn
}

output "kms_key_id" {
  description = "The ID of the KMS key used for encryption"
  value       = module.secure_s3_bucket.kms_key_id
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used for encryption"
  value       = module.secure_s3_bucket.kms_key_arn
}

output "replica_bucket_id" {
  description = "The name of the replica S3 bucket (if replication is enabled)"
  value       = try(module.secure_s3_bucket.replica_bucket_id, null)
}

output "replica_bucket_arn" {
  description = "The ARN of the replica S3 bucket (if replication is enabled)"
  value       = try(module.secure_s3_bucket.replica_bucket_arn, null)
}