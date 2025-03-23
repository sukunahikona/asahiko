data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}


resource "aws_ecr_repository" "main" {
  name                 = var.ecr-name
  image_tag_mutability = "MUTABLE"
  # imageが残ってても強制的にリポジトリ削除
  force_delete         = true
  image_scanning_configuration {
    scan_on_push = true
  }
}
resource "null_resource" "main" {
  triggers = {
    // MD5 チェックし、トリガーにする
    file_content_md5 = md5(file("${path.module}/dockerbuild.sh"))
  }

  provisioner "local-exec" {
    // ローカルのスクリプトを呼び出す
    command = "sh ${path.module}/dockerbuild.sh"

    // スクリプト専用の環境変数
    environment = {
      AWS_REGION       = var.aws-region
      AWS_ACCOUNT_ID   = local.account_id
      REPO_URL         = aws_ecr_repository.main.repository_url
      CONTAINER_NAME   = var.container-name
      DOCKER_FILE_PATH = "${path.module}/${var.app-name}"
    }
  }
}

resource "aws_ecr_repository" "web" {
  name                 = "${var.ecr-name}-web"
  image_tag_mutability = "MUTABLE"
  # imageが残ってても強制的にリポジトリ削除
  force_delete         = true
  image_scanning_configuration {
    scan_on_push = true
  }
}
resource "null_resource" "web" {
  triggers = {
    // MD5 チェックし、トリガーにする
    file_content_md5 = md5(file("${path.module}/dockerbuild.sh"))
  }

  provisioner "local-exec" {
    // ローカルのスクリプトを呼び出す
    command = "sh ${path.module}/dockerbuild.sh"

    // スクリプト専用の環境変数
    environment = {
      AWS_REGION       = var.aws-region
      AWS_ACCOUNT_ID   = local.account_id
      REPO_URL         = aws_ecr_repository.web.repository_url
      CONTAINER_NAME   = "${var.container-name}-web"
      DOCKER_FILE_PATH = "${path.module}/${var.app-name}/nginx"
    }
  }
}