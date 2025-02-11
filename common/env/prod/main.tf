module "vpc" {
    source = "../../modules/vpc"
    infra-basic-settings = var.infra-basic-settings
    vpc-settings = var.vpc-settings
}

module "certificate" {
  source           = "../../modules/certificate"
  infra-basic-settings = var.infra-basic-settings
}

module "ec2" {
    source = "../../modules/ec2"
    infra-basic-settings = var.infra-basic-settings
    public_subnet_ids = module.vpc.public_subnet_ids
    private_subnet_ids = module.vpc.private_subnet_ids
    vpc_id = module.vpc.vpc_id
}

module "rds" {
    source = "../../modules/rds"
    infra-basic-settings = var.infra-basic-settings
    private_subnet_ids = module.vpc.private_subnet_ids
    vpc_id = module.vpc.vpc_id
    rds-settings = var.rds-settings
}