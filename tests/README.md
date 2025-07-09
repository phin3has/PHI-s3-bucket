# Terraform Module Tests

This directory contains Terraform tests for the PHI S3 bucket modules.

## Test Approach

All tests use `command = plan` to validate the module configuration without requiring AWS credentials or creating actual resources. This approach:

1. **Validates module syntax and logic** - Ensures all resources can be planned successfully
2. **Tests variable combinations** - Verifies different configuration options work together
3. **Checks outputs** - Validates that expected outputs are generated
4. **No AWS credentials required** - Tests can run in CI/CD without AWS access

## Running Tests Locally

```bash
# Run all tests
terraform test

# Run specific test file
terraform test -test-directory=tests/basic_test.tf
```

## CI/CD Integration

The GitHub Actions workflow will:
- Skip tests if AWS credentials are not configured
- Continue the workflow even if tests fail (continue-on-error: true)
- Show a warning message when tests are skipped

To enable full testing in CI/CD, configure these secrets in your repository:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

## Test Files

- `basic_test.tf` - Tests core S3 bucket functionality and security features
- `compliance_test.tf` - Tests HIPAA compliance configurations

## Notes

These tests use Terraform's native testing framework introduced in Terraform 1.5+. They focus on configuration validation rather than infrastructure provisioning, making them suitable for module development and CI/CD pipelines.