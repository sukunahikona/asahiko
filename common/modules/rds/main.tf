# parameter store
data "aws_ssm_parameter" "rds_db_name" {
  name = "/${var.infra-basic-settings.name}/rds/db_name"
}
data "aws_ssm_parameter" "rds_user_name" {
  name = "/${var.infra-basic-settings.name}/rds/user_name"
}
data "aws_ssm_parameter" "rds_password" {
  name = "/${var.infra-basic-settings.name}/rds/password"
}

locals {
    ts = formatdate("YYYYMMDDhhmmss", timestamp())
    # Extract major version from engine version (e.g., "16.1" -> "16")
    postgresql_major_version = split(".", var.rds-settings.engine-version)[0]
}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "aurora_monitoring" {
  name = "${var.infra-basic-settings.name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.infra-basic-settings.name}-rds-monitoring-role"
  }
}

resource "aws_iam_role_policy_attachment" "aurora_monitoring" {
  role       = aws_iam_role.aurora_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# CloudWatch Log Groups for RDS
resource "aws_cloudwatch_log_group" "postgresql" {
  name              = "/aws/rds/cluster/${var.infra-basic-settings.name}-rds-cluster/postgresql"
  retention_in_days = 7

  tags = {
    Name = "${var.infra-basic-settings.name}-rds-postgresql-logs"
  }
}

# security group
resource "aws_security_group" "sg_rds" {
  name        = "${var.infra-basic-settings.name}-rds-sg"
  description = "RDS service security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.infra-basic-settings.name}-rds-sg"
  }
}

resource "aws_security_group_rule" "rds_ingress_postgres" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg_rds.id
}

resource "aws_security_group_rule" "rds_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg_rds.id
}

# subnet groups
resource "aws_db_subnet_group" "rds" {
  name        = "${var.infra-basic-settings.name}-rds-subnet-groups"
  description = "rds subnet group"
  subnet_ids  = var.private_subnet_ids
}

# rds
resource "aws_rds_cluster" "main" {
  cluster_identifier                  = "${var.infra-basic-settings.name}-rds-cluster"
  engine                              = "aurora-postgresql"
  engine_version                      = var.rds-settings.engine-version
  master_username                     = data.aws_ssm_parameter.rds_user_name.value
  master_password                     = data.aws_ssm_parameter.rds_password.value
  port                                = 5432
  database_name                       = data.aws_ssm_parameter.rds_db_name.value
  vpc_security_group_ids              = [aws_security_group.sg_rds.id]
  db_subnet_group_name                = aws_db_subnet_group.rds.name
  db_cluster_parameter_group_name     = aws_rds_cluster_parameter_group.main.name
  iam_database_authentication_enabled = true

  # CloudWatch Logs exports
  enabled_cloudwatch_logs_exports = ["postgresql"]

  #skip_final_snapshot = true
  final_snapshot_identifier  = "${var.infra-basic-settings.name}-snapshot-${local.ts}"
  snapshot_identifier        = "${var.rds-settings.snapshot-identifier}"
  apply_immediately   = true

  depends_on = [
    aws_cloudwatch_log_group.postgresql
  ]
}

resource "aws_rds_cluster_parameter_group" "main" {
  name   = "${var.infra-basic-settings.name}-rds-cluster-parameter-grp"
  family = "aurora-postgresql${local.postgresql_major_version}"

  parameter {
    name  = "log_statement"
    value = "all"
  }
}

resource "aws_rds_cluster_instance" "main" {
  count = 3

  cluster_identifier = aws_rds_cluster.main.id
  identifier         = "${var.infra-basic-settings.name}-instance-${count.index}"

  engine                  = aws_rds_cluster.main.engine
  engine_version          = aws_rds_cluster.main.engine_version
  instance_class          = "db.t4g.medium"
  db_subnet_group_name    = aws_db_subnet_group.rds.name
  db_parameter_group_name = aws_db_parameter_group.main.name

  # Enhanced Monitoring
  monitoring_role_arn = aws_iam_role.aurora_monitoring.arn
  monitoring_interval = 5
  #monitoring_interval = 60

  publicly_accessible = true
}

resource "aws_db_parameter_group" "main" {
  name   = "${var.infra-basic-settings.name}-rds-parameter-grp"
  family = "aurora-postgresql${local.postgresql_major_version}"

  parameter {
    apply_method = "pending-reboot"
    name  = "shared_preload_libraries"
    value = "pg_stat_statements,pg_hint_plan"
  }
}