# RDS DB Subnet Group
resource "aws_db_subnet_group" "db" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = aws_subnet.private_db[*].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-subnet-group"
  })
}

# RDS MySQL Instance (Multi-AZ)
resource "aws_db_instance" "db" {
  identifier             = "${local.name_prefix}-mysql-db"
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_type           = "gp3"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  db_name                = "petclinic"
  username               = "petclinic"
  password               = random_password.db_password.result
  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.rds_db.id]
  multi_az               = true
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.main.arn
  skip_final_snapshot    = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-mysql-db"
  })
}

# NOTE: RDS Proxy removed - not available on restricted/academic accounts.
# Application connects directly to the RDS instance endpoint.
