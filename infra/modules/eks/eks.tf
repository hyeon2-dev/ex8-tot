# ===================================================================================
# EKS 구축 프로세스
# 네트워크 구성 => IAM권한설정 => EKS 클러스터 구성 => 노드 그룹 정의 => 액세스 환경 정의
# ===================================================================================
# 서브넷 공통:      "kubernetes.io/cluster/<EKS이름>" = "shared"
# 퍼블릭 서브넷:    "kubernetes.io/role/elb" = "1"
# 프라이빗 서브넷:  "kubernetes.io/role/internal-elb" = "1"
# ===================================================================================
 
# ===================================================================================
# 1. EKS 및 워커노드를 위한 보안 그룹 생성
# ===================================================================================
# 노드와 컨트롤 플레인(k8s master)간 통신을 위한 포트: 10250/tcp
# 노드간 통신 모두 열어줌
resource "aws_security_group" "std19_ex8_k8s_sg" {
    name        = "${local.tag_header}k8s-sg"
    description = "Security group for eks access"
    vpc_id      = local.vpc_id

    # 같은 보안 그룹을 사용하는 리소스 사이의 모든 통신 허용
    # TCP 10250도 포함됨
    ingress {
        description = "Allow communication between worker nodes"  # 워커노드간 통신을 위한 보안 규칙
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        self        = true  # 이 보안 그룹이 붙은 리소스끼리 통신을 허용
    }

    ingress {
        from_port   = 10250
        to_port     = 10250
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}k8s-sg"
    }
}

# ===================================================================================
# 2. k8s master 및 워커 노드용 역할 및 정책 생성
# ===================================================================================
# 클러스터(k8s)용 역할(role) 생성
resource "aws_iam_role" "std19_ex8_cluster_role" {
  name            = "${local.tag_header}ex8-eks-cluster-role"
  assume_role_policy  =jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action  = "sts:AssumeRole"
        Effect  = "Allow"
        Principal = { Service = "eks.amazonaws.com"}
      }
    ]
  })
}

# 역할에서 사용할 정책 연결
# 정책 연결: 콘솔(IAM-Policy) AmazonEKSClusterPolicy(ARN) 
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn  = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role        = aws_iam_role.std19_ex8_cluster_role.name
}

# ===================================================================================
# 워커노드용 역할 및 정책
resource "aws_iam_role" "std19_ex8_node_role" {
  name            = "${local.tag_header}ex8-eks-node-role"
  assume_role_policy  =jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action  = "sts:AssumeRole"
        Effect  = "Allow"
        Principal = { Service = "ec2.amazonaws.com"}
      }
    ]
  })
}

locals {
  node_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    # ECR 레포지토리 이미지 읽기
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    # SSM: SSH 없이 터미널 접속 가능
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    # Logging: 파드 및 시스템 로그 전송
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    # S3: 설정 파일이나 이미지 읽기 (필요 시 수정)
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  ]
}

resource "aws_iam_role_policy_attachment" "node_policy" {
  for_each    = toset(local.node_policies)
  policy_arn  = each.value
  role        = aws_iam_role.std19_ex8_node_role.name
}

