# S3 Bucket for deployment artifacts
resource "aws_s3_bucket" "deploy" {
  bucket        = "${var.project_name}-${var.environment}-deploy-${random_string.suffix.result}"
  force_destroy = true # Allow clean deletion on destroy

  tags = local.common_tags
}

# Block public access
resource "aws_s3_bucket_public_access_block" "deploy" {
  bucket = aws_s3_bucket.deploy.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encryption configuration
resource "aws_s3_bucket_server_side_encryption_configuration" "deploy" {
  bucket = aws_s3_bucket.deploy.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.main.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Upload the compiled JAR to the S3 bucket
resource "aws_s3_object" "app_jar" {
  bucket     = aws_s3_bucket.deploy.id
  key        = "petclinic.jar"
  source     = "${path.module}/../target/spring-petclinic-4.0.0-SNAPSHOT.jar"
  kms_key_id = aws_kms_key.main.arn

  # This trigger ensures the JAR is re-uploaded when the file changes locally
  source_hash = filemd5("${path.module}/../target/spring-petclinic-4.0.0-SNAPSHOT.jar")

  depends_on = [
    aws_s3_bucket_server_side_encryption_configuration.deploy
  ]
}
