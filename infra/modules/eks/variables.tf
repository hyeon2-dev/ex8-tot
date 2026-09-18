variable "vpc_id" {
  type  = string
}

variable "tag_header" {
  type  = string
}

variable "cluster_subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = object({
    ssh_sg          = string
    internal_alb_sg = string
    external_alb_sg = string
  })
}

variable "region" {
  type = string
}
