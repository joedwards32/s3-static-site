# Local values

locals {
  site_fqdn = "${var.site_name}.${var.dns_zone}"
  site_aliases = var.subject_alt_names
  origin_id = "${var.site_name}-s3-origin"
}

# Create S3 bucket
resource "aws_s3_bucket" "site" {
  bucket = local.site_fqdn
  acl    = "private"
  force_destroy = true
}

# Build a list of site files
// consider always rebuilding the static site files first https://ilhicas.com/2019/08/17/Terraform-local-exec-run-always.html
module "template_files" {
  source = "hashicorp/dir/template"

  base_dir = "${var.site_files}"
  template_vars = {
  }
}

# Upload site files in "template_files" module to s3 bucket
resource "aws_s3_bucket_object" "site_files" {
  for_each = module.template_files.files

  bucket       = local.site_fqdn
  key          = each.key
  content_type = each.value.content_type

  # The template_files module guarantees that only one of these two attributes
  # will be set for each file, depending on whether it is an in-memory template
  # rendering result or a static file on disk.
  source  = each.value.source_path
  content = each.value.content

  # Unless the bucket has encryption enabled, the ETag of each object is an
  # MD5 hash of that object.
  etag = each.value.digests.md5
}

# SSL certificate for Site
## Create CSR in ACM
resource "aws_acm_certificate" "site" {
  provider = aws.us-east-1
  domain_name               = local.site_fqdn
  subject_alternative_names = var.subject_alt_names
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
    ignore_changes = [subject_alternative_names]
  }
}

## Validate SSL via DNS
data "aws_route53_zone" "site" {
  provider = aws.us-east-1
  name         = var.dns_zone
  private_zone = false
}

resource "aws_route53_record" "validate" {
  provider = aws.us-east-1
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.site.zone_id
}

resource "aws_acm_certificate_validation" "site" {
  provider = aws.us-east-1
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for record in aws_route53_record.validate : record.fqdn]
}

# CloudFront

resource "aws_cloudfront_origin_access_identity" "default" {
  comment = local.origin_id
}

resource "aws_cloudfront_distribution" "site" {
  count      = 1
  depends_on = [aws_s3_bucket.site]

  origin {
    domain_name = aws_s3_bucket.site.bucket_regional_domain_name

    origin_id   = local.origin_id
    origin_path = ""

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.default.cloudfront_access_identity_path
    }
  }

  dynamic "custom_error_response" {
    for_each = var.custom_error_response
    content {
      error_code         = custom_error_response.value.error_code
      response_code      = custom_error_response.value.response_code
      response_page_path = custom_error_response.value.response_page_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = local.site_aliases

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }

    }

    dynamic "lambda_function_association" {
      for_each = var.lambda_function_association
      content {
        event_type   = lambda_function_association.value.event_type
        include_body = lookup(lambda_function_association.value, "include_body", null)
        lambda_arn   = lambda_function_association.value.lambda_arn
      }
    }

    viewer_protocol_policy = "redirect-to-https"

    // Using CloudFront defaults, tune to liking
    min_ttl     = var.cf_min_ttl
    default_ttl = var.cf_default_ttl
    max_ttl     = var.cf_max_ttl
  }

  price_class = var.cf_price_class

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.site.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2019"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

# Grant Cloudfront acccess to S3 bucket
data "aws_iam_policy_document" "site" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.default.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site.json
}

# DNS Records
resource "aws_route53_record" "site" {
  provider = aws.us-east-1
  for_each = {
    for alias in local.site_aliases : alias => {
      name    = alias
    }
  }

  zone_id = data.aws_route53_zone.site.zone_id
  name    = each.value.name
  type    = "A"
  
  alias {
    name                   = aws_cloudfront_distribution.site[0].domain_name
    zone_id                = aws_cloudfront_distribution.site[0].hosted_zone_id
    evaluate_target_health = true
  }
}
