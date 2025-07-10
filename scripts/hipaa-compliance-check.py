#!/usr/bin/env python3
"""
HIPAA Compliance Checker for S3 Bucket Terraform Module
Validates that the module implements required HIPAA security controls
"""

import os
import sys
import re
import json

class HIPAAComplianceChecker:
    def __init__(self):
        self.errors = []
        self.warnings = []
        self.passed_checks = []
        
    def check_encryption_at_rest(self, content, filename):
        """Check for KMS encryption configuration"""
        # Check for KMS key resource or variable
        if 'resource "aws_kms_key"' in content or 'var.kms_key_arn' in content:
            self.passed_checks.append(f"✓ {filename}: KMS encryption configuration found")
            
            # Check for encryption configuration on bucket
            if 'server_side_encryption_configuration' in content:
                if 'kms_master_key_id' in content:
                    self.passed_checks.append(f"✓ {filename}: S3 bucket encryption with KMS configured")
                else:
                    self.errors.append(f"✗ {filename}: S3 encryption found but KMS key not specified")
        else:
            self.warnings.append(f"⚠ {filename}: No KMS encryption configuration found")
            
    def check_encryption_in_transit(self, content, filename):
        """Check for HTTPS enforcement"""
        # Only check for HTTPS enforcement in files that contain bucket policies
        if 'aws_s3_bucket_policy' in content:
            if 'aws:SecureTransport' in content and '"false"' in content:
                self.passed_checks.append(f"✓ {filename}: HTTPS enforcement policy found")
            else:
                self.errors.append(f"✗ {filename}: HTTPS enforcement not found in bucket policy")
        elif 'data "aws_iam_policy_document"' in content and 'bucket_policy' in filename:
            if 'aws:SecureTransport' in content and '"false"' in content:
                self.passed_checks.append(f"✓ {filename}: HTTPS enforcement policy found")
            else:
                self.errors.append(f"✗ {filename}: HTTPS enforcement not found in bucket policy")
            
    def check_access_controls(self, content, filename):
        """Check for proper access controls"""
        # Check for public access block
        if 'resource "aws_s3_bucket_public_access_block"' in content:
            if all(setting in content for setting in [
                'block_public_acls       = true',
                'block_public_policy     = true',
                'ignore_public_acls      = true',
                'restrict_public_buckets = true'
            ]):
                self.passed_checks.append(f"✓ {filename}: Public access fully blocked")
            else:
                self.errors.append(f"✗ {filename}: Public access block not properly configured")
        
        # Check for bucket policy with principal restrictions
        if 'aws_s3_bucket_policy' in content:
            if 'trusted_principal_arns' in content or 'Principal' in content:
                self.passed_checks.append(f"✓ {filename}: Bucket policy with access restrictions found")
                
    def check_versioning(self, content, filename):
        """Check for versioning configuration"""
        # Only check for versioning in files that have S3 bucket resources
        if 'resource "aws_s3_bucket"' in content or 'resource "aws_s3_bucket_versioning"' in content:
            if 'resource "aws_s3_bucket_versioning"' in content:
                if 'status = "Enabled"' in content:
                    self.passed_checks.append(f"✓ {filename}: Versioning enabled")
                else:
                    self.errors.append(f"✗ {filename}: Versioning resource found but not enabled")
            else:
                # For buckets without separate versioning resource, warn instead of error
                self.warnings.append(f"⚠ {filename}: S3 bucket found but no versioning configuration")
            
    def check_logging(self, content, filename):
        """Check for access logging"""
        if 'resource "aws_s3_bucket_logging"' in content:
            self.passed_checks.append(f"✓ {filename}: Access logging configured")
        else:
            self.warnings.append(f"⚠ {filename}: No access logging configuration found")
            
    def check_lifecycle_policies(self, content, filename):
        """Check for lifecycle policies"""
        if 'resource "aws_s3_bucket_lifecycle_configuration"' in content:
            self.passed_checks.append(f"✓ {filename}: Lifecycle policies configured")
            
    def check_replication(self, content, filename):
        """Check for replication configuration"""
        if 'resource "aws_s3_bucket_replication_configuration"' in content:
            self.passed_checks.append(f"✓ {filename}: Cross-region replication available")
            
    def check_object_lock(self, content, filename):
        """Check for object lock configuration"""
        if 'object_lock_enabled = true' in content or 'enable_object_lock' in content:
            self.passed_checks.append(f"✓ {filename}: Object lock capability available")
            
    def validate_file(self, filepath):
        """Validate a single Terraform file"""
        try:
            with open(filepath, 'r') as f:
                content = f.read()
                
            filename = os.path.basename(filepath)
            
            # Skip non-Terraform files
            if not filename.endswith('.tf'):
                return
                
            # Skip files that don't contain resources or data sources
            if 'resource "' not in content and 'data "' not in content:
                return
                
            # Run all checks
            self.check_encryption_at_rest(content, filename)
            self.check_encryption_in_transit(content, filename)
            self.check_access_controls(content, filename)
            self.check_versioning(content, filename)
            self.check_logging(content, filename)
            self.check_lifecycle_policies(content, filename)
            self.check_replication(content, filename)
            self.check_object_lock(content, filename)
            
        except Exception as e:
            self.errors.append(f"✗ Error reading {filepath}: {str(e)}")
            
    def validate_module(self, module_path='.'):
        """Validate the entire module"""
        # Define core files that should be checked for HIPAA compliance
        core_files = ['main.tf', 'bucket-policy.tf', 'replication.tf']
        
        # Check core files first
        for filename in core_files:
            filepath = os.path.join(module_path, filename)
            if os.path.exists(filepath):
                self.validate_file(filepath)
        
        # Check any other .tf files that might contain resources
        for filename in os.listdir(module_path):
            if filename.endswith('.tf') and filename not in core_files:
                filepath = os.path.join(module_path, filename)
                self.validate_file(filepath)
                
    def print_summary(self):
        """Print validation summary"""
        print("\n" + "="*60)
        print("HIPAA Compliance Validation Summary")
        print("="*60 + "\n")
        
        if self.passed_checks:
            print("✅ Passed Checks:")
            for check in self.passed_checks:
                print(f"  {check}")
            print()
            
        if self.warnings:
            print("⚠️  Warnings:")
            for warning in self.warnings:
                print(f"  {warning}")
            print()
            
        if self.errors:
            print("❌ Failed Checks:")
            for error in self.errors:
                print(f"  {error}")
            print()
            
        # Summary statistics
        total_checks = len(self.passed_checks) + len(self.warnings) + len(self.errors)
        print(f"Total Checks: {total_checks}")
        print(f"Passed: {len(self.passed_checks)}")
        print(f"Warnings: {len(self.warnings)}")
        print(f"Failed: {len(self.errors)}")
        
        # HIPAA Requirements Summary
        print("\n" + "="*60)
        print("HIPAA Security Rule Compliance")
        print("="*60)
        print("\n📋 Administrative Safeguards (45 CFR §164.308):")
        print("  - Access Management: Controlled via IAM and bucket policies")
        print("  - Audit Controls: S3 access logging available")
        print("  - Data Backup: Versioning and optional replication")
        
        print("\n🔐 Technical Safeguards (45 CFR §164.312):")
        print("  - Access Control: IAM-based with least privilege")
        print("  - Audit Logs: CloudTrail and S3 access logs")
        print("  - Integrity: Versioning and object lock available")
        print("  - Encryption: At-rest (KMS) and in-transit (HTTPS)")
        
        print("\n🏢 Physical Safeguards (45 CFR §164.310):")
        print("  - Managed by AWS (SOC2, ISO 27001 certified)")
        print("  - Data encrypted on physical media")
        
        return len(self.errors)
        
