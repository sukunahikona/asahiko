# systems manager store param for rds cluster endpiont
resource "aws_ssm_parameter" "rds_user_name" {
  name  = "/${var.infra-basic-settings.name}/rds/user_name"
  type  = "String"
  value = "${var.infra-basic-settings.name}"
}

resource "aws_ssm_parameter" "rds_password" {
  name  = "/${var.infra-basic-settings.name}/rds/password"
  type  = "SecureString"
  value = "dummy"
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/${var.infra-basic-settings.name}/rds/db_name"
  type  = "String"
  value = "${var.infra-basic-settings.name}db"
}