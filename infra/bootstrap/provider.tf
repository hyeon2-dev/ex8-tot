terraform {
	required_providers {    # 어떤 환경에서 사용할 것인가
		aws = {     # 1
			# provider 라이브러리 다운로드 경로
			source = "hashicorp/aws"

			# 사용할 버전 정의
			version = "~> 6.0"  # 5.0 ~ 6.0 (5.0 이상, 6.0 미만의 최신버전)
		}
	}

}

provider "aws" {    # 1
	region = "us-west-2"
}