variable "owner" {
    description     = "사용자 계정명"
    type            = string
    default         = ""
}

variable "vpc_cidr" {
    description     = "VPC CIDR"
    type            = string
    default         = ""
}

variable "tag_header" {
    description     = "태그 헤더값"
    type            = string
    default         = ""
}

variable "az_names" {
    description     = "가용영역 이름"
    type            = list(string)
    default         = []
}

variable "subnet_map" {
  type = map(object({
    type = string
    az   = string
    cidr = string
  }))
}

variable "region" {
  type = string
}
