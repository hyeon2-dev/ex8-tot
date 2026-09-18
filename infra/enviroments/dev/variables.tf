variable "owner" {
    description     = "사용자 계정명"
    type            = string
    default         = "std19"
}

variable "vpc_cidr" {
    description     = "VPC CIDR"
    type            = string
    default         = "10.0.0.0/16"
}

