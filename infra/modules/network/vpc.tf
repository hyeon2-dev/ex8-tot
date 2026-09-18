# ================================================================
# VPC
# ================================================================
resource "aws_vpc" "this" {
    cidr_block = "10.0.0.0/16"  # 이 네트워크가 사용할 IP 주소 범위
    enable_dns_hostnames = true
    enable_dns_support = true
    instance_tenancy = "default"

    tags = {
        Name = "${local.tag_header}vpc"
    }
}

# ================================================================
# Public Subnet
# ================================================================
resource "aws_subnet" "std19_ex8_public_subnet" {
    # Public 블록의 for_each
    for_each = {
        for key, subnet in local.subnet_map :
        key => subnet if subnet.type == "public"
    }

    vpc_id                  = aws_vpc.this.id
    cidr_block              = each.value.cidr
    availability_zone       = each.value.az
  
    map_public_ip_on_launch = each.value.type == "public" ? true : false
    enable_resource_name_dns_a_record_on_launch = true

    tags = merge({
        "Name" = "${local.tag_header}${each.key}-subnet"
        "Type" = each.value.type
        "kubernetes.io/cluster/${local.tag_header}eks-cluster" = "shared"
        "kubernetes.io/role/elb" = "1" 
    })
}

# ================================================================
# Private Subnet
# ================================================================
resource "aws_subnet" "std19_ex8_private_subnet" {
    for_each = {
        for key, subnet in local.subnet_map :
        key => subnet if subnet.type == "private"
    }

    vpc_id                  = aws_vpc.this.id
    cidr_block              = each.value.cidr
    availability_zone       = each.value.az

    map_public_ip_on_launch = false
    enable_resource_name_dns_a_record_on_launch = true

    tags = merge({
        "Name" = "${local.tag_header}${each.key}-subnet"
        "Type" = each.value.type
    })
}

# ================================================================
# Cluster Subnet
# ================================================================
resource "aws_subnet" "std19_ex8_cluster_subnet" {
    for_each = {
        for key, subnet in local.subnet_map :
        key => subnet if subnet.type == "cluster"
    }

    vpc_id                  = aws_vpc.this.id
    cidr_block              = each.value.cidr
    availability_zone       = each.value.az

    map_public_ip_on_launch = false
    enable_resource_name_dns_a_record_on_launch = true

    tags = merge({
        "Name" = "${local.tag_header}${each.key}-subnet"
        "Type" = each.value.type
        "kubernetes.io/cluster/${local.tag_header}eks-cluster" = "shared"
        "kubernetes.io/role/internal-elb" = "1"
    })
}

# ================================================================
# Gateway 생성
# ================================================================
# Internet Gateway 생성
resource "aws_internet_gateway" "std19_ex8_igw" {
    vpc_id = aws_vpc.this.id

    tags = {
        Name = "${local.tag_header}igw"
    }
}

# NAT Gateway 생성을 위한 EIP 생성
resource "aws_eip" "std19_ex8_nat_eip" {
    domain = "vpc"  # VPC용 EIP 생성, std19_nat_eip의 사용범위를 VPC로 제한

    tags = {
        Name = "${local.tag_header}nat-eip"
    }
}

# NAT Gateway 생성
resource "aws_nat_gateway" "std19_ex8_nat_gw" {
    allocation_id = aws_eip.std19_ex8_nat_eip.id
    # NAT Gateway를 생성할 Public Subnet 지정
    subnet_id     = aws_subnet.std19_ex8_public_subnet["public${split("-", local.az_names[0])[2]}"].id
    # 인터넷 게이트웨이를 먼저 생성(완료)되면 이후 NAT Gateway를 생성하도록 의존성 설정
    depends_on =   [
        aws_internet_gateway.std19_ex8_igw
    ]
    tags = {
        Name = "${local.tag_header}nat-gw"
    }
}

# ================================================================
# Route Table 생성
# ================================================================
# Public Route Table생성 -----------------------------------
resource "aws_route_table" "std19_ex8_public_rt" {
    vpc_id = aws_vpc.this.id

    route {
        cidr_block = "0.0.0.0/0"    # 모든 목적지(인터넷)로 가는 트레픽은
        gateway_id = aws_internet_gateway.std19_ex8_igw.id
    }

    tags = {
        Name = "${local.tag_header}public-rt"
    }
}

