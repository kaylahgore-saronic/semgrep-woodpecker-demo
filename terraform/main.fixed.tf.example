## Reference: what terraform/main.tf looks like with every planted finding remediated.
## Not a scan target (excluded via .semgrepignore's `*.example` pattern) -- this is what
## the `fixed` git branch's terraform/main.tf actually contains, kept here too as an
## easy side-by-side reference on every branch. Still never run `terraform apply` on this.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  # Credentials come from the environment / instance role, never hardcoded.
}

resource "aws_s3_bucket" "logs" {
  bucket = "saronic-demo-logs-bucket"

  tags = {
    Environment = "demo"
    owner       = "devsecops-team"
  }
}

resource "aws_s3_bucket_acl" "logs_acl" {
  bucket = aws_s3_bucket.logs.id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs_encryption" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "logs_versioning" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_security_group" "wide_open" {
  name        = "demo-wide-open-sg"
  description = "Demo SG restricted to a known office CIDR"

  ingress {
    description = "SSH from the office network only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ebs_volume" "data" {
  availability_zone = "us-east-1a"
  size              = 10
  encrypted         = true
}

resource "aws_db_instance" "demo" {
  identifier                      = "saronic-demo-db"
  engine                          = "postgres"
  engine_version                  = "15.4"
  instance_class                  = "db.t3.micro"
  allocated_storage               = 20
  username                        = "demo_admin"
  password                        = var.db_password
  storage_encrypted               = true
  publicly_accessible             = false
  skip_final_snapshot             = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = {
    Environment = "demo"
    owner       = "devsecops-team"
  }
}

variable "db_password" {
  type      = string
  sensitive = true
}

resource "aws_iam_policy" "scoped_access" {
  name = "demo-scoped-s3-read"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.logs.arn, "${aws_s3_bucket.logs.arn}/*"]
      }
    ]
  })
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "saronic-demo-artifacts-bucket"

  tags = {
    Environment = "demo"
    owner       = "devsecops-team"
  }
}