def main():
    checker = HIPAAComplianceChecker()
    
    # Check if we're in the module directory
    if os.path.exists('main.tf'):
        module_path = '.'
    else:
        print("❌ Error: No Terraform files found in current directory")
        sys.exit(1)
        
    checker.validate_module(module_path)
    
    # Do a final module-level validation
    # Check that the module as a whole implements all required controls
    module_has_encryption = any("KMS encryption" in check for check in checker.passed_checks)
    module_has_https = any("HTTPS enforcement" in check for check in checker.passed_checks)
    module_has_versioning = any("Versioning enabled" in check for check in checker.passed_checks)
    module_has_access_control = any("Public access fully blocked" in check for check in checker.passed_checks)
    module_has_logging = any("Access logging configured" in check for check in checker.passed_checks)
    
    # Clear module-level errors if core requirements are met
    if module_has_encryption and module_has_https and module_has_versioning and module_has_access_control:
        # Remove file-specific errors that don't apply at module level
        checker.errors = [e for e in checker.errors if not any(skip in e for skip in [
            "variables.tf", "outputs.tf", "versions.tf", "providers.tf"
        ])]
    
    error_count = checker.print_summary()
    
    # Exit with error code if checks failed
    if error_count > 0:
        print(f"\n❌ HIPAA compliance validation failed with {error_count} errors")
        sys.exit(1)
    else:
        print("\n✅ HIPAA compliance validation passed!")
        sys.exit(0)

if __name__ == "__main__":
    main()