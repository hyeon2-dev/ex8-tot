resource "aws_ecr_repository" "std19_ex8_nginx" {
  name      = "${local.tag_header}nginx"

  # 같은 이미지 태그 덮어쓰기 방지
  image_tag_mutability = "IMMUTABLE"

  # 이미지가 들어 있으면 저장소 강제 삭제 방지
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${local.tag_header}nginx"
  }
}

resource "aws_ecr_repository" "std19_ex8_fastapi" {
  name      = "${local.tag_header}fastapi"

  # 같은 이미지 태그 덮어쓰기 방지
  image_tag_mutability = "IMMUTABLE"

  # 이미지가 들어 있으면 저장소 강제 삭제 방지
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${local.tag_header}fastapi"
  }
}