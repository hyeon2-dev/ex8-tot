locals {
    vpc_id              = var.vpc_id
    tag_header          = var.tag_header
    cluster_subnet_ids  = var.cluster_subnet_ids
    security_group_ids  = var.security_group_ids
    region              = var.region
    eks_admin_principal_arn     = var.eks_admin_principal_arn
}