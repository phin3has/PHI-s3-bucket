variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
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
  description = "Enable cross-region replication (requires aws.replica provider)"
  type        = bool
  default     = false
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
}

variable "object_lock_days" {
  description = "Number of days for Object Lock retention"
  type        = number
  default     = 7
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