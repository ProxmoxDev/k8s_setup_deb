VERSION=v1.29
MANIFEST_VERSION=1.29.0
REPO_CRIO_PATH=stable:/${VERSION}
REPO_KUBERNETES_VERSION=${VERSION}
PACKAGE_KUBERNETES_VERSION=1.29.0-1.1
PACKAGE_CRIO_VERSION=1.29.0-1.1


## Kubernetes Repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/$REPO_KUBERNETES_VERSION/deb/Release.key |
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$REPO_KUBERNETES_VERSION/deb/ /" |
    tee /etc/apt/sources.list.d/kubernetes.list

## cri-o Repository
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/$REPO_CRIO_PATH/deb/Release.key |
    gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/$REPO_CRIO_PATH/deb/ /" |
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