# 2. 서브넷 연결
resource "aws_route_table_association" "std19_public_rt_assoc" {
    for_each        	= aws_subnet.std19_ex8_public_subnet

    subnet_id           = each.value.id
    route_table_id      = aws_route_table.std19_ex8_public_rt.id
}

# Private Route Table생성 (2a, 2b, 2c)--------------------------------
resource "aws_route_table" "std19_ex8_private_rt" {
    for_each    = toset(local.az_names)
    vpc_id      = aws_vpc.this.id

    route{
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_nat_gateway.std19_ex8_nat_gw.id
    }

    tags = {
        Name = "${local.tag_header}private${split("-", each.key)[2]}-rt"
    }
}

# 2. 서브넷 연결
resource "aws_route_table_association" "std19_ex8_private_rt_assoc" {
    for_each    		= aws_subnet.std19_ex8_private_subnet
    subnet_id           = each.value.id
    route_table_id      = aws_route_table.std19_ex8_private_rt[each.value.availability_zone].id
}

# Cluster Route Table생성 -------------------------------------------
resource "aws_route_table" "std19_ex8_cluster_rt" {
    vpc_id = aws_vpc.this.id

    route{
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_nat_gateway.std19_ex8_nat_gw.id
    }

    tags = {
        Name = "${local.tag_header}cluster-rt"
    }
}

# 2. 서브넷 연결
resource "aws_route_table_association" "std19_ex8_cluster_rt_assoc" {
    for_each    		= aws_subnet.std19_ex8_cluster_subnet
    subnet_id           = each.value.id
    route_table_id      = aws_route_table.std19_ex8_cluster_rt.id
}

# =================================================================================
# Security Group 생성
# =================================================================================
# SSH 접속용 Security Group 생성
resource "aws_security_group" "std19_ex8_ssh_sg" {
    name        = "${local.tag_header}ssh-sg"
    description = "Security group for SSH access"
    vpc_id      = aws_vpc.this.id

    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"  # 모든 프로토콜 허용
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "internal-ssh-sg"
    }
}

# 웹 보안그룹(ALB용) 생성
resource "aws_security_group" "std19_ex8_external_alb_sg" {
    name        = "${local.tag_header}external-alb-sg"
    description = "Security group for web access"
    vpc_id      = aws_vpc.this.id

    
    dynamic "ingress" {
        for_each = [80, 443, 8000]
        content {
        from_port   = ingress.value
        to_port     = ingress.value
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        }
    }    

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"  # 모든 프로토콜 허용
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "external-alb-sg"
    }
}

resource "aws_security_group" "std19_ex8_internal_alb_sg" {
    name        = "${local.tag_header}internal-web-sg"
    description = "Security group for private web access"
    vpc_id      = aws_vpc.this.id

    dynamic "ingress" {
        for_each = [80, 443]
        content {
            from_port   = ingress.value
            to_port     = ingress.value
            protocol    = "tcp"
            security_groups = [ aws_security_group.std19_ex8_external_alb_sg.id ]
        }
    }    

    ingress {
        from_port   = 8000
        to_port     = 8000
        protocol    = "tcp"
        cidr_blocks = [ aws_vpc.this.cidr_block ]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"  # 모든 프로토콜 허용
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    tags = {
        Name = "internal-alb-sg"
    }
}

# MYSQL 접속용 Security Group 생성
resource "aws_security_group" "std19_ex8_mysql_sg" {
    name        = "${local.tag_header}mysql-sg"
    description = "Security group for MYSQL access"
    vpc_id      = aws_vpc.this.id

    ingress {
        from_port   = 3306
        to_port     = 3306
        protocol    = "tcp"
        cidr_blocks = [ aws_vpc.this.cidr_block ]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"  # 모든 프로토콜 허용
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "internal-mysql-sg"
    }
}

# EKS 노드에서 ECR Endpoint로 들어오는 TCP 443만 허용하는 보안 그룹
resource "aws_security_group" "std19_ex8_ecr_endpoint_sg" {
    name        = "${local.tag_header}ecr-ep-sg"
    description = "Security group for ECR access"
    vpc_id      = aws_vpc.this.id

    ingress {
        description     = "Allow HTTPS from EKS nodes"
        from_port       = 443
        to_port         = 443
        protocol        = "tcp"
        cidr_blocks = [
            for subnet in aws_subnet.std19_ex8_cluster_subnet :
            subnet.cidr_block
        ]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"  # 모든 프로토콜 허용
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}ecr-cp-sg"
    }
}

