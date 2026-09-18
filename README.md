# Board GitOps on AWS EKS

Terraform으로 AWS 인프라를 구성하고, GitHub Actions로 Docker 이미지를 Amazon ECR에 업로드한 뒤, Argo CD를 통해 Amazon EKS에 자동 배포하는 GitOps 프로젝트입니다.

---

## 1. 프로젝트 목표

이 프로젝트는 다음 과정을 코드와 자동화 파일로 관리하는 것을 목표로 합니다.

```text
Terraform
  ↓
VPC / ECR / EKS 생성
  ↓
AWS Load Balancer Controller 설치
  ↓
GitHub Actions
  ↓
Docker Image Build
  ↓
Amazon ECR Push
  ↓
Kubernetes Manifest Image Tag 변경
  ↓
Git Push
  ↓
Argo CD
  ↓
Amazon EKS 자동 배포
  ↓
Ingress / ALB
```

저장소를 받은 사용자는 아래 설치 순서와 환경별 설정값을 준비한 뒤 동일한 구조를 재현할 수 있습니다.

> 주의: AWS 계정 ID, IAM ARN, ACM 인증서 ARN, GitHub 저장소 주소 등 일부 값은 환경별로 다르므로 자신의 환경에 맞게 설정해야 합니다.

---

## 2. 프로젝트 구조

```text
ex8-tot/
├── .github/
│   └── workflows/
│       ├── terraform.yaml
│       └── board-deploy.yaml
│
├── app/
│   └── board/
│       ├── frontend/
│       ├── backend/
│       └── board-docker-compose.yaml
│
├── infra/
│   ├── bootstrap/
│   │   ├── main.tf
│   │   └── provider.tf
│   │
│   ├── enviroments/
│   │   └── dev/
│   │       ├── main.tf
│   │       ├── data.tf
│   │       ├── local.tf
│   │       ├── terraform.tf
│   │       ├── variables.tf
│   │       └── terraform.tfvars
│   │
│   └── modules/
│       ├── network/
│       ├── eks/
│       └── ecr/
│
├── k8s/
│   ├── frontend.yaml
│   ├── backend.yaml
│   └── ingress.yaml
│
├── scripts/
│   ├── install-controller.sh
│   └── install-argocd.sh
│
├── gitops/
│   └── board-application.yaml
│
├── .gitignore
└── README.md
```

`terraform.tfvars`는 실제 환경값을 포함할 수 있으므로 Git에 커밋하지 않습니다.

---

## 3. 주요 구성 요소

### Terraform

Terraform은 AWS 인프라를 생성하고 관리합니다.

주요 생성 대상:

- VPC
- Public / Private / Cluster Subnet
- Internet Gateway
- NAT Gateway
- Route Table
- Security Group
- VPC Endpoint
- Amazon ECR
- Amazon EKS
- EKS Node Group
- IAM Role / Policy

Terraform 코드는 재사용성을 위해 `network`, `eks`, `ecr` 모듈로 분리되어 있습니다.

### Terraform Backend

Terraform State는 S3 Remote Backend를 사용합니다.

Bootstrap 단계에서 다음 리소스를 먼저 생성합니다.

- S3 Bucket: Terraform State 저장
- DynamoDB Table: State Lock

구조:

```text
infra/bootstrap
  ↓
State용 S3 / DynamoDB 생성

infra/enviroments/dev
  ↓
S3 Remote Backend 사용
  ↓
VPC / ECR / EKS 관리
```

Bootstrap State와 Dev State는 서로 분리해서 관리해야 합니다.

---

## 4. 사전 준비

다음 도구가 필요합니다.

- Git
- AWS CLI
- Terraform
- kubectl
- Helm
- eksctl
- Docker

설치 확인:

```bash
git --version
aws --version
terraform version
kubectl version --client
helm version
eksctl version
docker --version
```

AWS CLI 인증도 완료되어 있어야 합니다.

```bash
aws sts get-caller-identity
```

---

## 5. 저장소 Clone

```bash
git clone <YOUR_GITHUB_REPOSITORY_URL>
cd ex8-tot
```

---

## 6. 환경별 설정값

다른 AWS 계정이나 환경에서 실행할 경우 다음 값을 확인하거나 수정해야 합니다.

### Terraform 변수

`infra/enviroments/dev/terraform.tfvars`

예시:

