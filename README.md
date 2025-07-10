# Secure S3 Bucket Terraform Module

[![Terraform](https://img.shields.io/badge/terraform->=1.6.0-623CE4)](https://www.terraform.io)
[![AWS Provider](https://img.shields.io/badge/AWS->=5.0-FF9900)](https://registry.terraform.io/providers/hashicorp/aws/latest)
[![Security Scan](https://github.com/phin3has/PHI-s3-bucket/actions/workflows/security-scan.yml/badge.svg)](https://github.com/phin3has/PHI-s3-bucket/actions/workflows/security-scan.yml)
[![Terraform CI](https://github.com/phin3has/PHI-s3-bucket/actions/workflows/terraform-ci.yml/badge.svg)](https://github.com/phin3has/PHI-s3-bucket/actions/workflows/terraform-ci.yml)

A production-ready Terraform module that creates secure S3 buckets with enterprise-grade security controls suitable for sensitive data storage, including HIPAA-compliant configurations.

## Features

This module implements the following security requirements:

1. **Blocks all public access** - Prevents any public access to bucket and objects
2. **Enforces server-side encryption** - Uses customer-managed KMS keys (CMK) or creates one automatically
3. **Enforces encryption in transit** - Denies all non-HTTPS requests via bucket policy
4. **Enables object versioning** - Protects against accidental deletion or modification
5. **Secure by default** - Only allows access from trusted IAM principals
6. **S3 Object Lock support** - Optional immutability for compliance requirements
7. **Cross-region replication** - Automatic replication for high availability

## Usage

### Basic Example

```hcl
module "secure_bucket" {
  source = "github.com/phin3has/PHI-s3-bucket"
  
  bucket_name = "my-secure-data-bucket"
  environment = "prod"
  
  # Specify trusted IAM principals
  trusted_principal_arns = [
    "arn:aws:iam::123456789012:role/DataProcessingRole",
    "arn:aws:iam::123456789012:user/data-scientist"
  ]
  
  # Enable replication to us-west-2
  enable_replication = true
  replication_region = "us-west-2"
  
  tags = {
    Project    = "DataLake"
    CostCenter = "Engineering"
  }
  
  providers = {
    aws         = aws
    aws.replica = aws.replica
  }
}
```

### Using Your Own KMS Key

```hcl
module "secure_bucket" {
  source = "github.com/phin3has/PHI-s3-bucket"
  
  bucket_name = "my-secure-bucket"
  environment = "prod"
  
  # Use existing KMS key
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  
  trusted_principal_arns = [
    "arn:aws:iam::123456789012:role/ApplicationRole"
  ]
  
  providers = {
    aws         = aws
    aws.replica = aws.replica
  }
}
```

### With Object Lock for Compliance

```hcl
module "secure_bucket" {
  source = "github.com/phin3has/PHI-s3-bucket"
  
  bucket_name = "compliance-data-bucket"
  environment = "prod"
  
  # Enable Object Lock
  enable_object_lock = true
  object_lock_mode   = "GOVERNANCE"
  object_lock_days   = 30
  
  trusted_principal_arns = [
    "arn:aws:iam::123456789012:role/ComplianceRole"
  ]
  
  providers = {
    aws         = aws
    aws.replica = aws.replica
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | >= 5.0 |

## Provider Configuration

**Important**: This module requires two AWS providers to be configured:

```hcl
provider "aws" {
  region = "us-east-1"  # Primary region
}

provider "aws" {
  alias  = "replica"
  region = "us-west-2"  # Replication region (can be same as primary if not using replication)
}
```

Both providers must be passed to the module, even if replication is disabled:

```hcl
module "secure_bucket" {
  source = "./path/to/module"
  
  # ... other configuration ...
  
  providers = {
    aws         = aws
    aws.replica = aws.replica
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| bucket_name | The name of the S3 bucket | `string` | n/a | yes |
| environment | Environment name (dev, staging, prod) | `string` | n/a | yes |
| kms_key_arn | ARN of existing KMS key. If not provided, creates a new key | `string` | `null` | no |
| trusted_principal_arns | List of IAM principal ARNs that should have access | `list(string)` | `[]` | no |
| enable_replication | Enable cross-region replication | `bool` | `false` | no |
| replication_region | AWS region for the replica bucket | `string` | `"us-west-2"` | no |
| enable_object_lock | Enable S3 Object Lock for immutability | `bool` | `false` | no |
| object_lock_mode | Object Lock mode (GOVERNANCE or COMPLIANCE) | `string` | `"GOVERNANCE"` | no |
| object_lock_days | Number of days for Object Lock retention | `number` | `7` | no |
| enable_lifecycle_rules | Enable lifecycle rules for automatic archival | `bool` | `true` | no |
| tags | Additional tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| bucket_id | The name of the S3 bucket |
| bucket_arn | The ARN of the S3 bucket |
| kms_key_id | The ID of the KMS key used for encryption |
| kms_key_arn | The ARN of the KMS key used for encryption |
| replica_bucket_id | The name of the replica S3 bucket (if replication enabled) |
| replica_bucket_arn | The ARN of the replica S3 bucket (if replication enabled) |

## Security Features

### Encryption
- **At Rest**: All objects are encrypted using KMS (either customer-provided or module-created)
- **In Transit**: Bucket policy enforces HTTPS for all requests
- **Key Rotation**: Automatic key rotation enabled for module-created KMS keys

### Access Control
- **Public Access**: All public access is blocked at the bucket level
- **Principal-Based**: Only specified IAM principals can access the bucket
- **Bucket Policy**: Enforces encryption requirements and secure transport

### Data Protection
- **Versioning**: Enabled by default to protect against accidental deletion
- **Replication**: Optional cross-region replication for disaster recovery
- **Object Lock**: Optional immutability for compliance requirements

### Monitoring
- **Access Logs**: All bucket access is logged to a separate S3 bucket
- **Lifecycle**: Logs are automatically deleted after 90 days

## Compliance

This module is designed to meet common compliance requirements including:
- HIPAA (Protected Health Information)
- PCI-DSS (Payment Card Data)
- SOC 2
- GDPR

## Examples

See the [examples](./examples) directory for a complete example:
- [Basic Usage](./examples/basic)

## Development

### Testing
```bash
# Run tests
cd examples/basic
terraform init
terraform plan
```

### Security Scanning
This module includes automated security scanning via GitHub Actions:
- Checkov for Terraform security best practices
- Trivy for vulnerability scanning
- TruffleHog for secret detection

## License

Apache 2.0 - See [LICENSE](./LICENSE) for details.