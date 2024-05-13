#!/bin/bash

KUBE_API_SERVER_IP=192.168.100.
REPO_KUBERNETES_VERSION=v1.29
PACKAGE_KUBERNETES_VERSION=1.29.0-1.1
PACKAGE_CRIO_VERSION=1.29.0-1.1
PROJECT_PATH=stable:/v1.29

## Kubernetes Repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/$REPO_KUBERNETES_VERSION/deb/Release.key |
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$REPO_KUBERNETES_VERSION/deb/ /" |
    tee /etc/apt/sources.list.d/kubernetes.list

## cri-o Repository
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/$PROJECT_PATH/deb/Release.key |
    gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/$PROJECT_PATH/deb/ /" |
    tee /etc/apt/sources.list.d/cri-o.list

## Install Kubernetes
apt update -y
apt install -y \
  kubelet=$PACKAGE_KUBERNETES_VERSION \
  kubeadm=$PACKAGE_KUBERNETES_VERSION \
  kubectl=$PACKAGE_KUBERNETES_VERSION \
  cri-o=$PACKAGE_CRIO_VERSION

## Start Service
systemctl enable --now crio.service
systemctl enable kubelet.service

## swap無効
swapoff -a

## ネットワーク設定
modprobe br_netfilter
sysctl -w net.ipv4.ip_forward=1

## kubeadm設定
# Set kubeadm bootstrap token using openssl
KUBEADM_BOOTSTRAP_TOKEN=$(openssl rand -hex 3).$(openssl rand -hex 8)

# Set init configuration for the first control plane
cat > ~/init_kubeadm.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
bootstrapTokens:
- token: "$KUBEADM_BOOTSTRAP_TOKEN"
  description: "kubeadm bootstrap token"
  ttl: "24h"
nodeRegistration:
  criSocket: "unix:///var/run/crio/crio.sock"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
networking:
  serviceSubnet: "192.168.100.0/24"
  podSubnet: "192.128.100.0/24"
kubernetesVersion: "${PACKAGE_KUBERNETES_VERSION}"
controlPlaneEndpoint: "${KUBE_API_SERVER_IP}:6443"
EOF

kubeadm init --config ~/init_kubeadm.yaml

# kubectl Setting
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

echo "source <(kubectl completion bash)" >> ~/.bashrc
alias k=kubectl
complete -F __start_kubectl k

# Generate control plane certificate
KUBEADM_UPLOADED_CERTS=$(kubeadm init phase upload-certs --upload-certs | tail -n 1)

# Set join configuration for other control plane nodes
cat > ~/join_kubeadm_cp.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
nodeRegistration:
  criSocket: "unix:///var/run/crio/crio.sock"
discovery:
  bootstrapToken:
    apiServerEndpoint: "${KUBE_API_SERVER_IP}:6443"
    token: "$KUBEADM_BOOTSTRAP_TOKEN"
    unsafeSkipCAVerification: true
controlPlane:
  certificateKey: "$KUBEADM_UPLOADED_CERTS"
EOF

# Set join configuration for worker nodes
cat > ~/join_kubeadm_wk.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
nodeRegistration:
  criSocket: "unix:///var/run/crio/crio.sock"
discovery:
  bootstrapToken:
    apiServerEndpoint: "${KUBE_API_SERVER_IP}:6443"
    token: "$KUBEADM_BOOTSTRAP_TOKEN"
    unsafeSkipCAVerification: true
EOF
