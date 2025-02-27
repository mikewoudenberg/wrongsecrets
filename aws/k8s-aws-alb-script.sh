#!/bin/bash
# set -o errexit
# set -o pipefail
# set -o nounset

function checkCommandsAvailable() {
  for var in "$@"
  do
    if ! [ -x "$(command -v "$var")" ]; then
      echo "🔥 ${var} is not installed." >&2
      exit 1
    else
      echo "🏄 $var is installed..."
    fi
  done
}

checkCommandsAvailable helm jq vault sed grep docker grep cat aws curl eksctl kubectl

if test -n "${AWS_REGION-}"; then
  echo "AWS_REGION is set to <$AWS_REGION>"
else
  AWS_REGION=eu-west-1
  echo "AWS_REGION is not set or empty, defaulting to ${AWS_REGION}"
fi

if test -n "${CLUSTERNAME-}"; then
  echo "CLUSTERNAME is set to <$CLUSTERNAME>"
else
  CLUSTERNAME=wrongsecrets-exercise-cluster
  echo "CLUSTERNAME is not set or empty, defaulting to ${CLUSTERNAME}"
fi

ACCOUNT_ID=$(aws sts get-caller-identity | jq '.Account' -r)
echo "ACCOUNT_ID=${ACCOUNT_ID}"

LBC_VERSION="v2.3.0"
echo "LBC_VERSION=$LBC_VERSION"


# echo "executing eksctl utils associate-iam-oidc-provider"
# eksctl utils associate-iam-oidc-provider \
#     --region ${AWS_REGION} \
#     --cluster ${CLUSTERNAME} \
#     --approve

echo "creating iam policy"
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.3.0/docs/install/iam_policy.json
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

echo "creating iam service account for cluster ${CLUSTERNAME}"
eksctl create iamserviceaccount \
  --cluster $CLUSTERNAME \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --region $AWS_REGION \
  --approve


echo "setting up kubectl"

aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTERNAME --kubeconfig ~/.kube/wrongsecrets

export KUBECONFIG=~/.kube/wrongsecrets

echo "applying aws-lbc with kubectl"

kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"

kubectl get crd

echo "do helm eks application"
helm repo add eks https://aws.github.io/eks-charts

helm upgrade -i aws-load-balancer-controller \
    eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=${CLUSTERNAME} \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set image.tag="${LBC_VERSION}"


kubectl -n kube-system rollout status deployment aws-load-balancer-controller

EKS_CLUSTER_VERSION=$(aws eks describe-cluster --name $CLUSTERNAME --region $AWS_REGION --query cluster.version --output text)

kubectl apply -f k8s/secret-challenge-vault-ingress.yml

echo "Do not forget to cleanup afterwards! Run k8s-aws-alb-script-cleanup.sh"
