# Generate random password for database
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Secrets Manager Secret
resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "${local.name_prefix}-db-secret-${random_string.suffix.result}"
  kms_key_id              = aws_kms_key.main.key_id
  recovery_window_in_days = 0 # Force delete on destroy for sandbox environment

  tags = local.common_tags
}

# Secret Version
resource "aws_secretsmanager_secret_version" "db_secret_val" {
  secret_id = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    username             = "petclinic"
    password             = random_password.db_password.result
    engine               = "mysql"
    host                 = aws_db_instance.db.address
    port                 = 3306
    dbInstanceIdentifier = aws_db_instance.db.identifier
  })
}

# Generate a random suffix to make secret names unique and avoid conflicts on recreation
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}
