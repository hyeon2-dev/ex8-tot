# ===============================================================================================================
# S3 Endpoint 설정: VPC 내에서 S3 서비스에 대한 프라이빗 액세스를 제공하는 Gateway Endpoint 생성
# ===============================================================================================================
# 1. 서비스 데이터 소스 정의(서비스 정의)
data "aws_vpc_endpoint_service" "s3" {
  service             = "s3"
  service_type        = "Gateway"
}

# 2. 엔드포인트 생성 및 연결
resource "aws_vpc_endpoint" "s3_ex8_endpoint" {
  vpc_id              = aws_vpc.this.id
  service_name        = data.aws_vpc_endpoint_service.s3.service_name

  vpc_endpoint_type   = "Gateway"

  
  route_table_ids = concat(
    [
      for rt in aws_route_table.std19_ex8_private_rt : rt.id
    ],
    [
      aws_route_table.std19_ex8_cluster_rt.id
    ]
  )

  tags = { Name = "${local.tag_header}s3-endpoint" }
}

# ===============================================================================================================
# ECR 서비스 사용을 위한 Interface Endpoint
# - ECR API Interface Endpoint:
#   IAM 인증, 이미지 메타데이터 조회, 레포지토리 생성 및 삭제 등 ECR API 제어 명령을 처리
#   com.amazonaws.<region>.ecr.api
# - ECR DKR Interface Endpoint
#   실제 Docker 데몬이 Container Image Layer를 가져오거나(Pull) / 업로드(Push)를 실행
# ===============================================================================================================
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${local.region}.ecr.api"
  vpc_endpoint_type = "Interface"

  subnet_ids  = toset([
    for subnet in aws_subnet.std19_ex8_private_subnet : subnet.id
  ])

  # ECR은 통신포트로 443을 사용
  security_group_ids  = [
    aws_security_group.std19_ex8_ecr_endpoint_sg.id
  ]

  # [필수] ECR의 기본 URL 주소 호환을 위한 필수 옵션
  private_dns_enabled = true

  tags = { Name = "${local.tag_header}ecr-api-vpce"}
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${local.region}.ecr.dkr"
  vpc_endpoint_type = "Interface"

  subnet_ids  = toset([
    for subnet in aws_subnet.std19_ex8_private_subnet : subnet.id
  ])

  # ECR은 통신포트로 443을 사용
  security_group_ids  = [
    aws_security_group.std19_ex8_ecr_endpoint_sg.id
  ]

  # [필수] ECR의 기본 URL 주소 호환을 위한 필수 옵션
  private_dns_enabled = true

  tags = { Name = "${local.tag_header}ecr-dkr-vpce"}

}