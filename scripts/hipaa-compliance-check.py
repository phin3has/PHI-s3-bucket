#!/usr/bin/env python3
"""
HIPAA Compliance Check Script
Validates Terraform modules against HIPAA security requirements
"""

import json
import os
import sys
import glob
import re
from pathlib import Path

class HIPAAComplianceChecker:
    def __init__(self):
        self.errors = []
        self.warnings = []
        self.passed_checks = []
        
    def check_file(self, filepath):
        """Check a single Terraform file for HIPAA compliance"""
        with open(filepath, 'r') as f:
            content = f.read()
            
        filename = os.path.basename(filepath)
        
        # Check for encryption
        if 'aws_s3_bucket' in content:
            self.check_s3_encryption(content, filename)
            self.check_s3_versioning(content, filename)
            self.check_s3_access_logging(content, filename)
            
        # Check for KMS key rotation
        if 'aws_kms_key' in content:
            self.check_kms_rotation(content, filename)
            
        # Check for public access blocks
        if 'aws_s3_bucket_public_access_block' in content:
            self.check_public_access_block(content, filename)
            
        # Check for CloudTrail
        if 'aws_cloudtrail' in content:
            self.check_cloudtrail_encryption(content, filename)
            self.check_cloudtrail_validation(content, filename)
            
    def check_s3_encryption(self, content, filename):
        """Verify S3 buckets have encryption configured"""
        # Check for encryption configuration resource
        if 'aws_s3_bucket_server_side_encryption_configuration' in content:
            if 'sse_algorithm' in content:
                if 'aws:kms' in content or 'AES256' in content:
                    self.passed_checks.append(f"{filename}: S3 encryption properly configured")
                else:
                    self.errors.append(f"{filename}: S3 encryption must use KMS or AES256")
            else:
                self.errors.append(f"{filename}: S3 encryption configuration missing algorithm")
        elif 'aws_s3_bucket' in content and 'checkov:skip=CKV_AWS_145' not in content:
            self.warnings.append(f"{filename}: S3 bucket found without separate encryption configuration")
            
    def check_s3_versioning(self, content, filename):
        """Verify S3 buckets have versioning enabled"""
        if 'aws_s3_bucket_versioning' in content:
            if 'status = "Enabled"' in content or 'status     = "Enabled"' in content:
                self.passed_checks.append(f"{filename}: S3 versioning enabled")
            else:
                self.warnings.append(f"{filename}: S3 versioning status unclear")
                
    def check_s3_access_logging(self, content, filename):
        """Verify S3 buckets have access logging configured"""
        if 'aws_s3_bucket_logging' in content:
            self.passed_checks.append(f"{filename}: S3 access logging configured")
        elif 'aws_s3_bucket' in content and 'log' not in filename.lower():
            self.warnings.append(f"{filename}: Consider enabling S3 access logging")
            
    def check_kms_rotation(self, content, filename):
        """Verify KMS keys have rotation enabled"""
        if 'enable_key_rotation' in content:
            if 'enable_key_rotation = true' in content or 'enable_key_rotation      = true' in content:
                self.passed_checks.append(f"{filename}: KMS key rotation enabled")
            else:
                self.errors.append(f"{filename}: KMS key rotation must be enabled for HIPAA compliance")
                
    def check_public_access_block(self, content, filename):
        """Verify S3 public access is blocked"""
        required_settings = [
            'block_public_acls       = true',
            'block_public_policy     = true',
            'ignore_public_acls      = true',
            'restrict_public_buckets = true'
        ]
        
        missing_settings = []
        for setting in required_settings:
            # Check with different spacing patterns
            setting_base = setting.split('=')[0].strip()
            if not re.search(f'{setting_base}\\s*=\\s*true', content):
                missing_settings.append(setting_base)
                
        if not missing_settings:
            self.passed_checks.append(f"{filename}: S3 public access properly blocked")
        else:
            self.errors.append(f"{filename}: Missing public access blocks: {', '.join(missing_settings)}")
            
    def check_cloudtrail_encryption(self, content, filename):
        """Verify CloudTrail uses KMS encryption"""
        if 'kms_key_id' in content:
            self.passed_checks.append(f"{filename}: CloudTrail KMS encryption configured")
        else:
            self.warnings.append(f"{filename}: CloudTrail should use KMS encryption")
            
    def check_cloudtrail_validation(self, content, filename):
        """Verify CloudTrail has log file validation enabled"""
        if 'enable_log_file_validation' in content:
            if 'enable_log_file_validation   = true' in content or 'enable_log_file_validation = true' in content:
                self.passed_checks.append(f"{filename}: CloudTrail log validation enabled")
            else:
                self.errors.append(f"{filename}: CloudTrail log validation must be enabled")
                
    def run_checks(self):
        """Run compliance checks on all Terraform files"""
        # Find all .tf files in modules directory
        tf_files = glob.glob('modules/**/*.tf', recursive=True)
        
        if not tf_files:
            self.errors.append("No Terraform files found in modules directory")
            return
            
        print(f"Checking {len(tf_files)} Terraform files for HIPAA compliance...")
        
        for tf_file in tf_files:
            self.check_file(tf_file)
            
    def generate_report(self):
        """Generate compliance report"""
        total_checks = len(self.passed_checks) + len(self.errors) + len(self.warnings)
        
        print("\n" + "="*60)
        print("HIPAA COMPLIANCE CHECK REPORT")
        print("="*60)
        
        print(f"\nTotal files scanned: {len(glob.glob('modules/**/*.tf', recursive=True))}")
        print(f"Total checks performed: {total_checks}")
        print(f"Passed: {len(self.passed_checks)}")
        print(f"Errors: {len(self.errors)}")
        print(f"Warnings: {len(self.warnings)}")
        
        if self.passed_checks:
            print("\n✅ PASSED CHECKS:")
            for check in self.passed_checks:
                print(f"  - {check}")
                
        if self.warnings:
            print("\n⚠️  WARNINGS:")
            for warning in self.warnings:
                print(f"  - {warning}")
                
        if self.errors:
            print("\n❌ ERRORS:")
            for error in self.errors:
                print(f"  - {error}")
                
        print("\n" + "="*60)
        
        # Exit with error code if there are errors
        if self.errors:
            print("\n❌ HIPAA compliance check FAILED")
            sys.exit(1)
        else:
            print("\n✅ HIPAA compliance check PASSED")
            
def main():
    checker = HIPAAComplianceChecker()
    checker.run_checks()
    checker.generate_report()
    
if __name__ == "__main__":
    main()