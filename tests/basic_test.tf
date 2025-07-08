# Basic test configuration for PHI S3 bucket module
# Tests core functionality and compliance features

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

# Test basic bucket creation with all security features
run "basic_bucket_creation" {
  command = apply

  module {
    source = "./modules/s3-phi-bucket"
  }

  variables {
    bucket_name  = "test-phi-bucket-${timestamp()}"
    environment  = "test"
    
    enable_replication         = false  # Disable for faster tests
    enable_access_logging      = true
    enable_lifecycle_rules     = true
    enable_intelligent_tiering = true
    versioning_enabled         = true
    mfa_delete                 = false
    
    tags = {
      Test = "true"
    }
  }

  assert {
    condition     = output.bucket_id != ""
    error_message = "Bucket ID should not be empty"
  }

  assert {
    condition     = output.kms_key_arn != null
    error_message = "KMS key should be created"
  }

  assert {
    condition     = output.compliance_features.versioning_enabled == true
    error_message = "Versioning should be enabled"
  }

  assert {
    condition     = output.compliance_features.encryption_enabled == true
    error_message = "Encryption should be enabled"
  }

  assert {
    condition     = output.compliance_features.public_access_blocked == true
    error_message = "Public access should be blocked"
  }
}

# Test bucket policy enforcement
run "bucket_policy_test" {
  command = plan

  module {
    source = "./modules/s3-phi-bucket"
  }

  variables {
    bucket_name = "test-policy-bucket"
    environment = "test"
  }

  assert {
    condition     = jsondecode(output.bucket_policy_json).Statement[0].Sid == "DenyUnencryptedObjectUploads"
    error_message = "Bucket policy should deny unencrypted uploads"
  }

  assert {
    condition     = jsondecode(output.bucket_policy_json).Statement[1].Sid == "DenyInsecureConnections"
    error_message = "Bucket policy should deny non-SSL connections"
  }
}

# Test replication configuration
run "replication_test" {
  command = plan

  module {
    source = "./modules/s3-phi-bucket"
  }

  variables {
    bucket_name        = "test-replication-bucket"
    environment        = "test"
    enable_replication = true
    replication_region = "us-west-2"
  }

  assert {
    condition     = output.replica_bucket_id != null
    error_message = "Replica bucket should be created when replication is enabled"
  }

  assert {
    condition     = output.replica_bucket_region == "us-west-2"
    error_message = "Replica bucket should be in the specified region"
  }

  assert {
    condition     = output.replication_role_arn != null
    error_message = "Replication role should be created"
  }
}

# Test lifecycle rules configuration
run "lifecycle_rules_test" {
  command = plan

  module {
    source = "./modules/s3-phi-bucket"
  }

  variables {
    bucket_name            = "test-lifecycle-bucket"
    environment            = "test"
    enable_lifecycle_rules = true
    
    lifecycle_rules = [
      {
        id                       = "test-rule"
        enabled                  = true
        transition_days          = 30
        transition_storage_class = "STANDARD_IA"
        expiration_days          = 365
      }
    ]
  }

  assert {
    condition     = output.compliance_features.lifecycle_rules_count == 1
    error_message = "One lifecycle rule should be configured"
  }
}

# Test access points configuration
run "access_points_test" {
  command = plan

  module {
    source = "./modules/s3-phi-bucket"
  }

  variables {
    bucket_name = "test-access-points-bucket"
    environment = "test"
    
    access_point_configs = [
      {
        name   = "test-access-point"
        vpc_id = "vpc-12345678"
      }
    ]
  }

  assert {
    condition     = length(output.access_points) == 1
    error_message = "One access point should be created"
  }

  assert {
    condition     = output.compliance_features.access_points_count == 1
    error_message = "Access points count should be 1"
  }
}

# Test KMS encryption configuration
run "kms_encryption_test" {
  command = plan

  module {
    source = "./modules/s3-phi-bucket"
  }

  variables {
    bucket_name   = "test-kms-bucket"
    environment   = "test"
    sse_algorithm = "aws:kms"
  }

  assert {
    condition     = output.kms_key_arn != null
    error_message = "KMS key should be created for aws:kms encryption"
  }

  assert {
    condition     = output.compliance_features.encryption_algorithm == "aws:kms"
    error_message = "Encryption algorithm should be aws:kms"
  }

  assert {
    condition     = output.compliance_features.kms_key_rotation == true
    error_message = "KMS key rotation should be enabled"
  }
}

# Test with external KMS key
run "external_kms_key_test" {
  command = plan

  module {
    source = "./modules/s3-phi-bucket"
  }

  variables {
    bucket_name = "test-external-kms-bucket"
    environment = "test"
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  }

  assert {
    condition     = output.kms_key_arn == "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
    error_message = "Should use provided KMS key ARN"
  }
}

# Test monitoring module integration
run "monitoring_integration_test" {
  command = plan

  module {
    source = "./modules/monitoring"
  }

  variables {
    bucket_name              = "test-monitoring-bucket"
    bucket_arn               = "arn:aws:s3:::test-monitoring-bucket"
    environment              = "test"
    enable_sns_notifications = true
    notification_email       = "test@example.com"
  }

  assert {
    condition     = output.sns_topic_arn != null
    error_message = "SNS topic should be created for notifications"
  }

  assert {
    condition     = output.cloudtrail_name != null
    error_message = "CloudTrail should be created for monitoring"
  }
}

# Test Security Hub integration
run "security_hub_test" {
  command = plan

  module {
    source = "./modules/security-hub"
  }

  variables {
    bucket_name         = "test-security-hub-bucket"
    bucket_arn          = "arn:aws:s3:::test-security-hub-bucket"
    environment         = "test"
    enable_security_hub = true
    enable_config       = true
    enable_guardduty    = true
    enable_macie        = true
  }

  assert {
    condition     = output.compliance_status.security_hub_enabled == true
    error_message = "Security Hub should be enabled"
  }

  assert {
    condition     = output.compliance_status.hipaa_standard == true
    error_message = "HIPAA standard should be enabled in Security Hub"
  }

  assert {
    condition     = output.config_recorder_name != null
    error_message = "Config recorder should be created"
  }

  assert {
    condition     = output.guardduty_detector_id != null
    error_message = "GuardDuty detector should be created"
  }

  assert {
    condition     = output.macie_account_id != null
    error_message = "Macie should be enabled"
  }
}