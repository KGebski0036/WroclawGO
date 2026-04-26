output "website_url" {
  description = "The S3 website URL to access the frontend"
  value       = module.s3.website_url
}

output "s3_bucket_name" {
  description = "The S3 bucket name to push your compiled Angular code to"
  value       = module.s3.bucket_id
}

output "aws_region" {
  description = "AWS region used for deployment"
  value       = var.aws_region
}

output "ecr_repo_url" {
  description = "ECR repository URL for the backend Docker image"
  value       = aws_ecr_repository.backend.repository_url
}

output "backend_url" {
  description = "The public backend base URL"
  value       = "http://${aws_instance.backend.public_ip}"
}

output "backend_public_ip" {
  description = "The public IP of the backend EC2 instance"
  value       = aws_instance.backend.public_ip
}

output "backend_instance_id" {
  description = "The EC2 instance id running the backend"
  value       = aws_instance.backend.id
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint hostname"
  value       = module.db.db_instance_address
  sensitive   = true
}

output "media_bucket_name" {
  description = "S3 bucket name for backend media uploads"
  value       = aws_s3_bucket.media.id
}
