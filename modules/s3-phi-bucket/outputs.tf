output "bucket_id" {
  description = "The name of the bucket"
  value       = aws_s3_bucket.phi_bucket.id
}

output "bucket_arn" {
  description = "The ARN of the bucket"
  value       = aws_s3_bucket.phi_bucket.arn
}

output "bucket_domain_name" {
  description = "The bucket domain name"
  value       = aws_s3_bucket.phi_bucket.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "The bucket region-specific domain name"
  value       = aws_s3_bucket.phi_bucket.bucket_regional_domain_name
}

output "bucket_region" {
  description = "The AWS region this bucket resides in"
  value       = aws_s3_bucket.phi_bucket.region
}

output "kms_key_id" {
  description = "The KMS key ID used for bucket encryption"
  value       = var.sse_algorithm == "aws:kms" ? (var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.phi_bucket[0].id) : null
}

output "kms_key_arn" {
  description = "The KMS key ARN used for bucket encryption"
  value       = var.sse_algorithm == "aws:kms" ? (var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.phi_bucket[0].arn) : null
}

output "log_bucket_id" {
  description = "The name of the logging bucket"
  value       = var.enable_access_logging ? aws_s3_bucket.log_bucket[0].id : null
}

output "log_bucket_arn" {
  description = "The ARN of the logging bucket"
  value       = var.enable_access_logging ? aws_s3_bucket.log_bucket[0].arn : null
}

output "replica_bucket_id" {
  description = "The name of the replica bucket"
  value       = var.enable_replication ? aws_s3_bucket.replica[0].id : null
}

output "replica_bucket_arn" {
  description = "The ARN of the replica bucket"
  value       = var.enable_replication ? aws_s3_bucket.replica[0].arn : null
}

output "replica_bucket_region" {
  description = "The region of the replica bucket"
  value       = var.enable_replication ? var.replication_region : null
}

output "replication_role_arn" {
  description = "The ARN of the replication role"
  value       = var.enable_replication ? aws_iam_role.replication[0].arn : null
}

output "access_points" {
  description = "Map of access point names to their attributes"
  value = {
    for name, ap in aws_s3_access_point.phi_bucket : name => {
      arn                  = ap.arn
      domain_name         = ap.domain_name
      network_origin      = ap.network_origin
      vpc_id              = ap.vpc_configuration[0].vpc_id
    }
  }
}

output "bucket_policy_json" {
  description = "JSON policy to apply to the bucket (useful for debugging)"
  value       = data.aws_iam_policy_document.bucket_policy.json
}

output "compliance_features" {
  description = "Enabled compliance features"
  value = {
    versioning_enabled     = var.versioning_enabled
    mfa_delete_enabled     = var.mfa_delete
    encryption_enabled     = true
    encryption_algorithm   = var.sse_algorithm
    kms_key_rotation       = var.sse_algorithm == "aws:kms" ? true : false
    access_logging_enabled = var.enable_access_logging
    replication_enabled    = var.enable_replication
    object_lock_enabled    = var.enable_object_lock
    public_access_blocked  = var.block_public_access
    lifecycle_rules_count  = var.enable_lifecycle_rules ? length(var.lifecycle_rules) : 0
    access_points_count    = length(var.access_point_configs)
  }
}