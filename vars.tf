variable "dns_zone" {
  description = "DNS Zone for site's A record. Zone must already exist."
  type        = string
}

variable "site_name" {
  description = "Site short DNS name"
  type        = string
}

variable "site_files" {
  description = "Path to site files"
  type        = string
}

variable "subject_alt_names" {
  description = "SSL certificate subject alternative names, defaults to none"
  type        = list
}

variable "cf_default_ttl" {
  description = "CloudFront default TTL for cachine"
  type        = string
  default     = "86400"
}

variable "cf_min_ttl" {
  description = "CloudFront minimum TTL for caching"
  type        = string
  default     = "0"
}

variable "cf_max_ttl" {
  description = "CloudFront maximum TTL for caching"
  type        = string
  default     = "31536000"
}

variable "cf_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_All"
}

variable "custom_error_response" {
  description = "Optionally a list of custom error response configurations for CloudFront distribution"
  type = set(object({
    error_code         = number
    response_code      = number
    response_page_path = string
  }))
  default = []
}

variable "lambda_function_association" {
  type = list(object({
    event_type   = string
    include_body = bool
    lambda_arn   = string
  }))

  description = "A config block that triggers a lambda@edge function with specific actions"
  default     = []
}
