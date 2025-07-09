# Compliance Scripts

This directory contains Python scripts for validating HIPAA compliance of the Terraform modules.

## Scripts

### hipaa-compliance-check.py

Validates Terraform configurations against HIPAA security requirements:
- Checks for encryption at rest (S3, KMS)
- Verifies access controls (public access blocks)
- Validates audit logging (CloudTrail, S3 access logs)
- Ensures data integrity controls (versioning)
- Checks KMS key rotation

**Usage:**
```bash
python scripts/hipaa-compliance-check.py
```

**Exit codes:**
- 0: All checks passed
- 1: One or more critical errors found

### generate-compliance-report.py

Generates a detailed markdown report of HIPAA compliance status:
- Encryption compliance
- Access control implementation
- Audit logging configuration
- Data integrity controls
- Monitoring and alerting setup

**Usage:**
```bash
python scripts/generate-compliance-report.py > compliance-report.md
```

## CI/CD Integration

These scripts are automatically run in the GitHub Actions workflow:
1. `hipaa-compliance-check.py` validates the configuration
2. `generate-compliance-report.py` creates a report artifact

## Requirements

- Python 3.6+
- No external dependencies (uses standard library only)

## Adding New Checks

To add new compliance checks:
1. Add the check method to `HIPAAComplianceChecker` class
2. Call the method from `check_file()`
3. Update the report generator if needed

## HIPAA Controls Validated

- **Encryption**: KMS, S3 SSE
- **Access Control**: IAM, S3 bucket policies, public access blocks
- **Audit**: CloudTrail, S3 access logs
- **Integrity**: Versioning, MFA delete
- **Monitoring**: CloudWatch, SNS