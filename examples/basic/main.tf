# Example usage of the Secure S3 Bucket module

terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Primary provider
provider "aws" {
  region = "us-east-1"
}

# Replica provider (required even if replication is disabled)
provider "aws" {
  alias  = "replica"
  region = "us-west-2"
}

# Create a secure S3 bucket
module "secure_bucket" {
  source = "../../"
  
  bucket_name = "my-secure-data-bucket"
  environment = "prod"
  
  # Security configuration
  trusted_principal_arns = [
    aws_iam_role.app_role.arn
  ]
  
  # Optional: Use your own KMS key
  # kms_key_arn = aws_kms_key.my_key.arn
  
  # Replication settings
  enable_replication = false
  
  # Object Lock settings
  enable_object_lock = false
  
  # Lifecycle settings
  enable_lifecycle_rules = true
  
  tags = {
    Project    = "Example"
    CostCenter = "Engineering"
  }
  
  providers = {
    aws         = aws
    aws.replica = aws.replica
  }
}

# Example IAM role that can access the bucket
resource "aws_iam_role" "app_role" {
  name = "secure-bucket-app-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Outputs
output "bucket_name" {
  value = module.secure_bucket.bucket_id
}

output "bucket_arn" {
  value = module.secure_bucket.bucket_arn
}

output "kms_key_arn" {
  value = module.secure_bucket.kms_key_arn
}