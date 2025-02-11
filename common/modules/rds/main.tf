locals {
    ts = formatdate("YYYYMMDDhhmmss", timestamp())
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
  master_username                     = var.rds-settings.db-username
  master_password                     = var.rds-settings.db-password
  port                                = 5432
  database_name                       = var.rds-settings.db-name
  vpc_security_group_ids              = [aws_security_group.sg_rds.id]
  db_subnet_group_name                = aws_db_subnet_group.rds.name
  db_cluster_parameter_group_name     = aws_rds_cluster_parameter_group.main.name
  iam_database_authentication_enabled = true

  #skip_final_snapshot = true
  final_snapshot_identifier  = "${var.infra-basic-settings.name}-snapshot-${local.ts}"
  snapshot_identifier        = "${var.rds-settings.snapshot-identifier}"
  apply_immediately   = true
}

resource "aws_rds_cluster_parameter_group" "main" {
  name   = "${var.infra-basic-settings.name}-rds-cluster-parameter-grp"
  family = "aurora-postgresql16"
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

  #monitoring_role_arn = aws_iam_role.aurora_monitoring.arn
  #monitoring_interval = 60

  publicly_accessible = true
}

resource "aws_db_parameter_group" "main" {
  name   = "${var.infra-basic-settings.name}-rds-parameter-grp"
  family = "aurora-postgresql16"

  parameter {
    apply_method = "pending-reboot"
    name  = "shared_preload_libraries"
    value = "pg_stat_statements,pg_hint_plan"
  }
}

# systems manager store param for rds cluster endpiont
resource "aws_ssm_parameter" "rds_cluster_endpoint" {
  name  = "/${var.infra-basic-settings.name}/rds_cluster_endpoint"
  type  = "String"
  value = aws_rds_cluster.main.endpoint
}