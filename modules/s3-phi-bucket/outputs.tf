output "bucket_id" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.main.id
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.main.arn
}

output "bucket_domain_name" {
  description = "The bucket domain name"
  value       = aws_s3_bucket.main.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "The bucket region-specific domain name"
  value       = aws_s3_bucket.main.bucket_regional_domain_name
}

output "kms_key_id" {
  description = "The ID of the KMS key used for encryption"
  value       = var.kms_key_arn != null ? var.kms_key_arn : try(aws_kms_key.bucket[0].id, null)
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used for encryption"
  value       = var.kms_key_arn != null ? var.kms_key_arn : try(aws_kms_key.bucket[0].arn, null)
}

output "log_bucket_id" {
  description = "The name of the S3 access logs bucket"
  value       = aws_s3_bucket.logs.id
}

output "log_bucket_arn" {
  description = "The ARN of the S3 access logs bucket"
  value       = aws_s3_bucket.logs.arn
}

output "replica_bucket_id" {
  description = "The name of the replica S3 bucket"
  value       = try(aws_s3_bucket.replica[0].id, null)
}

output "replica_bucket_arn" {
  description = "The ARN of the replica S3 bucket"
  value       = try(aws_s3_bucket.replica[0].arn, null)
}

output "replication_role_arn" {
  description = "The ARN of the replication role"
  value       = try(aws_iam_role.replication[0].arn, null)
}