# ===================================================================================
# 3. EKS Cluster 리소스 생성
# ===================================================================================
resource "aws_eks_cluster" "std19_ex8_k8s" {
  name          = "${local.tag_header}ex8-eks-cluster"

  # 클러스터 역할
  role_arn      = aws_iam_role.std19_ex8_cluster_role.arn

  # 네트워크 설정
  vpc_config {
    subnet_ids  = local.cluster_subnet_ids
  }

  # 사용자 연결 설정
  access_config {
    # EKS 클러스터가 사용자나 역할을 어떤 방식으로 인식하게 할지 지정
    # API_AND_CONFIG_MAP / ConfigMap
    authentication_mode   = "API_AND_CONFIG_MAP"

    # 생성자에게 자동으로 관리자 권한을 부여
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [ aws_iam_role_policy_attachment.cluster_policy ]

}

# ===================================================================================
# 4. 노드 그룹 구성
# ===================================================================================
data "aws_ami" "eks_al2023_latest" {
  most_recent = true
  owners      = ["602401143452"] # Amazon EKS 공식 계정

  filter {
    name   = "name"
    # 'standard'를 명시하는 대신 와일드카드를 써서 1.35 버전의 x86_64 이미지를 찾습니다.
    values = ["amazon-eks-node-al2023-x86_64-standard-1.35-v*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
resource "aws_launch_template" "std19_ex8_launch_template" {
  # 생성될 인스턴스들에 부여할 이름의 접두사
  name_prefix             = "${local.tag_header}k8s-node-"
  # image_id 대신 ami_type = "AL2023_x86_64_STANDARD" 를 사용할 경우 user data를 제외
  image_id                = data.aws_ami.eks_al2023_latest.id
  instance_type           = "t3.small"
  key_name                = "std19-key"
  vpc_security_group_ids  = [
    aws_security_group.std19_ex8_k8s_sg.id,
    local.security_group_ids.ssh_sg,
    local.security_group_ids.internal_alb_sg,
    aws_eks_cluster.std19_ex8_k8s.vpc_config[0].cluster_security_group_id
  ]

  update_default_version  = true
  user_data = base64encode(<<-EOT
    ---
    apiVersion: node.eks.aws/v1alpha1
    kind: NodeConfig
    spec:
      cluster:
        name: ${aws_eks_cluster.std19_ex8_k8s.name}
        apiServerEndpoint: ${aws_eks_cluster.std19_ex8_k8s.endpoint}
        certificateAuthority: ${aws_eks_cluster.std19_ex8_k8s.certificate_authority[0].data}
        cidr: ${aws_eks_cluster.std19_ex8_k8s.kubernetes_network_config[0].service_ipv4_cidr}
  EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.tag_header}k8s-node" }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = "${local.tag_header}k8s-volume" }
  }
}

# 노드 그룹 생성: subnet_ids  = data.aws_subnets.std19_cluster_subnets.ids
resource "aws_eks_node_group" "std19_ex8_eks_node_group" {
  node_group_name = "${local.tag_header}eks-node-group"
  cluster_name    = aws_eks_cluster.std19_ex8_k8s.name

  node_role_arn = aws_iam_role.std19_ex8_node_role.arn
  subnet_ids  = local.cluster_subnet_ids

  scaling_config {
    desired_size  = 2
    max_size      = 3
    min_size      = 1
  }

  launch_template {
    name    = aws_launch_template.std19_ex8_launch_template.name
    version = aws_launch_template.std19_ex8_launch_template.latest_version  # 삭제 / version = $Default
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_policy
  ]

}

# ===================================================================================
# [추가] 사용자 연결
# ===================================================================================
resource "null_resource" "update_kubeconfig" {
  depends_on = [ aws_eks_node_group.std19_ex8_eks_node_group ]
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${local.region} --name ${aws_eks_cluster.std19_ex8_k8s.name}"
  }
}

# ===================================================================================
# 5. 사용자 등록
# ===================================================================================
resource "aws_eks_access_entry" "bipa17-student19" {
  cluster_name      = aws_eks_cluster.std19_ex8_k8s.name
  # 등록할 사용자의 계정 ARN
  principal_arn     = "arn:aws:iam::925047940866:user/bipa17-student19"

  # 아래와 같이 지정하고 사용자 계정을 IAM에서 역할 부여
  kubernetes_groups = ["master"]
  type              = "STANDARD"
}

resource "aws_eks_access_policy_association" "bipa17_student19_admin" {
  cluster_name      = aws_eks_cluster.std19_ex8_k8s.name
  policy_arn        = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn     = aws_eks_access_entry.bipa17-student19.principal_arn

  access_scope {
    type = "cluster"  # 적용범위: 클러스터 전체
  }

  depends_on = [ aws_eks_access_entry.bipa17-student19 ]
}


