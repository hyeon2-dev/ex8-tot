terraform {
	required_providers {    # 어떤 환경에서 사용할 것인가
		aws = {     # 1
			# provider 라이브러리 다운로드 경로
			source = "hashicorp/aws"

			# 사용할 버전 정의
			version = "~> 6.0"  # 5.0 ~ 6.0 (5.0 이상, 6.0 미만의 최신버전)
		}
	}

	backend "s3" {
		bucket						= "std19-board-state-bucket"	# 테라폼 상태파일을 저장할 버킷 이름
		key								= "TerraformState/ex8-tot/dev/terraform.tfstate"	# 버킷에서 테라폼 상태파일 저장 경로
		region						= "us-west-2"
		dynamodb_table		= "std19-board-state-table"	# 락온 상태를 저장할 DynamoDB Table 이름
		encrypt						= true	# 파일 암호화
	}
}

provider "aws" {    # 1
	region = "us-west-2"
}