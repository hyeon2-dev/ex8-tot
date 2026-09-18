#!/bin/bash

set -e

# =========================================================
# 기본 설정
# =========================================================
CLUSTER_NAME="std19-ex8-eks-cluster"
AWS_REGION="us-west-2"

POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"
ROLE_NAME="AmazonEKSLoadBalancerControllerRole"

SERVICE_ACCOUNT_NAME="aws-load-balancer-controller"
NAMESPACE="kube-system"

CONTROLLER_VERSION="v2.14.1"


# =========================================================
# 1. 현재 AWS 계정 ID 확인
# =========================================================
AWS_ACCOUNT_ID=$(aws sts get-caller-identity \
  --query Account \
  --output text)

echo "AWS Account ID : ${AWS_ACCOUNT_ID}"
echo "EKS Cluster    : ${CLUSTER_NAME}"
echo "AWS Region     : ${AWS_REGION}"


# =========================================================
# 2. EKS 클러스터 존재 확인
# =========================================================
echo "EKS 클러스터 확인 중..."

aws eks describe-cluster \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}" \
  > /dev/null

echo "EKS 클러스터 확인 완료"


# =========================================================
# 3. kubeconfig 설정
# =========================================================
echo "kubeconfig 설정 중..."

aws eks update-kubeconfig \
  --region "${AWS_REGION}" \
  --name "${CLUSTER_NAME}"

echo "kubeconfig 설정 완료"


# =========================================================
# 4. OIDC Provider 확인 및 생성
# =========================================================
echo "OIDC Provider 확인 중..."

OIDC_ID=$(aws eks describe-cluster \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}" \
  --query "cluster.identity.oidc.issuer" \
  --output text | cut -d '/' -f 5)

OIDC_EXISTS=$(aws iam list-open-id-connect-providers \
  --query "OpenIDConnectProviderList[].Arn" \
  --output text | grep "${OIDC_ID}" || true)

if [ -z "${OIDC_EXISTS}" ]; then

  echo "OIDC Provider가 없습니다."
  echo "OIDC Provider를 생성합니다."

  eksctl utils associate-iam-oidc-provider \
    --cluster "${CLUSTER_NAME}" \
    --region "${AWS_REGION}" \
    --approve

else

  echo "OIDC Provider가 이미 존재합니다."
  echo "${OIDC_EXISTS}"

fi


# =========================================================
# 5. Load Balancer Controller IAM Policy 확인 및 생성
# =========================================================
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"

echo "IAM Policy 확인 중..."

if aws iam get-policy \
    --policy-arn "${POLICY_ARN}" \
    > /dev/null 2>&1; then

  echo "${POLICY_NAME} 정책이 이미 존재합니다."

else

  echo "${POLICY_NAME} 정책이 없습니다."
  echo "IAM Policy 파일을 다운로드합니다."

  curl -Lo /tmp/aws-load-balancer-controller-iam-policy.json \
    "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${CONTROLLER_VERSION}/docs/install/iam_policy.json"

  echo "IAM Policy를 생성합니다."

  aws iam create-policy \
    --policy-name "${POLICY_NAME}" \
    --policy-document file:///tmp/aws-load-balancer-controller-iam-policy.json

fi


# =========================================================
# 6. IAM ServiceAccount + IAM Role 생성
# =========================================================
echo "Load Balancer Controller ServiceAccount 확인 중..."

if kubectl get serviceaccount "${SERVICE_ACCOUNT_NAME}" \
    -n "${NAMESPACE}" \
    > /dev/null 2>&1; then

  echo "${SERVICE_ACCOUNT_NAME} ServiceAccount가 이미 존재합니다."

else

  echo "ServiceAccount와 IAM Role을 생성합니다."

  eksctl create iamserviceaccount \
    --cluster "${CLUSTER_NAME}" \
    --region "${AWS_REGION}" \
    --namespace "${NAMESPACE}" \
    --name "${SERVICE_ACCOUNT_NAME}" \
    --role-name "${ROLE_NAME}" \
    --attach-policy-arn "${POLICY_ARN}" \
    --approve

fi


# =========================================================
# 7. Helm Repository 등록
# =========================================================
echo "Helm repository 설정 중..."

helm repo add eks https://aws.github.io/eks-charts \
  --force-update

helm repo update


# =========================================================
# 8. AWS Load Balancer Controller 설치
# =========================================================
echo "AWS Load Balancer Controller 설치 확인 중..."

if helm status aws-load-balancer-controller \
    -n "${NAMESPACE}" \
    > /dev/null 2>&1; then

  echo "AWS Load Balancer Controller가 이미 설치되어 있습니다."

else

  echo "AWS Load Balancer Controller를 설치합니다."

  helm install aws-load-balancer-controller \
    eks/aws-load-balancer-controller \
    -n "${NAMESPACE}" \
    --set clusterName="${CLUSTER_NAME}" \
    --set serviceAccount.create=false \
    --set serviceAccount.name="${SERVICE_ACCOUNT_NAME}"

fi


# =========================================================
# 9. 설치 확인
# =========================================================
echo "Controller Deployment 확인 중..."

kubectl get deployment \
  aws-load-balancer-controller \
  -n "${NAMESPACE}"

echo "AWS Load Balancer Controller 설정 완료"