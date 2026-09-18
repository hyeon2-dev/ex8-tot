output "repository_nginx_url" {
  value = aws_ecr_repository.std19_ex8_nginx.repository_url
}

output "repository_fastapi_url" {
  value = aws_ecr_repository.std19_ex8_fastapi.repository_url
}