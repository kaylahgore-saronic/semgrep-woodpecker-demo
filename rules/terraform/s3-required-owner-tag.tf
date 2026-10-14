# ruleid: s3-required-owner-tag
resource "aws_s3_bucket" "bad_no_tags" {
  bucket = "test-bucket-no-tags"
}

# ruleid: s3-required-owner-tag
resource "aws_s3_bucket" "bad_other_tags" {
  bucket = "test-bucket-other-tags"
  tags = {
    Environment = "test"
  }
}

# ok: s3-required-owner-tag
resource "aws_s3_bucket" "good" {
  bucket = "test-bucket-good"
  tags = {
    Environment = "test"
    owner       = "devsecops-team"
  }
}
