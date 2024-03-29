output "s3_bucket_arn" {
  value = aws_s3_bucket.site.arn
}

output "cf_domain_name" {
  value = aws_cloudfront_distribution.site[0].domain_name
}
