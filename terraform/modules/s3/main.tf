resource "aws_s3_bucket" "frontend_bucket" {
  bucket        = var.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "frontend_bucket_website" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_versioning" "frontend_bucket_versioning" {
  bucket = aws_s3_bucket.frontend_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend_bucket_sse" {
  bucket = aws_s3_bucket.frontend_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "frontend_bucket_lifecycle" {
  bucket = aws_s3_bucket.frontend_bucket.id

  rule {
    id     = "frontend-lifecycle"
    status = "Enabled"

    filter {}

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket" "log_bucket" {
  bucket        = "${var.bucket_name}-logs"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "log_bucket_versioning" {
  bucket = aws_s3_bucket.log_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "log_bucket_block_public_access" {
  bucket                  = aws_s3_bucket.log_bucket.id
  block_public_acls       = false
  block_public_policy     = true
  ignore_public_acls      = false
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "log_bucket_ownership" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    object_ownership = "ObjectWriter"
  }

  depends_on = [aws_s3_bucket_public_access_block.log_bucket_block_public_access]
}

resource "aws_s3_bucket_acl" "log_bucket_acl" {
  bucket = aws_s3_bucket.log_bucket.id
  acl    = "log-delivery-write"

  depends_on = [aws_s3_bucket_ownership_controls.log_bucket_ownership]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket_sse" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "log_bucket_lifecycle" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    id     = "logs-expiration"
    status = "Enabled"

    filter {}

    expiration {
      days = var.log_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_policy" "log_bucket_policy" {
  bucket = aws_s3_bucket.log_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontLogDelivery"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = ["s3:PutObject"]
        Resource  = "${aws_s3_bucket.log_bucket.arn}/cloudfront/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid       = "AllowS3ServerAccessLogs"
        Effect    = "Allow"
        Principal = { Service = "logging.s3.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.log_bucket.arn}/s3/*"
      }
    ]
  })
}

resource "aws_s3_bucket_logging" "frontend_bucket_logging" {
  bucket        = aws_s3_bucket.frontend_bucket.id
  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "s3/"
}

resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket                  = aws_s3_bucket.frontend_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_read_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowPublicReadForWebsite"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_website_configuration.frontend_bucket_website,
    aws_s3_bucket_public_access_block.block_public_access
  ]
}
