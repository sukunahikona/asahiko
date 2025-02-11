# commonで作成したvpcを取得
data "aws_vpc" "main" {
    filter {
        name = "tag:Name"
        values = [var.vpc-settings.name]
        #values = [var.vpc_name]
    }
}

# commonで作成したsubnets
data "aws_subnets" "public" {
    filter {
        name   = "vpc-id"
        values = [data.aws_vpc.main.id]
    }
    filter {
        name   = "tag:Name"
        values = ["${var.infra-basic-settings.name}-public*"]
    }
}

data "aws_subnets" "private" {
    filter {
        name   = "vpc-id"
        values = [data.aws_vpc.main.id]
    }
    filter {
        name   = "tag:Name"
        values = ["${var.infra-basic-settings.name}-private*"]
    }
}

data "aws_subnet" "public" {
    for_each = toset(data.aws_subnets.public.ids)

    vpc_id  = data.aws_vpc.main.id
    id      = each.value
}

data "aws_subnet" "private" {
    for_each = toset(data.aws_subnets.private.ids)

    vpc_id  = data.aws_vpc.main.id
    id      = each.value
}

locals {
  private_subnet_ids_az_map = {
    for subnet in data.aws_subnet.private :
    subnet.availability_zone => subnet.id
  }

  public_subnet_ids_az_map = {
    for subnet in data.aws_subnet.public :
    subnet.availability_zone => subnet.id
  }
}

# commonで作成したcertificate取得
data "aws_acm_certificate" "main" {
  domain   = "*.${var.infra-basic-settings.name}.${var.infra-basic-settings.domain-name}"
}

# commonで作成したRDS取得
data "aws_rds_cluster" "main" {
    cluster_identifier = "${var.infra-basic-settings.name}-rds-cluster"
}

# region取得
data "aws_region" "current" {}

module "ec2" {
    source = "../../modules/ec2"
    infra-basic-settings    = var.infra-basic-settings
    public_subnet_id_map       = local.public_subnet_ids_az_map
    private_subnet_id_map      = local.private_subnet_ids_az_map
    vpc_id = data.aws_vpc.main.id
}

module "alb" {
    source                = "../../modules/alb"
    infra-basic-settings    = var.infra-basic-settings
    cert_arn              = data.aws_acm_certificate.main.arn
    public_subnet_ids     = [for subnet in data.aws_subnet.public : subnet.id]
    vpc_id                = data.aws_vpc.main.id
}

module "ecr" {
    source         = "../../modules/ecr"
    ecr-name       = var.ecr-settings.ecr-name
    aws-region     = data.aws_region.current.name
    app-name       = var.ecr-settings.app-name
    container-name = var.ecr-settings.container-name
}

module "ecs" {
    source         = "../../modules/ecs"
    vpc_id  = data.aws_vpc.main.id
    infra-basic-settings    = var.infra-basic-settings
    private_subnet_ids     = [for subnet in data.aws_subnet.private : subnet.id]
    aws_ecr_repository_main_repository_url = module.ecr.aws_ecr_repository_main_repository_url
    alb_tg_main_arn = module.alb.alb_tg_main_arn
    aws_lb_listener_https_arn = module.alb.aws_lb_listener_https_arn
    aws_rds_endpoint = data.aws_rds_cluster.main.endpoint
}