variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be valid S3 bucket naming format"
  }
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "aws_region" {
  description = "AWS region for the primary bucket"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "secure-s3"
}

variable "kms_key_arn" {
  description = "ARN of existing KMS key for encryption. If not provided, a new key will be created"
  type        = string
  default     = null
}

variable "trusted_principal_arns" {
  description = "List of IAM principal ARNs that should have access to the bucket"
  type        = list(string)
  default     = []
}

variable "enable_replication" {
  description = "Enable cross-region replication"
  type        = bool
  default     = true
}

variable "replication_region" {
  description = "AWS region for the replica bucket"
  type        = string
  default     = "us-west-2"
}

variable "enable_object_lock" {
  description = "Enable S3 Object Lock for immutability"
  type        = bool
  default     = false
}

variable "object_lock_mode" {
  description = "Object Lock mode (GOVERNANCE or COMPLIANCE)"
  type        = string
  default     = "GOVERNANCE"
  
  validation {
    condition     = contains(["GOVERNANCE", "COMPLIANCE"], var.object_lock_mode)
    error_message = "Object Lock mode must be GOVERNANCE or COMPLIANCE"
  }
}

variable "object_lock_days" {
  description = "Number of days for Object Lock retention"
  type        = number
  default     = 7
  
  validation {
    condition     = var.object_lock_days >= 1 && var.object_lock_days <= 36500
    error_message = "Object Lock days must be between 1 and 36500"
  }
}

variable "enable_lifecycle_rules" {
  description = "Enable lifecycle rules for automatic archival"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}