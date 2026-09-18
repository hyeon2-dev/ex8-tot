#!/bin/bash

set -e

NAMESPACE="argocd"

echo "Argo CD namespace 확인 중..."

if kubectl get namespace "${NAMESPACE}" > /dev/null 2>&1; then
  echo "${NAMESPACE} namespace가 이미 존재합니다."
else
  echo "${NAMESPACE} namespace를 생성합니다."
  kubectl create namespace "${NAMESPACE}"
fi

echo "Argo CD 설치 중..."

kubectl apply \
  -n "${NAMESPACE}" \
  --server-side \
  --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Argo CD Pod 준비 대기 중..."

kubectl wait \
  --for=condition=Ready \
  pods \
  --all \
  -n "${NAMESPACE}" \
  --timeout=300s

echo "Argo CD 설치 완료"

kubectl get pods -n "${NAMESPACE}"