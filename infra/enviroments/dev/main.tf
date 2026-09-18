# 사용할 모듈블럭 정의
module "network" {
    source      = "../../modules/network"
    # # 다른 리전을 사용하고자 할 경우, provider.tf에서 provider {}가 미리 정의되어 있어야함
    # providers   = { aws = aws.seoul }

    # <모듈 변수명> = <모듈로 넘겨줄 값 | var.변수명 | local.변수명>
    az_names        = local.az_names
    owner           = local.owner
    vpc_cidr        = local.vpc_cidr
    tag_header      = local.tag_header
    subnet_map      = local.subnet_map
    region          = local.region
    eks_admin_principal_arn   = local.eks_admin_principal_arn
}

module "eks" {
    source              = "../../modules/eks"

    vpc_id              = module.network.vpc_id
    cluster_subnet_ids  = values(module.network.cluster_subnet_ids)
    tag_header          = local.tag_header
    security_group_ids  = module.network.security_group_ids
    region              = local.region

}

module "ecr" {
    source              = "../../modules/ecr"

    tag_header      = local.tag_header
    
}
