output "bucket_id" { value = aws_s3_bucket.frontend_bucket.id }
output "bucket_regional_domain_name" { value = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name }
output "website_endpoint" { value = aws_s3_bucket_website_configuration.frontend_bucket_website.website_endpoint }
output "website_url" { value = "http://${aws_s3_bucket_website_configuration.frontend_bucket_website.website_endpoint}" }
output "log_bucket_id" { value = aws_s3_bucket.log_bucket.id }
output "log_bucket_domain_name" { value = aws_s3_bucket.log_bucket.bucket_domain_name }
