# =============================================================================
# S3 BUCKET (Application Storage)
# =============================================================================
# A general-purpose S3 bucket for the application.
# Could be used for file uploads, static assets, backups, etc.
#
# Security:
# - Versioning: keeps history of all file changes (recoverable)
# - Encryption: AES-256 at rest (data is encrypted on AWS disks)
# - Public access: COMPLETELY blocked (no accidental data leaks)
# - force_destroy: allows cleanup in lab environment
# =============================================================================

resource "aws_s3_bucket" "app_storage" {
  bucket        = "${var.project_name}-app-storage-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-app-storage"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
