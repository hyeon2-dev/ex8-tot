# 리전 정보
data "aws_region" current {}
# 현재 리전의 가용영역을 문자열 형태의 리스트로 반환
data "aws_availability_zones" "available_az" {
    state           = "available"
}
