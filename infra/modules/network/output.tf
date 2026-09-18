output "vpc_id" {
  value = aws_vpc.this.id
}

output "security_group_ids" {
  value = {
    ssh_sg           = aws_security_group.std19_ex8_ssh_sg.id
    internal_alb_sg  = aws_security_group.std19_ex8_internal_alb_sg.id
    external_alb_sg  = aws_security_group.std19_ex8_external_alb_sg.id
  }
}

output "private_subnet_ids" {
  value = {
    for key, subnet in aws_subnet.std19_ex8_private_subnet :
    key => subnet.id
  }
}

output "public_subnet_ids" {
  value = {
    for key, subnet in aws_subnet.std19_ex8_public_subnet :
    key => subnet.id
  }
}

output "cluster_subnet_ids" {
  value = {
    for key, subnet in aws_subnet.std19_ex8_cluster_subnet :
    key => subnet.id
  }
}