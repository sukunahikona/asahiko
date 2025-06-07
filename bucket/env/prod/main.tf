module "s3" {
    source = "../../modules/s3"
    infra-basic-settings = var.infra-basic-settings
}

module "iam" {
    source = "../../modules/iam"
    infra-basic-settings = var.infra-basic-settings
    s3-public-bucket-arn = module.s3.public_bucket_arn 
}