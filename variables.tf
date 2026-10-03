variable "name" {
  description = "Name prefix for the resources this module creates"
  type        = string
}

variable "distribution_arns" {
  description = "CloudFront distribution ARNs to capture, keyed by a short label"
  type        = map(string)
}

variable "ingest_url" {
  description = "Clientlog ingest endpoint. Null selects archive mode."
  type        = string
  default     = null
}

variable "api_key" {
  description = "Clientlog API key, required when ingest_url is set"
  type        = string
  default     = null
  sensitive   = true
}

variable "origin" {
  description = "Registered site origin, required when ingest_url is set"
  type        = string
  default     = null
}

variable "project" {
  description = "Registered project, required when ingest_url is set"
  type        = string
  default     = null
}

variable "record_fields" {
  description = "CloudFront log fields to deliver. Null selects the default set."
  type        = list(string)
  default     = null
}

variable "archive_prefix" {
  description = "Key prefix for objects written to the bucket"
  type        = string
  default     = "edge-logs/"
}

variable "retention_days" {
  description = "Days before objects in the bucket expire"
  type        = number
  default     = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
