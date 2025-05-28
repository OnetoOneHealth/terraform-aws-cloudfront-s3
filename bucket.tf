locals {
  bucket_name_default = "${var.organization}-${var.environment}-${var.name}"
  bucket_name         = var.bucket_name == "" ? local.bucket_name_default : var.bucket_name
}

resource "aws_s3_bucket" "web" {
  bucket        = local.bucket_name
  force_destroy = var.bucket_force_destroy

  tags = merge(
    {
      "Name" = local.bucket_name
    },
    {
      "Environment" = var.environment
    },
    var.tags,
  )
}

# Read the policy description for cloudfront access

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.web.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "web" {
  bucket = aws_s3_bucket.web.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

# Private access policies

resource "aws_s3_bucket_ownership_controls" "web" {
  bucket = aws_s3_bucket.web.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "web" {
  depends_on = [
    aws_s3_bucket_ownership_controls.web
  ]

  bucket = aws_s3_bucket.web.id
  acl    = var.bucket_acl
}

resource "aws_s3_bucket_lifecycle_configuration" "web" {
  bucket = aws_s3_bucket.web.id

  rule {
    id     = "${local.bucket_name}-lifecycle"
    status = "Enabled"
    filter { prefix = "" }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }
  }
}

resource "aws_s3_bucket_versioning" "web" {
  bucket = aws_s3_bucket.web.id

  versioning_configuration {
    status = "Enabled"
  }
}
