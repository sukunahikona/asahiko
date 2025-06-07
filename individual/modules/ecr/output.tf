output "aws_ecr_repository_main_repository_url" {
  value = aws_ecr_repository.app.repository_url
}
output "aws_ecr_repository_web_repository_url" {
  value = aws_ecr_repository.web.repository_url
}