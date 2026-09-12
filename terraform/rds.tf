resource "aws_db_subnet_group" "db" {
  name       = local.name
  subnet_ids = aws_subnet.db[*].id
}
resource "aws_db_parameter_group" "db" {
  name   = "${local.name}-pg17"
  family = "postgres17"
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}
resource "aws_db_instance" "db" {
  identifier                      = local.name
  engine                          = "postgres"
  engine_version                  = "17"
  instance_class                  = var.db_instance_class
  allocated_storage               = 20
  max_allocated_storage           = 100
  storage_type                    = "gp3"
  storage_encrypted               = true
  db_name                         = "solicitudes"
  username                        = "solicitudes_owner"
  manage_master_user_password     = true
  db_subnet_group_name            = aws_db_subnet_group.db.name
  parameter_group_name            = aws_db_parameter_group.db.name
  vpc_security_group_ids          = [aws_security_group.db.id]
  publicly_accessible             = false
  multi_az                        = var.multi_az
  backup_retention_period         = var.environment == "prod" ? 14 : 7
  backup_window                   = "03:00-04:00"
  maintenance_window              = "sun:05:00-sun:06:00"
  auto_minor_version_upgrade      = true
  copy_tags_to_snapshot           = true
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = false
  final_snapshot_identifier       = "${local.name}-final"
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
}

# El valor se crea con AWS get-random-password en el script, nunca en Terraform.
resource "aws_secretsmanager_secret" "app" {
  name                    = "${local.name}/database-app"
  recovery_window_in_days = 7
}
