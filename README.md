# terraform-aws-clientlog-edge

Terraform module that captures CloudFront access logs for server-side
analysis. It delivers CloudFront standard logs (v2, JSON) from one or more
distributions to an Amazon Data Firehose stream.

Server-side logs include requests from clients that run no JavaScript, such
as search crawlers and AI agents. A browser beacon cannot observe these
requests.

The module is part of Clientlog (https://www.clientlog.bayis.co.uk).

## Modes

- **Archive mode** (default). Firehose writes gzip-compressed, newline-delimited
  JSON to an S3 bucket created by the module.
- **Ingest mode**. Firehose sends batches to an HTTPS endpoint with an access
  key. This mode targets the Clientlog ingest endpoint, which is in
  development. Setting `ingest_url` selects it. The bucket then holds failed
  deliveries only.

## What it creates

- A private S3 bucket with lifecycle expiry
- A Firehose delivery stream and its IAM role
- A CloudWatch Logs delivery destination
- One delivery source and one delivery for each distribution

All resources are created in us-east-1. CloudFront delivers standard logs to
Firehose streams in that region only.

## Requirements

- Terraform 1.3 or later
- AWS provider 5.83 or later
- A provider alias for us-east-1
- One or more existing CloudFront distributions

## Usage

```hcl
provider "aws" {
  alias  = "us_east"
  region = "us-east-1"
}

module "edge_logging" {
  source = "github.com/bayinfosys/terraform-aws-clientlog-edge?ref=v0.1.0"

  providers = {
    aws.us_east = aws.us_east
  }

  name = "mysite"
  distribution_arns = {
    web = aws_cloudfront_distribution.web.arn
  }
}
```

A complete example is in `examples/basic`.

## Ingest mode

```hcl
module "edge_logging" {
  source = "github.com/bayinfosys/terraform-aws-clientlog-edge?ref=v0.1.0"

  providers = {
    aws.us_east = aws.us_east
  }

  name              = "mysite"
  distribution_arns = { web = aws_cloudfront_distribution.web.arn }

  ingest_url = "https://api.example.com/v1/ingest"
  api_key    = var.clientlog_api_key
  origin     = "https://www.example.com"
  project    = "example/home"
}
```

Changing `ingest_url` between null and a value replaces the Firehose stream
and the deliveries. The API key is stored in Terraform state, so keep the
state backend private.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| name | string | required | Name prefix for created resources |
| distribution_arns | map(string) | required | CloudFront distribution ARNs, keyed by a short label |
| ingest_url | string | null | HTTPS endpoint for ingest mode. Null selects archive mode |
| api_key | string (sensitive) | null | Access key sent to the endpoint. Required with ingest_url |
| origin | string | null | Site origin, sent as a common attribute. Required with ingest_url |
| project | string | null | Project name, sent as a common attribute. Required with ingest_url |
| record_fields | list(string) | null | Log fields to deliver. Null selects the default set |
| archive_prefix | string | "edge-logs/" | Key prefix for objects in the bucket |
| retention_days | number | 30 | Days before bucket objects expire |
| tags | map(string) | {} | Tags applied to created resources |

## Outputs

| Name | Description |
|------|-------------|
| bucket | Name of the S3 bucket |
| firehose_arn | ARN of the Firehose delivery stream |
| mode | "archive" or "ingest" |

## Choosing log fields

With `record_fields` unset, CloudFront delivers its default field set, which
may include the query string and cookie fields. Review the "Access log
fields" page in the CloudFront developer guide and list only the fields you
need. An unknown field name causes the apply to fail.

## Privacy and data handling

Access logs contain client IP addresses and user agent strings. In archive
mode they are stored in the bucket for `retention_days`. Choose fields and
retention to match your legal basis for processing. The operator of the site
is responsible for compliance under GDPR and applicable law.

## Limitations

- CloudFront only. Real-time logs are not supported.
- JSON output only.
- Deliveries for several distributions in one apply can return a
  ConflictException. Re-run the apply or use `-parallelism=1`.
- On the first apply, Firehose may report that it cannot assume its role.
  This is IAM propagation, and a second apply succeeds.

## Licence

MIT. See LICENSE.
