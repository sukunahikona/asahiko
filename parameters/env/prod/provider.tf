locals {
  name = "terraform"
  region = "ap-northeast-1"
}

provider "aws" {
  region = local.region
}
