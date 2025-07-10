variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
  default     = "secure-data-example"
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

variable "replication_region" {
  description = "AWS region for replication"
  type        = string
  default     = "us-west-2"
}

variable "enable_replication" {
  description = "Enable cross-region replication"
  type        = bool
  default     = true
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "secure-s3-example"
}

variable "trusted_principal_arns" {
  description = "List of IAM principal ARNs that should have access to the bucket"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Example     = "basic"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}