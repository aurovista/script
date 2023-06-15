#!/bin/bash

#修改时区
sudo timedatectl set-timezone Asia/Shanghai
#验证
#date
#重启
sudo systemctl restart rsyslog

# 关闭swap
#临时
sudo swapoff -a
#永久
sed -ri 's/.swap./#&/' /etc/fstab
#验证
free -g

#关闭 selinux(centos)
#sed -i 's/enforcing/disabled/' /etc/selinux/config
#setenforce 0

# 设置HostName
#sudo hostnamectl set-hostname master-node

#安装kubeadm,kubelet,kubectl
sudo apt-get install -y apt-transport-https
sudo curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - 
#curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
#deb https://apt.kubernetes.io/ kubernetes-xenial main
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo systemctl enable --now kubelet

# 阻止自动更新
sudo apt-mark hold kubelet kubeadm kubectl

containerd config default | sudo tee /etc/containerd/config.toml
# 使用阿里源替换国外源
sudo sed -i 's/registry.k8s.io/registry.aliyuncs.com\/google_containers/g' /etc/containerd/config.toml
# config.toml的[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]条目下，将SystemdCgroup = false改为SystemdCgroup = true
sudo systemctl enable containerd
sudo systemctl restart containerd

# 根据环境配置你的--pod-network-cidr的值，不能与已有的网络重复
sudo kubeadm init --image-repository registry.aliyuncs.com/google_containers --pod-network-cidr=10.10.0.0/16 --apiserver-advertise-address=192.168.52.130

# 初始化集群
#生成kubeadm默认配置文件
sudo kubeadm config print init-defaults > kubeadm.yaml
#修改localAPIEndpoint.advertiseAddress为master的ip；
#修改nodeRegistration.name为当前节点名称；
#修改imageRepository为国内源：registry.cn-hangzhou.aliyuncs.com/google_containers
#添加networking.podSubnet:192.168.66.0/24，该网络ip范围不能与networking.serviceSubnet和节点网络192.168.56.0/24冲突
kubeadm config images pull --config kubeadm.yaml
#初始化
sudo kubeadm init --config kubeadm.yaml
#初始化失败
#sudo kubeadm reset

#配置环境变量
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
#root
export KUBECONFIG=/etc/kubernetes/admin.conf

#节点加入集群
kubeadm token create --print-join-command
kubeadm join 192.168.52.130:6443 --token n762o3.gmofjd4feyiqe52x \
	--discovery-token-ca-cert-hash sha256:30216b1cdffb160c8d86fd0b04c9137a781718694511107536c3edec8c41de91 

kubectl get nodes

#安装CNI网络插件calico
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/tigera-operator.yaml
curl https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/custom-resources.yaml -O
# 编辑custom-resources.yaml，确保cidr配置的值与之前--pod-network-cidr的值相同
kubectl create -f custom-resources.yaml
kubectl apply -f custom-resources.yaml
#https://cloud.tencent.com/developer/article/1817826
#部署DashBoard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
kubectl proxy
# http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
#DashBoard公共访问(http://NodeIP:30001)
kind:Service
apiVersion: v1
metadata:
    labels:
        k8s-app:kubernetes-dashboard
name: kubernetes-dashboard
namespace: kube-system
spec:
    type:NodePort
ports:
    -port:443
    targetPort:8443
    nodePort:30001
selector:
    k8s-app:kubernetes-dashboard
#创建账户
kubectl create serviceaccount dashboard-admin -n kube-system
kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kube-system:dashboard-admin
kubectl describe secrets -n kube-system $(kubectl -n kube-system get secret | awk '/dashboard-admin/{print $1}')




hostnamectl --static set-hostname k8s-master
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4EB27DB2A3B88B8B
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B53DC80D13EDEF05
cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb http://mirrors.ustc.edu.cn/kubernetes/apt kubernetes-xenial main
EOF
apt-get update && apt-get install -y docker.io
apt-get update && apt-get -y install kubelet=1.20.11-00 kubernetes-cni=1.2.0-00 kubectl=1.20.11-00 kubeadm=1.20.11-00
swapoff -a
cat /data/workspace/myshixun/step1/docker-init.txt > /etc/docker/daemon.json
service docker restart
docker pull docker.io/calico/cni:v3.14.2
docker pull docker.io/calico/pod2daemon-flexvol:v3.14.2
docker pull docker.io/calico/node:v3.14.2
docker pull docker.io/calico/kube-controllers:v3.14.2
kubeadm init --image-repository='registry.cn-hangzhou.aliyuncs.com/google_containers'
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
kubectl apply -f calico.yaml