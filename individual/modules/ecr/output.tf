output "aws_ecr_repository_main_repository_url" {
  value = aws_ecr_repository.app.repository_url
}
output "aws_ecr_repository_web_repository_url" {
  value = aws_ecr_repository.web.repository_url
}
output "ecr_app_push_complete" {
  value = null_resource.app.id
}
output "ecr_web_push_complete" {
  value = null_resource.web.id
}