output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "The public DNS name of the Application Load Balancer"
}

output "alb_url_http" {
  value       = "http://${aws_lb.main.dns_name}"
  description = "HTTP connection URL (redirects to HTTPS)"
}

output "alb_url_https" {
  value       = "https://${aws_lb.main.dns_name}"
  description = "HTTPS connection URL"
}

output "rds_endpoint" {
  value       = aws_db_instance.db.endpoint
  description = "The endpoint of the RDS MySQL database"
}

output "rds_proxy_endpoint" {
  value       = "N/A - RDS Proxy not available on this account type"
  description = "RDS Proxy not available on restricted/academic accounts - connecting directly to RDS"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.deploy.id
  description = "The name of the S3 bucket used for deployments"
}

output "secrets_manager_secret_name" {
  value       = aws_secretsmanager_secret.db_secret.name
  description = "The name of the Secret in Secrets Manager"
}
