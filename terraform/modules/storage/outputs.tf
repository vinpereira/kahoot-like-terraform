output "website_bucket_id" {
  value = aws_s3_bucket.website.id
}

output "website_bucket_arn" {
  value = aws_s3_bucket.website.arn
}

output "artifacts_bucket_id" {
  value = aws_s3_bucket.artifacts.id
}

output "artifacts_bucket_arn" {
  value = aws_s3_bucket.artifacts.arn
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.website.id
}

output "cloudfront_distribution_arn" {
  value = aws_cloudfront_distribution.website.arn
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.website.domain_name
}