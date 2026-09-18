# provider.tf
# ========================================================================
# 1. 테라폼 실행 환경 설정 블록
# ========================================================================
terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 6.0"  # 가급적 메인과 버전 일치
        }
    }

    backend "s3" {
		bucket				= "std19-board-state-bucket"	# 테라폼 상태파일을 저장할 버킷 이름
		key					= "TerraformState/ex8-tot/dev/terraform.tfstate"	# 버킷에서 테라폼 상태파일 저장 경로
		region				= "us-west-2"
		dynamodb_table		= "std19-board-state-table"	# 락온 상태를 저장할 DynamoDB Table 이름
		encrypt				= true	# 파일 암호화
	}
}