output "bucket" {
  value = aws_s3_bucket.logs.id
}

output "firehose_arn" {
  value = aws_kinesis_firehose_delivery_stream.this.arn
}

output "mode" {
  value = local.http_mode ? "ingest" : "archive"
}
