## Semgrep demo: intentionally insecure Terraform.
## Every resource here plants one or more known findings for p/terraform, p/secrets,
## and the custom org rule in rules/terraform/. Never run `terraform apply` against this.
## Fake values only; there are no real cloud resources or credentials anywhere in this repo.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region     = "us-east-1"
  # Finding: hardcoded fake credentials (p/secrets).
  access_key = "AKIAIOSFODNN7EXAMPLE"
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}

# Finding: S3 bucket with no `owner` tag (custom rule rules/terraform/s3-required-owner-tag.yaml).
# Finding: public ACL (p/terraform).
resource "aws_s3_bucket" "logs" {
  bucket = "saronic-demo-logs-bucket"

  tags = {
    Environment = "demo"
  }
}

resource "aws_s3_bucket_acl" "logs_acl" {
  bucket = aws_s3_bucket.logs.id
  acl    = "public-read"
}

# Finding: bucket has no server-side encryption configuration (p/terraform).
# (intentionally omitted: aws_s3_bucket_server_side_encryption_configuration)

# Finding: bucket has no versioning configuration (p/terraform) -- a known MISS,
# several community Terraform rulesets don't check for this on its own; see docs/FINDINGS.md.
# (intentionally omitted: aws_s3_bucket_versioning)

# Finding: security group open to the world on SSH (p/terraform).
resource "aws_security_group" "wide_open" {
  name        = "demo-wide-open-sg"
  description = "Demo SG with an overly permissive ingress rule"

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Finding: unencrypted EBS volume (p/terraform).
resource "aws_ebs_volume" "data" {
  availability_zone = "us-east-1a"
  size              = 10
  encrypted         = false
}

# Finding: RDS instance with no storage encryption and a hardcoded fake password (p/terraform + p/secrets).
resource "aws_db_instance" "demo" {
  identifier          = "saronic-demo-db"
  engine              = "postgres"
  engine_version      = "15.4"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  username            = "demo_admin"
  # Justified suppression: this is a fake, demo-only credential (never a real DB password),
  # kept here specifically to demonstrate feature 4.4 (inline suppression). See docs/FINDINGS.md.
  password            = "SuperSecretPassw0rd!" # nosemgrep: terraform.lang.security.rds-insecure-password-storage-in-source-code.rds-insecure-password-storage-in-source-code
  storage_encrypted   = false
  publicly_accessible = true
  skip_final_snapshot = true
}

# Finding: IAM policy with wildcard actions/resources (p/terraform) -- KNOWN MISS candidate,
# kept to confirm whether the pack flags inline wildcard policies; documented either way.
resource "aws_iam_policy" "overly_permissive" {
  name = "demo-admin-everything"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      }
    ]
  })
}

# Correctly-tagged bucket, used as an `ok` example for the custom owner-tag rule.
resource "aws_s3_bucket" "artifacts" {
  bucket = "saronic-demo-artifacts-bucket"

  tags = {
    Environment = "demo"
    owner       = "devsecops-team"
  }
}