```hcl
owner = "std19"
vpc_cidr = "10.0.0.0/16"

eks_admin_principal_arn = "arn:aws:iam::<ACCOUNT_ID>:user/<IAM_USER_NAME>"
```

`terraform.tfvars`는 `.gitignore`에 포함되어 GitHub에 업로드하지 않습니다.

### 현재 코드에서 환경별 확인이 필요한 값

- AWS Account ID
- AWS Region
- EKS Cluster Name
- ECR Repository Name
- IAM Principal ARN
- EC2 Key Pair 이름
- ACM Certificate ARN
- GitHub Repository URL

특히 `k8s/ingress.yaml`의 ACM 인증서 ARN은 자신의 AWS 환경에 맞게 변경해야 합니다.

---

## 7. Bootstrap 실행

Terraform Remote State 저장소를 먼저 생성합니다.

```bash
cd infra/bootstrap

terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

Bootstrap에서는 다음 리소스를 생성합니다.

```text
S3 Bucket
  └── Terraform State 저장

DynamoDB Table
  └── Terraform State Lock
```

Bootstrap은 최초 환경 구성 시 실행합니다.

---

## 8. GitHub Actions Secrets 설정

GitHub Repository에서 다음 경로로 이동합니다.

```text
Settings
→ Secrets and variables
→ Actions
```

다음 Repository Secrets를 등록합니다.

### AWS_ACCESS_KEY

AWS Access Key

### AWS_SECRET_ACCESS_KEY

AWS Secret Access Key

### AWS_REGION

예:

```text
us-west-2
```

### TF_VARS_DEV

`terraform.tfvars`에 들어갈 내용을 Secret으로 등록합니다.

예:

```hcl
owner = "std19"
vpc_cidr = "10.0.0.0/16"
eks_admin_principal_arn = "arn:aws:iam::<ACCOUNT_ID>:user/<IAM_USER_NAME>"
```

GitHub Actions 실행 시 이 값을 사용해 임시 `terraform.tfvars` 파일을 생성합니다.

---

## 9. Terraform Infrastructure Pipeline

워크플로우:

```text
.github/workflows/terraform.yaml
```

다음 파일이 변경되면 실행됩니다.

```text
infra/**
scripts/install-controller.sh
.github/workflows/terraform.yaml
```

실행 과정:

```text
Checkout
  ↓
AWS 인증
  ↓
Terraform 설치
  ↓
terraform.tfvars 생성
  ↓
terraform init
  ↓
terraform validate
  ↓
terraform plan
  ↓
terraform apply
  ↓
kubectl 설치
  ↓
Helm 설치
  ↓
eksctl 설치
  ↓
AWS Load Balancer Controller 설치
```

수동으로 실행하려면 GitHub Actions의 `workflow_dispatch`를 사용할 수 있습니다.

---

## 10. AWS Load Balancer Controller

설치 스크립트:

```text
scripts/install-controller.sh
```

이 스크립트는 다음 작업을 수행합니다.

```text
EKS Cluster 확인
  ↓
kubeconfig 설정
  ↓
OIDC Provider 확인 / 생성
  ↓
Load Balancer Controller IAM Policy 확인 / 생성
  ↓
IAM Role + ServiceAccount 확인 / 생성
  ↓
Helm Repository 설정
  ↓
AWS Load Balancer Controller 설치
```

이미 존재하는 리소스는 확인 후 중복 생성을 피하도록 구성합니다.

설치 확인:

```bash
kubectl get deployment aws-load-balancer-controller -n kube-system
```

Pod 확인:

```bash
kubectl get pods \
  -n kube-system \
  -l app.kubernetes.io/name=aws-load-balancer-controller
```

정상적인 경우 Pod 상태가 `Running`이어야 합니다.

---

## 11. Kubernetes Manifest

Kubernetes 배포 파일은 `k8s/` 디렉터리에 있습니다.

```text
k8s/
├── frontend.yaml
├── backend.yaml
└── ingress.yaml
```

구성:

```text
Ingress / AWS ALB
        ↓
Frontend Service
        ↓
Frontend Nginx
        ↓
Backend Service
        ↓
FastAPI
```

Argo CD를 연결하기 전 수동 테스트가 필요한 경우:

```bash
kubectl apply -f k8s/
```

확인:

```bash
kubectl get deploy
kubectl get pods
kubectl get svc
kubectl get ingress
```

Ingress 상세 확인:

```bash
kubectl describe ingress
```

---

## 12. Argo CD 설치

Argo CD 설치 스크립트:

```text
scripts/install-argocd.sh
```

실행:

```bash
chmod +x scripts/install-argocd.sh
./scripts/install-argocd.sh
```

설치 확인:

```bash
kubectl get pods -n argocd
```

주요 Argo CD Pod가 `Running` 상태인지 확인합니다.

---

## 13. Argo CD Application 등록

Application 설정:

```text
gitops/board-application.yaml
```

Application은 다음 정보를 정의합니다.

```text
Git Repository
  ↓
main branch
  ↓
k8s/
  ↓
Argo CD
  ↓
현재 EKS Cluster
  ↓
default namespace
```

`repoURL`을 자신의 GitHub Repository URL로 변경합니다.

예:

```yaml
source:
  repoURL: <YOUR_GITHUB_REPOSITORY_URL>
  targetRevision: main
  path: k8s
```

Application 적용:

```bash
kubectl apply -f gitops/board-application.yaml
```

확인:

```bash
kubectl get applications -n argocd
```

정상 상태:

```text
Synced
Healthy
```

### Private Repository

GitHub Repository가 Private인 경우 Argo CD에 별도의 Repository 인증 정보를 등록해야 합니다.

Public Repository는 Repository URL만으로 읽을 수 있습니다.

---

## 14. Argo CD Web UI 접속

Argo CD Server 확인:

```bash
kubectl get svc -n argocd
```

Port Forward:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

브라우저 접속:

```text
https://localhost:8080
```

기본 사용자:

```text
admin
```

초기 비밀번호 확인:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

echo
```

---

## 15. Application CI/CD Pipeline

워크플로우:

```text
.github/workflows/board-deploy.yaml
```

`app/board/**`가 변경되면 실행됩니다.

실행 과정:

```text
Frontend / Backend 코드 변경
        ↓
Git Push
        ↓
GitHub Actions
        ↓
Docker Image Build
        ↓
Amazon ECR Push
        ↓
k8s/frontend.yaml Image Tag 변경
k8s/backend.yaml Image Tag 변경
        ↓
Git Commit / Push
        ↓
Argo CD 변경 감지
        ↓
Amazon EKS 자동 Sync
```

이미지 태그에는 GitHub Commit SHA를 사용합니다.

```text
<repository>:<github.sha>
```

이를 통해 어떤 Git Commit으로 생성된 Docker Image인지 추적할 수 있습니다.

---

## 16. GitOps 동작 확인

애플리케이션 코드를 변경합니다.

예:

```text
app/board/backend/
```

또는:

```text
app/board/frontend/
```

Commit 후 Push:

```bash
git add .
git commit -m "test: gitops deployment"
git push origin main
```

확인 순서:

### GitHub Actions

```text
Actions
→ Board ECR GitOps Pipeline
```

Workflow 성공 여부를 확인합니다.

### ECR

새로운 GitHub SHA Tag를 가진 이미지가 생성되었는지 확인합니다.

### Git

다음 파일의 Image Tag가 변경되었는지 확인합니다.

```text
k8s/frontend.yaml
k8s/backend.yaml
```

### Argo CD

```bash
kubectl get applications -n argocd
```

정상:

```text
Synced
Healthy
```

### Kubernetes

```bash
kubectl get pods
kubectl get deploy
kubectl get svc
kubectl get ingress
```

새로운 Pod가 정상적으로 `Running` 상태인지 확인합니다.

---

## 17. 전체 CI/CD 흐름

```text
┌──────────────────────┐
│     Developer        │
└──────────┬───────────┘
           │
           │ git push
           ▼
┌──────────────────────┐
│       GitHub         │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│   GitHub Actions     │
│                      │
│ Docker Image Build   │
│ ECR Push             │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│      Amazon ECR      │
└──────────────────────┘

GitHub Actions
     │
     │ Kubernetes Image Tag 변경
     ▼
┌──────────────────────┐
│      Git k8s/        │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│       Argo CD        │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│      Amazon EKS      │
│                      │
│ Frontend / Backend   │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ AWS Load Balancer    │
│ Controller           │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│        ALB           │
└──────────────────────┘
```

---

## 18. Terraform 상태 확인

Dev 인프라:

```bash
cd infra/enviroments/dev

terraform init
terraform validate
terraform plan
```

정상적인 경우 이미 배포된 인프라와 코드가 같다면:

```text
No changes. Your infrastructure matches the configuration.
```

에 가까운 결과가 표시됩니다.

State 확인:

```bash
terraform state list
```

Dev State에는 다음 계열이 존재합니다.

```text
module.network.*
module.ecr.*
module.eks.*
```

Bootstrap 리소스는 Dev State와 분리하여 관리합니다.

---

## 19. 문제 해결

### ECR RepositoryAlreadyExistsException

AWS에 ECR Repository가 존재하지만 Terraform State에서 관리하지 않을 때 발생할 수 있습니다.

기존 리소스를 바로 삭제하지 말고 먼저 Terraform State가 올바른 Backend를 보고 있는지 확인합니다.

```bash
terraform state list
```

### IAM EntityAlreadyExists

IAM Role이 AWS에는 존재하지만 Terraform State에 없을 때 발생할 수 있습니다.

Terraform State와 실제 AWS 리소스의 일치 여부를 먼저 확인해야 합니다.

### Ingress가 생성되지 않는 경우

```bash
kubectl get ingress
kubectl describe ingress
```

AWS Load Balancer Controller 상태 확인:

```bash
kubectl get deployment aws-load-balancer-controller -n kube-system
```

### Pod가 실행되지 않는 경우

```bash
kubectl get pods
kubectl describe pod <POD_NAME>
kubectl logs <POD_NAME>
```

### Argo CD가 OutOfSync인 경우

```bash
kubectl describe application board -n argocd
```

Git의 `k8s/` 상태와 실제 Kubernetes 상태를 비교합니다.

---

## 20. 리소스 삭제

애플리케이션 리소스 삭제:

```bash
kubectl delete -f gitops/board-application.yaml
```

필요한 경우 Argo CD 삭제:

```bash
kubectl delete namespace argocd
```

Dev Terraform 인프라 삭제:

```bash
cd infra/enviroments/dev

terraform init
terraform plan -destroy
terraform destroy
```

Bootstrap S3 Bucket에는 `prevent_destroy = true`가 설정되어 있으므로 실수로 State 저장소가 삭제되지 않도록 보호합니다.

Bootstrap 리소스는 Dev 인프라보다 마지막에 정리해야 합니다.

> Terraform State가 저장된 S3 Bucket을 먼저 삭제하면 이후 리소스 관리가 어려워질 수 있으므로 삭제 순서를 반드시 지켜야 합니다.

---

## 21. 주의사항

- `.terraform/`은 Git에 커밋하지 않습니다.
- `*.tfstate`, `*.tfstate.*`는 Git에 커밋하지 않습니다.
- `terraform.tfvars`는 Git에 커밋하지 않습니다.
- AWS Access Key / Secret Key는 코드에 직접 작성하지 않습니다.
- `.terraform.lock.hcl`은 Terraform Provider 버전 재현을 위해 커밋합니다.
- Terraform Bootstrap State와 Dev State를 같은 Backend Key로 관리하지 않습니다.
- 실제 리소스가 이미 존재하는 경우 임의로 삭제하기 전에 Terraform State를 먼저 확인합니다.
- ACM 인증서 ARN, AWS Account ID, IAM ARN 등 환경별 값은 실행 환경에 맞게 변경합니다.

---

## 22. 현재 자동화 범위

현재 프로젝트에서 자동화되는 범위:

```text
Terraform Infrastructure
        ↓
GitHub Actions
        ↓
AWS Load Balancer Controller
```

애플리케이션 변경 시:

```text
Source Code Push
        ↓
GitHub Actions
        ↓
Docker Build
        ↓
ECR Push
        ↓
Kubernetes Manifest Update
        ↓
Argo CD
        ↓
EKS Deployment
```

최초 Bootstrap과 Argo CD 설치/Application 등록은 환경 구성 시 한 번 수행합니다.

---

## 23. 정리

이 프로젝트는 인프라 구성부터 애플리케이션 배포까지 다음 기술을 연결합니다.

- Terraform
- AWS VPC
- Amazon ECR
- Amazon EKS
- AWS Load Balancer Controller
- Docker
- Kubernetes
- GitHub Actions
- Argo CD
- GitOps

Terraform으로 인프라를 코드화하고 GitHub Actions와 Argo CD를 통해 애플리케이션 변경 사항이 EKS까지 자동 반영되는 CI/CD 및 GitOps 환경을 구성했습니다.
