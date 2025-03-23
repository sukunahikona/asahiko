module "ssm" {
    source = "../../modules/ssm_parameter"
    infra-basic-settings = var.infra-basic-settings
}