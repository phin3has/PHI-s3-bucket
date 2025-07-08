variable "bucket_name" {
  description = "Name of the S3 bucket for PHI data"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must start and end with lowercase alphanumeric characters, and can contain hyphens."
  }
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_replication" {
  description = "Enable cross-region replication for disaster recovery"
  type        = bool
  default     = true
}

variable "replication_region" {
  description = "AWS region for replication bucket"
  type        = string
  default     = "us-west-2"
}

variable "enable_access_logging" {
  description = "Enable S3 access logging for audit trails"
  type        = bool
  default     = true
}

variable "enable_lifecycle_rules" {
  description = "Enable lifecycle rules for cost optimization"
  type        = bool
  default     = true
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

variable "enable_object_lock" {
  description = "Enable object lock for compliance requirements"
  type        = bool
  default     = false
}

variable "object_lock_configuration" {
  description = "Object lock configuration"
  type = object({
    mode = string
    days = optional(number)
    years = optional(number)
  })
  default = null
}

variable "enable_intelligent_tiering" {
  description = "Enable S3 Intelligent-Tiering for automatic cost optimization"
  type        = bool
  default     = true
}

variable "block_public_access" {
  description = "Block all public access to the bucket"
  type        = bool
  default     = true
}

variable "versioning_enabled" {
  description = "Enable versioning for data protection"
  type        = bool
  default     = true
}

variable "mfa_delete" {
  description = "Enable MFA delete for versioned objects"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption. If not provided, a new key will be created."
  type        = string
  default     = null
}

variable "sse_algorithm" {
  description = "Server-side encryption algorithm (aws:kms or AES256)"
  type        = string
  default     = "aws:kms"
  validation {
    condition     = contains(["aws:kms", "AES256"], var.sse_algorithm)
    error_message = "SSE algorithm must be either aws:kms or AES256."
  }
}

variable "access_point_configs" {
  description = "Configurations for S3 Access Points"
  type = list(object({
    name                  = string
    vpc_id               = optional(string)
    public_access_block  = optional(bool, true)
    policy               = optional(string)
  }))
  default = []
}

variable "event_notification_configs" {
  description = "Event notification configurations for EventBridge"
  type = list(object({
    id            = string
    events        = list(string)
    filter_prefix = optional(string)
    filter_suffix = optional(string)
  }))
  default = []
}

variable "cors_rules" {
  description = "CORS rules for the bucket"
  type = list(object({
    allowed_headers = optional(list(string))
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string))
    max_age_seconds = optional(number)
  }))
  default = []
}

variable "request_payer" {
  description = "Who pays for requests and data transfer (BucketOwner or Requester)"
  type        = string
  default     = "BucketOwner"
  validation {
    condition     = contains(["BucketOwner", "Requester"], var.request_payer)
    error_message = "Request payer must be either BucketOwner or Requester."
  }
}

variable "transfer_acceleration" {
  description = "Enable transfer acceleration for faster uploads"
  type        = bool
  default     = false
}

variable "analytics_configuration" {
  description = "S3 analytics configuration for access pattern analysis"
  type = object({
    id                     = string
    prefix                 = optional(string)
    output_bucket          = string
    output_prefix          = optional(string)
  })
  default = null
}

variable "inventory_configuration" {
  description = "S3 inventory configuration for compliance reporting"
  type = object({
    id                     = string
    included_object_versions = optional(string, "All")
    output_bucket          = string
    output_prefix          = optional(string)
    output_format          = optional(string, "CSV")
    schedule_frequency     = optional(string, "Weekly")
    optional_fields        = optional(list(string), ["Size", "LastModifiedDate", "ETag", "StorageClass", "IsMultipartUploaded", "ReplicationStatus", "EncryptionStatus"])
  })
  default = null
}