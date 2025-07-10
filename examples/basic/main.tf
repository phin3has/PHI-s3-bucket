# Basic Example - Secure S3 Bucket

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

provider "aws" {
  alias  = "replica"
  region = var.replication_region
}

# Example: Basic secure S3 bucket
module "secure_s3_bucket" {
  source = "../../"
  
  bucket_name    = var.bucket_name
  environment    = var.environment
  aws_region     = var.aws_region
  project_name   = var.project_name
  
  # Security configuration
  trusted_principal_arns = var.trusted_principal_arns
  
  # Replication configuration  
  enable_replication = var.enable_replication
  replication_region = var.replication_region
  
  # Optional features
  enable_lifecycle_rules = true
  enable_object_lock     = false
  
  tags = var.common_tags
  
  providers = {
    aws         = aws
    aws.replica = aws.replica
  }
}

# Example: IAM role that can access the bucket
resource "aws_iam_role" "example_app" {
  name = "${var.bucket_name}-app-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.common_tags
}

# Example: Policy to allow the role to access the bucket
resource "aws_iam_role_policy" "bucket_access" {
  name = "${var.bucket_name}-access"
  role = aws_iam_role.example_app.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.secure_s3_bucket.bucket_arn,
          "${module.secure_s3_bucket.bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [module.secure_s3_bucket.kms_key_arn]
      }
    ]
  })
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

output "kms_key_arn" {
  description = "The ARN of the KMS key"
  value       = module.secure_s3_bucket.kms_key_arn
}

output "replica_bucket_id" {
  description = "The name of the replica bucket"
  value       = module.secure_s3_bucket.replica_bucket_id
}

output "example_role_arn" {
  description = "ARN of the example IAM role"
  value       = aws_iam_role.example_app.arn
}