# Basic Secure S3 Bucket Example

This example demonstrates how to create a secure S3 bucket with:
- KMS encryption
- Cross-region replication
- Access logging
- Versioning
- Lifecycle rules

## Usage

```bash
terraform init
terraform plan
terraform apply
```

## Requirements

- AWS credentials configured
- Terraform >= 1.6.0

## What This Creates

1. **Primary S3 Bucket** in us-east-1 with:
   - KMS encryption (creates new KMS key)
   - Versioning enabled
   - All public access blocked
   - Bucket policy enforcing HTTPS
   - Access logging to separate bucket

2. **Replica S3 Bucket** in us-west-2 with:
   - Same security settings as primary
   - Automatic replication from primary

3. **Example IAM Role** showing how to grant access to the bucket

## Customization

Edit `variables.tf` or create a `terraform.tfvars` file:

```hcl
bucket_name = "my-company-secure-data"
environment = "prod"

trusted_principal_arns = [
  "arn:aws:iam::123456789012:role/DataProcessingRole"
]
```

## Outputs

- `bucket_id` - Name of the primary bucket
- `bucket_arn` - ARN of the primary bucket
- `kms_key_arn` - ARN of the KMS key
- `replica_bucket_id` - Name of the replica bucket
- `example_role_arn` - ARN of the example IAM role