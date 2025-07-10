# Basic Example

This example shows how to use the Secure S3 Bucket module with minimal configuration.

## Usage

```bash
terraform init
terraform plan
terraform apply
```

## What This Creates

- A secure S3 bucket with:
  - KMS encryption (creates a new key)
  - All public access blocked
  - Versioning enabled
  - HTTPS-only access enforced
  - Access logging enabled
  - Lifecycle rules for cost optimization

## Customization

See the `main.tf` file for configuration options. Key settings:

- `trusted_principal_arns` - IAM principals that can access the bucket
- `enable_replication` - Enable cross-region replication
- `enable_object_lock` - Enable object lock for compliance
- `kms_key_arn` - Use your own KMS key instead of creating one