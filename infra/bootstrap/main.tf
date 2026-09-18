# ========================================================================
# 2. 상태 파일 저장(공유)을 위한 버킷 생성 및 버전 활성화
# ========================================================================
# S3 bucket 생성
resource "aws_s3_bucket" "std19_board_state_bucket" {
  bucket  = "std19-board-state-bucket"

	lifecycle {
		prevent_destroy = true	# 실수로 삭제되는 것을 방지
	}
}

# Bucket 버전 관리 활성화 (상태 복구용)
resource "aws_s3_bucket_versioning" "std19_std19_bucket_versioning" {
	bucket          = aws_s3_bucket.std19_board_state_bucket.id
	versioning_configuration {
		status  = "Enabled"
	}
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.std19_board_state_bucket.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# ========================================================================
# 3. 배포중 락온 설정을 위한 DynamoDB Table 생성
# ========================================================================
resource "aws_dynamodb_table" "terraform_lock" {
	name = "std19-board-state-table"
	# Dynamodb의 관리 방식(비용과 연관된 설정)
	billing_mode = "PROVISIONED"    # PAY_PER_REQUEST
	hash_key = "LockID"     # 1

	read_capacity = 20      # 초당 4KB 데이터 읽기(RCU) => 1RCU
	write_capacity = 20     # 초당 4KB 데이터 쓰기(WCU) => 1WCU

	attribute {
		name = "LockID"     # 관계형 데이터베이스의 P/K와 같은 역할     1
		type = "S"          # S(String), N(Number), B(Binary)
	}
}