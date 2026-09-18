# <변수명> = <모듈명.아웃풋이름>
locals {
    # ["us-west-2", ...]
    az_names    = slice(data.aws_availability_zones.available_az.names, 0, 3)
    owner       = var.owner
    vpc_cidr    = var.vpc_cidr
    tag_header  = var.owner == "" ? "" : "${local.owner}-ex8-"
    cidr_header = "${split(".", var.vpc_cidr)[0]}.${split(".", var.vpc_cidr)[1]}"
    subnet_map  = merge([
        for idx, key in ["public", "private", "cluster"] : {   # idx: 순서, key: public,priavte
            for i, az_name in local.az_names : "${key}${split("-", az_name)[2]}" => {   # i: 순서, az: 가용영역 이름
                type    = key
                az      = az_name
                cidr    = "${local.cidr_header}.${i+(idx*10+1)}.0/24"
            }   
        }
    ]...)
    region                  = data.aws_region.current.region
    eks_admin_principal_arn = var.eks_admin_principal_arn
    # ami_id      = data.aws_ami.ubuntu_24_04.id
}
