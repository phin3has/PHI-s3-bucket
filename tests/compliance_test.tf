# Compliance-focused tests for PHI S3 bucket module
# Validates HIPAA compliance requirements

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    testing = {
      source  = "hashicorp/testing"
      version = ">= 0.1.0"
    }
  }
}

# Test HIPAA encryption requirements
run "hipaa_encryption_compliance" {
  command = plan

  module {
    source = "./modules/s3-phi-bucket"
  }

  variables {
    bucket_name = "test-hipaa-encryption"
    environment = "test"
  }

  # HIPAA §164.312(a)(2)(iv) - Encryption and decryption
  assert {
    condition     = output.compliance_features.encryption_enabled == true
    error_message = "HIPAA requires encryption at rest for PHI data"
  }

  assert {
    condition     = output.compliance_features.encryption_algorithm == "aws:kms"
    error_message = "HIPAA best practice is to use KMS encryption for PHI"
  }

  assert {
    condition     = output.compliance_features.kms_key_rotation == true
    error_message = "HIPAA requires regular key rotation"
  }

  # Verify SSL/TLS enforcement in bucket policy
  assert {
    condition     = contains(jsondecode(output.bucket_policy_json).Statement[*].Sid, "DenyInsecureConnections")
    error_message = "HIPAA requires encryption in transit - SSL/TLS must be enforced"
  }
}

# Test HIPAA access control requirements
run "hipaa_access_control_compliance" {
  command = plan

  module {
    source = "./modules/s3-phi-bucket"
  }

  variables {
    bucket_name = "test-hipaa-access-control"
    environment = "test"
    
    access_point_configs = [
      {
        name   = "controlled-access"
        vpc_id = "vpc-test123"
      }
    ]
  }

  # HIPAA §164.312(a)(1) - Access control
  assert {
    condition     = output.compliance_features.public_access_blocked == true
    error_message = "HIPAA requires blocking all public access to PHI"
  }

  assert {
    condition     = output.compliance_features.access_points_count > 0
    error_message = "HIPAA best practice is to use S3 Access Points for granular access control"
  }

  # Verify deny policy for public access
  assert {
    condition     = contains(jsondecode(output.bucket_policy_json).Statement[*].Sid, "DenyPublicReadWrite")
    error_message = "Bucket policy must explicitly deny public access"
  }
}

# Test HIPAA audit control requirements
run "hipaa_audit_control_compliance" {
  command = plan

  module {
    source = "./modules/s3-phi-bucket"
  }

  variables {
    bucket_name           = "test-hipaa-audit"
    environment           = "test"
    enable_access_logging = true
  }

  # HIPAA §164.312(b) - Audit controls
  assert {
    condition     = output.compliance_features.access_logging_enabled == true
    error_message = "HIPAA requires audit logging for PHI access"
  }

  assert {
    condition     = output.log_bucket_id != null
    error_message = "Access logs must be stored in a separate bucket"
  }
}

# Test HIPAA integrity requirements
run "hipaa_integrity_compliance" {
  command = plan

  module {
    source = "./modules/s3-phi-bucket"
  }

  variables {
    bucket_name        = "test-hipaa-integrity"
    environment        = "test"
    versioning_enabled = true
    mfa_delete         = false  # Would be true in production
  }

  # HIPAA §164.312(c)(1) - Integrity
  assert {
    condition     = output.compliance_features.versioning_enabled == true
    error_message = "HIPAA requires data integrity controls - versioning must be enabled"
  }

  # Verify delete protection in bucket policy
  assert {
    condition     = contains(jsondecode(output.bucket_policy_json).Statement[*].Sid, "DenyObjectDeletion")
    error_message = "HIPAA best practice is to restrict object deletion"
  }
}

# Test HIPAA contingency plan requirements
run "hipaa_contingency_compliance" {
  command = plan

  module {
    source = "./modules/s3-phi-bucket"
  }

  variables {
    bucket_name        = "test-hipaa-contingency"
    environment        = "test"
    enable_replication = true
    replication_region = "us-west-2"
  }

  # HIPAA §164.308(a)(7) - Contingency plan
  assert {
    condition     = output.compliance_features.replication_enabled == true
    error_message = "HIPAA requires data backup and disaster recovery"
  }

  assert {
    condition     = output.replica_bucket_id != null
    error_message = "Replica bucket must exist for disaster recovery"
  }

  assert {
    condition     = output.replica_bucket_region != var.aws_region
    error_message = "Replica must be in a different region for true disaster recovery"
  }
}

# Test comprehensive HIPAA compliance with all features
run "full_hipaa_compliance" {
  command = plan

  module {
    source = "./modules/s3-phi-bucket"
  }

  variables {
    bucket_name                = "test-full-hipaa-compliance"
    environment                = "test"
    enable_replication         = true
    replication_region         = "us-west-2"
    enable_access_logging      = true
    enable_lifecycle_rules     = true
    enable_intelligent_tiering = true
    versioning_enabled         = true
    block_public_access        = true
    sse_algorithm              = "aws:kms"
  }

  # Comprehensive compliance check
  assert {
    condition = alltrue([
      output.compliance_features.versioning_enabled,
      output.compliance_features.encryption_enabled,
      output.compliance_features.kms_key_rotation,
      output.compliance_features.access_logging_enabled,
      output.compliance_features.replication_enabled,
      output.compliance_features.public_access_blocked
    ])
    error_message = "All HIPAA compliance features must be enabled"
  }
}

# Test Security Hub HIPAA compliance checks
run "security_hub_hipaa_standards" {
  command = plan

  module {
    source = "./modules/security-hub"
  }

  variables {
    bucket_name         = "test-security-hub-hipaa"
    bucket_arn          = "arn:aws:s3:::test-security-hub-hipaa"
    environment         = "test"
    enable_security_hub = true
    enable_config       = true
  }

  assert {
    condition     = output.compliance_status.hipaa_standard == true
    error_message = "HIPAA Security Rule standard must be enabled in Security Hub"
  }

  assert {
    condition     = output.compliance_status.config_enabled == true
    error_message = "AWS Config must be enabled for continuous compliance monitoring"
  }
}

# Test Config rules for S3 HIPAA compliance
run "config_rules_hipaa_compliance" {
  command = plan

  module {
    source = "./modules/security-hub"
  }

  variables {
    bucket_name    = "test-config-hipaa"
    bucket_arn     = "arn:aws:s3:::test-config-hipaa"
    environment    = "test"
    enable_config  = true
  }

  assert {
    condition     = output.config_recorder_name != null
    error_message = "Config recorder must be enabled for compliance monitoring"
  }
}

# Test data classification with Macie
run "macie_phi_classification" {
  command = plan

  module {
    source = "./modules/security-hub"
  }

  variables {
    bucket_name   = "test-macie-phi"
    bucket_arn    = "arn:aws:s3:::test-macie-phi"
    environment   = "test"
    enable_macie  = true
  }

  assert {
    condition     = output.macie_account_id != null
    error_message = "Macie must be enabled for PHI data classification"
  }
}

# Test object lock for compliance retention
run "object_lock_compliance" {
  command = plan

  module {
    source = "./modules/s3-phi-bucket"
  }

  variables {
    bucket_name        = "test-object-lock"
    environment        = "test"
    enable_object_lock = true
    
    object_lock_configuration = {
      mode = "COMPLIANCE"
      days = 2555  # 7 years
    }
  }

  assert {
    condition     = output.compliance_features.object_lock_enabled == true
    error_message = "Object lock should be enabled for compliance retention"
  }
}