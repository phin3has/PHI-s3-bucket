# HIPAA-Compliant S3 Bucket Terraform Module

A production-ready Terraform module for deploying HIPAA-compliant S3 buckets with enterprise-grade security features for storing Protected Health Information (PHI).

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Requirements](#requirements)
- [Usage](#usage)
- [Module Structure](#module-structure)
- [Compliance Mapping](#compliance-mapping)
- [Architecture Decision Records](#architecture-decision-records)
- [Security Features](#security-features)
- [Cost Optimization](#cost-optimization)
- [Monitoring and Alerting](#monitoring-and-alerting)
- [Examples](#examples)
- [CI/CD Integration](#cicd-integration)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## Overview

This Terraform module creates a secure, HIPAA-compliant S3 bucket infrastructure designed for storing Protected Health Information (PHI). It implements defense-in-depth security controls, automated compliance monitoring, and cost optimization features while maintaining high availability through multi-region replication.

### Key Differentiators

- **Multi-region replication** for disaster recovery and high availability
- **Automated KMS key rotation** for encryption key management
- **S3 Access Points** for granular access control
- **Real-time security monitoring** with EventBridge and CloudWatch
- **Integrated compliance checking** with AWS Security Hub, Config, GuardDuty, and Macie
- **Cost optimization** through intelligent tiering and lifecycle policies
- **Production-ready** with comprehensive testing and documentation

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         HIPAA-Compliant S3 Architecture              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐       │
│  │   Primary    │────▶│ Replication  │     │   S3 Access  │       │
│  │   S3 Bucket  │     │   S3 Bucket  │     │    Points    │       │
│  │  (us-east-1) │     │ (us-west-2)  │     └──────────────┘       │
│  └──────────────┘     └──────────────┘                             │
│         │                                                           │
│         ▼                                                           │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐       │
│  │  KMS Keys    │     │ EventBridge  │     │  CloudWatch  │       │
│  │(Auto-Rotate) │     │    Rules     │────▶│   Alarms     │       │
│  └──────────────┘     └──────────────┘     └──────────────┘       │
│                                                     │               │
│  ┌──────────────┐     ┌──────────────┐            ▼               │
│  │   AWS Config │     │  CloudTrail  │     ┌──────────────┐       │
│  │    Rules     │     │   Logging    │     │  SNS Topic   │       │
│  └──────────────┘     └──────────────┘     └──────────────┘       │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────┐      │
│  │                Security & Compliance Layer                 │      │
│  ├──────────────┬──────────────┬──────────────┬─────────────┤      │
│  │ Security Hub │    Config     │  GuardDuty   │   Macie     │      │
│  └──────────────┴──────────────┴──────────────┴─────────────┘      │
└─────────────────────────────────────────────────────────────────────┘
```

## Features

### Security Features
- **Encryption at Rest**: Customer-managed KMS keys with automatic rotation
- **Encryption in Transit**: Enforced SSL/TLS for all connections
- **Access Control**: S3 Access Points for granular permissions
- **Versioning**: Object versioning with MFA delete protection
- **Access Logging**: Comprehensive audit trails
- **Public Access Block**: All public access blocked by default
- **Bucket Policies**: Restrictive policies enforcing security requirements

### Compliance Features
- **HIPAA Controls**: Implements required HIPAA security controls
- **AWS Security Hub**: Automated compliance checking against HIPAA standards
- **AWS Config Rules**: Continuous compliance monitoring
- **Amazon Macie**: Automated PHI discovery and classification
- **GuardDuty**: Threat detection for S3 access patterns

### High Availability
- **Multi-Region Replication**: Automated cross-region replication
- **Disaster Recovery**: RPO < 15 minutes with replication metrics
- **Backup Strategy**: Versioning and replication for data protection

### Cost Optimization
- **Intelligent Tiering**: Automatic storage class optimization
- **Lifecycle Policies**: Automated data archival and expiration
- **Storage Analytics**: Usage pattern analysis for optimization

### Monitoring & Alerting
- **EventBridge Rules**: Real-time security event detection
- **CloudWatch Dashboards**: Comprehensive monitoring dashboards
- **SNS Notifications**: Email alerts for security events
- **CloudTrail Integration**: Full API audit logging

## Requirements

- Terraform >= 1.5.0
- AWS Provider >= 5.0
- AWS Account with appropriate permissions
- AWS CLI configured for authentication

## Usage

### Basic Usage

```hcl
module "phi_s3_bucket" {
  source = "./modules/s3-phi-bucket"

  bucket_name  = "my-healthcare-phi-data"
  environment  = "prod"
  
  # Enable all security features
  enable_replication      = true
  replication_region      = "us-west-2"
  enable_access_logging   = true
  enable_lifecycle_rules  = true
  enable_intelligent_tiering = true
  
  # Notification email for security alerts
  notification_email = "security-team@healthcare.com"
  
  tags = {
    Project     = "Healthcare Platform"
    CostCenter  = "IT-Security"
    DataType    = "PHI"
  }
}

# Security Hub Integration
module "security_hub" {
  source = "./modules/security-hub"
  
  bucket_name  = module.phi_s3_bucket.bucket_id
  bucket_arn   = module.phi_s3_bucket.bucket_arn
  kms_key_arn  = module.phi_s3_bucket.kms_key_arn
  environment  = "prod"
  
  enable_security_hub = true
  enable_config      = true
  enable_guardduty   = true
  enable_macie       = true
}

# Monitoring Integration
module "monitoring" {
  source = "./modules/monitoring"
  
  bucket_name  = module.phi_s3_bucket.bucket_id
  bucket_arn   = module.phi_s3_bucket.bucket_arn
  environment  = "prod"
  
  enable_sns_notifications = true
  notification_email      = "security-team@healthcare.com"
  enable_cloudwatch_alarms = true
}
```

### Advanced Configuration with S3 Access Points

```hcl
module "phi_s3_bucket" {
  source = "./modules/s3-phi-bucket"

  bucket_name  = "my-healthcare-phi-data"
  environment  = "prod"
  
  # S3 Access Points for different use cases
  access_point_configs = [
    {
      name   = "analytics-team"
      vpc_id = "vpc-12345678"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect = "Allow"
          Principal = {
            AWS = "arn:aws:iam::123456789012:role/AnalyticsRole"
          }
          Action   = ["s3:GetObject", "s3:ListBucket"]
          Resource = ["*"]
        }]
      })
    },
    {
      name   = "etl-pipeline"
      vpc_id = "vpc-87654321"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect = "Allow"
          Principal = {
            AWS = "arn:aws:iam::123456789012:role/ETLRole"
          }
          Action   = ["s3:GetObject", "s3:PutObject"]
          Resource = ["*"]
        }]
      })
    }
  ]
}
```

## Module Structure

```
.
├── modules/
│   ├── s3-phi-bucket/       # Main S3 bucket module
│   │   ├── main.tf          # Primary bucket resources
│   │   ├── replication.tf   # Cross-region replication
│   │   ├── bucket-policy.tf # Security policies
│   │   ├── variables.tf     # Input variables
│   │   ├── outputs.tf       # Output values
│   │   └── versions.tf      # Provider requirements
│   │
│   ├── monitoring/          # EventBridge and CloudWatch monitoring
│   │   └── main.tf         # Monitoring resources
│   │
│   └── security-hub/        # Security Hub and compliance
│       └── main.tf         # Security Hub, Config, GuardDuty, Macie
│
├── examples/               # Example configurations
│   ├── basic/             # Basic PHI bucket
│   ├── data-lake/         # Data lake configuration
│   ├── backup-archive/    # Backup and archive use case
│   └── analytics/         # Analytics platform
│
├── tests/                 # Terraform test configurations
├── .github/workflows/     # GitHub Actions CI/CD
├── README.md             # This file
├── SECURITY.md           # Security documentation
└── CHANGELOG.md          # Version history
```

## Compliance Mapping

### HIPAA Security Rule Compliance

| HIPAA Control | Implementation | Module Component |
|---------------|----------------|------------------|
| §164.308(a)(1) | Security Management Process | AWS Security Hub, Config Rules |
| §164.308(a)(3) | Workforce Training | Documentation, Access Points |
| §164.308(a)(4) | Access Management | IAM Policies, S3 Access Points |
| §164.308(a)(5) | Security Awareness | CloudWatch Alarms, SNS Alerts |
| §164.308(a)(6) | Security Incident Procedures | EventBridge, CloudTrail |
| §164.308(a)(7) | Contingency Plan | Multi-region Replication |
| §164.310(d)(1) | Device and Media Controls | Lifecycle Policies, Versioning |
| §164.312(a)(1) | Access Control | IAM, Bucket Policies, MFA Delete |
| §164.312(a)(2) | Audit Controls | CloudTrail, Access Logging |
| §164.312(b) | Audit Logs | CloudTrail, S3 Access Logs |
| §164.312(c) | Integrity | Versioning, Object Lock |
| §164.312(e) | Transmission Security | SSL/TLS Enforcement |

### AWS Security Standards Compliance

- **AWS Foundational Security Best Practices**: ✓ Enabled
- **HIPAA Security Rule 2003**: ✓ Enabled
- **CIS AWS Foundations Benchmark v1.2.0**: ✓ Enabled

## Architecture Decision Records

### ADR-001: Multi-Region Replication Strategy

**Status**: Accepted

**Context**: PHI data requires high availability and disaster recovery capabilities to meet HIPAA requirements for data availability and contingency planning.

**Decision**: Implement automated cross-region replication to a secondary region with:
- Same-region replication for operational recovery
- Cross-region replication for disaster recovery
- 15-minute RPO target
- Encrypted replication using separate KMS keys

**Consequences**: 
- Increased storage costs (mitigated by lifecycle policies)
- Enhanced data durability and availability
- Compliance with HIPAA contingency planning requirements

### ADR-002: Encryption Strategy

**Status**: Accepted

**Context**: HIPAA requires encryption of PHI at rest and in transit.

**Decision**: Use customer-managed KMS keys with:
- Automatic key rotation enabled
- Separate keys for primary and replica regions
- Bucket key enabled for performance
- SSL/TLS enforced via bucket policy

**Consequences**:
- Full control over encryption keys
- Audit trail of key usage
- Slight performance overhead (mitigated by bucket keys)

### ADR-003: Access Control Model

**Status**: Accepted

**Context**: Different teams and applications need varying levels of access to PHI data.

**Decision**: Implement S3 Access Points for granular access control:
- VPC-restricted access points for internal services
- Separate access points per use case
- Policy-based access control
- No direct bucket access

**Consequences**:
- Simplified permission management
- Better security isolation
- Easier audit and compliance

### ADR-004: Cost Optimization Approach

**Status**: Accepted

**Context**: Healthcare data grows continuously, requiring cost management strategies.

**Decision**: Implement automated cost optimization:
- Intelligent-Tiering for automatic storage class transitions
- Lifecycle policies for predictable access patterns
- Archive to Glacier after 90 days
- Delete non-current versions after 2 years

**Consequences**:
- Reduced storage costs (up to 70% for archived data)
- Automated management reduces operational overhead
- Maintains compliance while optimizing costs

### ADR-005: Security Monitoring Strategy

**Status**: Accepted

**Context**: HIPAA requires monitoring and alerting for security incidents.

**Decision**: Implement comprehensive monitoring stack:
- EventBridge for real-time event processing
- Security Hub for centralized findings
- GuardDuty for threat detection
- Macie for data classification

**Consequences**:
- Proactive security incident detection
- Automated compliance checking
- Centralized security visibility

## Security Features

### Defense in Depth

1. **Network Layer**
   - VPC-restricted S3 Access Points
   - Private endpoint access only

2. **Identity Layer**
   - IAM role-based access
   - MFA enforcement for sensitive operations
   - Principle of least privilege

3. **Application Layer**
   - Bucket policies enforcing encryption
   - SSL/TLS requirement
   - Request authentication

4. **Data Layer**
   - Encryption at rest with KMS
   - Encryption in transit
   - Versioning for data integrity

5. **Monitoring Layer**
   - Real-time security alerts
   - Compliance monitoring
   - Threat detection

### Security Controls

- **Preventive Controls**
  - Public access block
  - Encryption enforcement
  - SSL/TLS requirement
  - MFA delete protection

- **Detective Controls**
  - CloudTrail logging
  - S3 access logging
  - EventBridge monitoring
  - Security Hub findings

- **Responsive Controls**
  - Automated alerting
  - Incident response procedures
  - Security team notifications

## Cost Optimization

### Storage Class Optimization

The module implements intelligent storage management:

1. **Standard Storage** (0-90 days)
   - For frequently accessed PHI data
   - Immediate access

2. **Standard-IA** (Replication target)
   - For disaster recovery copies
   - Reduced storage cost

3. **Intelligent-Tiering** (Enabled by default)
   - Automatic optimization based on access patterns
   - No retrieval fees

4. **Glacier** (90+ days)
   - For long-term compliance archives
   - 90% cost reduction

### Cost Monitoring

- S3 Storage Analytics for usage patterns
- Cost allocation tags for chargeback
- CloudWatch metrics for storage optimization

## Monitoring and Alerting

### Real-time Security Events

The module monitors and alerts on:

- Unauthorized access attempts
- Object deletion attempts
- Bucket policy changes
- Encryption configuration changes
- Public access configuration changes
- Large file uploads (potential data exfiltration)

### CloudWatch Dashboard

Comprehensive dashboard showing:
- Bucket size and object count
- Request metrics (GET, PUT, DELETE)
- Error rates (4xx, 5xx)
- Replication metrics
- Access patterns

### Alert Notifications

- SNS email notifications for critical events
- CloudWatch alarms for threshold breaches
- Security Hub findings for compliance issues

## Examples

### Data Lake Configuration

```hcl
module "phi_data_lake" {
  source = "./modules/s3-phi-bucket"

  bucket_name  = "healthcare-data-lake"
  environment  = "prod"
  
  # Data lake specific settings
  enable_intelligent_tiering = true
  transfer_acceleration     = true
  
  # Analytics configuration
  analytics_configuration = {
    id            = "access-patterns"
    output_bucket = "analytics-results"
    output_prefix = "s3-analytics/"
  }
  
  # Inventory for data catalog
  inventory_configuration = {
    id                     = "weekly-inventory"
    output_bucket          = "data-catalog"
    output_prefix          = "inventory/"
    schedule_frequency     = "Weekly"
    included_object_versions = "Current"
  }
}
```

### Backup Archive Configuration

```hcl
module "phi_backup_archive" {
  source = "./modules/s3-phi-bucket"

  bucket_name  = "healthcare-backup-archive"
  environment  = "prod"
  
  # Backup specific settings
  enable_object_lock = true
  object_lock_configuration = {
    mode = "COMPLIANCE"
    days = 2555  # 7 years retention
  }
  
  # Aggressive lifecycle for cost optimization
  lifecycle_rules = [
    {
      id                     = "immediate-archive"
      enabled                = true
      transition_days        = 0
      transition_storage_class = "GLACIER"
    }
  ]
}
```

### Analytics Platform Configuration

```hcl
module "phi_analytics" {
  source = "./modules/s3-phi-bucket"

  bucket_name  = "healthcare-analytics"
  environment  = "prod"
  
  # Analytics workload settings
  request_payer = "Requester"  # Requester pays model
  
  # CORS for web-based analytics tools
  cors_rules = [
    {
      allowed_methods = ["GET", "HEAD"]
      allowed_origins = ["https://analytics.healthcare.com"]
      allowed_headers = ["*"]
      max_age_seconds = 3000
    }
  ]
  
  # Multiple access points for different teams
  access_point_configs = [
    {
      name   = "data-scientists"
      vpc_id = var.analytics_vpc_id
    },
    {
      name   = "bi-tools"
      vpc_id = var.bi_vpc_id
    }
  ]
}
```

## CI/CD Integration

### GitHub Actions Workflow

The module includes GitHub Actions workflows for:

1. **Terraform Validation**
   - Syntax checking
   - Format verification
   - Security scanning with tfsec

2. **Automated Testing**
   - Terraform test framework
   - Compliance validation
   - Cost estimation

3. **Documentation**
   - Auto-generated docs
   - Compliance matrix updates

### Pre-commit Hooks

```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.77.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tfsec
      - id: terraform_docs
  
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: end-of-file-fixer
      - id: trailing-whitespace
      - id: detect-private-key
      - id: detect-aws-credentials
```

## Troubleshooting

### Common Issues

1. **Replication Not Working**
   - Verify both regions are enabled in your AWS account
   - Check IAM role has cross-region permissions
   - Ensure versioning is enabled on both buckets

2. **Access Denied Errors**
   - Verify SSL/TLS is used (https://)
   - Check encryption headers are included
   - Validate IAM permissions

3. **High Costs**
   - Review lifecycle policies
   - Check Intelligent-Tiering recommendations
   - Analyze access patterns with S3 Analytics

4. **Compliance Findings**
   - Review Security Hub findings
   - Check Config rule compliance
   - Validate all security features are enabled

### Debug Commands

```bash
# Check bucket encryption
aws s3api get-bucket-encryption --bucket <bucket-name>

# Verify replication status
aws s3api get-bucket-replication --bucket <bucket-name>

# List access points
aws s3control list-access-points --account-id <account-id>

# Check Security Hub findings
aws securityhub get-findings --filters '{"ResourceType": [{"Value": "AwsS3Bucket", "Comparison": "EQUALS"}]}'
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

### Development Guidelines

- Follow Terraform best practices
- Include tests for new features
- Update documentation
- Run pre-commit hooks
- Ensure HIPAA compliance

## License

This module is licensed under the MIT License. See LICENSE file for details.

## Support

For issues and feature requests, please file a GitHub issue.

For security issues, please see SECURITY.md for responsible disclosure process.