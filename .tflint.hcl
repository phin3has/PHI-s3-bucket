config {
  format = "compact"
  module = true
  force = false
  disabled_by_default = false
}

# AWS Provider rules
plugin "aws" {
  enabled = true
  version = "0.28.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Basic Terraform rules
rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_module_pinned_source" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
  format = "snake_case"
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_standard_module_structure" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_unused_required_providers" {
  enabled = true
}

# AWS specific rules for S3 security
rule "aws_s3_bucket_public_access_block" {
  enabled = true
}

rule "aws_s3_bucket_server_side_encryption" {
  enabled = true
}

# Security-focused rules
rule "aws_iam_policy_document_gov_friendly_arns" {
  enabled = true
}

rule "aws_iam_role_policy_gov_friendly_arns" {
  enabled = true
}

rule "aws_resource_missing_tags" {
  enabled = true
  tags = ["Environment", "ManagedBy", "Purpose"]
}

# Cost optimization rules
rule "aws_instance_invalid_type" {
  enabled = true
}

rule "aws_db_instance_invalid_type" {
  enabled = true
}