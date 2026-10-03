locals {
  http_mode = var.ingest_url != null
}

resource "aws_s3_bucket" "logs" {
  provider      = aws.us_east
  bucket_prefix = "${var.name}-edge-logs-"
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "logs" {
  provider                = aws.us_east
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  provider = aws.us_east
  bucket   = aws_s3_bucket.logs.id

  rule {
    id     = "expire"
    status = "Enabled"
    filter {}
    expiration {
      days = var.retention_days
    }
  }
}

data "aws_iam_policy_document" "assume" {
  provider = aws.us_east

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "firehose" {
  provider           = aws.us_east
  name               = "${var.name}-edge-logs-firehose"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "bucket_access" {
  provider = aws.us_east

  statement {
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject",
    ]
    resources = [
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "firehose" {
  provider = aws.us_east
  name     = "bucket-access"
  role     = aws_iam_role.firehose.id
  policy   = data.aws_iam_policy_document.bucket_access.json
}

resource "aws_kinesis_firehose_delivery_stream" "this" {
  provider    = aws.us_east
  name        = "${var.name}-edge-logs"
  destination = local.http_mode ? "http_endpoint" : "extended_s3"
  tags        = var.tags

  dynamic "extended_s3_configuration" {
    for_each = local.http_mode ? [] : [1]
    content {
      role_arn            = aws_iam_role.firehose.arn
      bucket_arn          = aws_s3_bucket.logs.arn
      prefix              = var.archive_prefix
      error_output_prefix = "${var.archive_prefix}errors/"
      compression_format  = "GZIP"
      buffering_size      = 5
      buffering_interval  = 300
    }
  }

  dynamic "http_endpoint_configuration" {
    for_each = local.http_mode ? [1] : []
    content {
      url                = var.ingest_url
      name               = "clientlog"
      access_key         = var.api_key
      role_arn           = aws_iam_role.firehose.arn
      s3_backup_mode     = "FailedDataOnly"
      buffering_size     = 5
      buffering_interval = 300
      retry_duration     = 300

      request_configuration {
        content_encoding = "GZIP"

        common_attributes {
          name  = "origin"
          value = var.origin
        }
        common_attributes {
          name  = "project"
          value = var.project
        }
      }

      s3_configuration {
        role_arn           = aws_iam_role.firehose.arn
        bucket_arn         = aws_s3_bucket.logs.arn
        prefix             = "${var.archive_prefix}failed/"
        compression_format = "GZIP"
        buffering_size     = 5
        buffering_interval = 300
      }
    }
  }

  lifecycle {
    precondition {
      condition = (
        var.ingest_url == null ||
        (var.api_key != null && var.origin != null && var.project != null)
      )
      error_message = "api_key, origin and project are required when ingest_url is set."
    }
  }

  depends_on = [aws_iam_role_policy.firehose]
}

resource "aws_cloudwatch_log_delivery_destination" "this" {
  provider      = aws.us_east
  name          = "${var.name}-edge-logs"
  output_format = "json"
  tags          = var.tags

  delivery_destination_configuration {
    destination_resource_arn = aws_kinesis_firehose_delivery_stream.this.arn
  }
}

resource "aws_cloudwatch_log_delivery_source" "this" {
  for_each     = var.distribution_arns
  provider     = aws.us_east
  name         = "${var.name}-${each.key}"
  log_type     = "ACCESS_LOGS"
  resource_arn = each.value
  tags         = var.tags
}

resource "aws_cloudwatch_log_delivery" "this" {
  for_each                 = var.distribution_arns
  provider                 = aws.us_east
  delivery_source_name     = aws_cloudwatch_log_delivery_source.this[each.key].name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.this.arn
  record_fields            = var.record_fields
  tags                     = var.tags
}
