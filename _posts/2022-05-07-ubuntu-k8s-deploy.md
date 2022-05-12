---
layout: post
title: "🔧【k8s】Ubuntu部署kubernetes集群(一)"
categories: kubernetes
author: "ooTao"
typora-root-url: ..
---

## 准备工作

- 两台或更多ubuntu机器，推荐1404以上；
- 要求cpu两核及以上，64bit x86 or ARM，内存2g及以上；
- 能够访问互联网；
- 可用磁盘空间建议20GB，主要用于存储Docker images。

我准备的机器：两台vmware虚拟机安装Ubuntu18.04，一台4核4GB内存作为master，一台2核2GB内存作为slave。

**提醒**：如果不具备科学上网的条件，建议将ubuntu镜像源替换为国内源，不然下载和更新网站会非常非常慢。具体操作参考[阿里巴巴开源镜像站-OPSX镜像站-阿里云开发者社区](https://developer.aliyun.com/mirror/)。

**警告：如果尝试使用WSL2的虚拟机可以放弃了。**因为Kubernetes使用systemd作为cgroup Driver，但是！！！WSL2不使用Linux原生的Init System: systemd，而是Windows的SysV init，所以没有办法在WSL2下运行Kubernetes集群。

---

## 安装Docker及Kubeadm

### 添加kubernetes国内源

为了方便，以下命令都是在root权限下运行。

添加阿里云的镜像源 `https://mirrors.aliyun.com/kubernetes/apt`。

```shell
echo "deb https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
# 更新源
apt-get update
```

更新源 `apt-get update` 报错:

```shell
W: GPG error: https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial InRelease: The following signatures couldn't be verified because the public key is not available: NO_PUBKEY FEEA9169307EA071 NO_PUBKEY 8B57C5C2836F4BEB
E: The repository 'https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial InRelease' is not signed.
N: Updating from such a repository can't be done securely, and is therefore disabled by default.
N: See apt-secure(8) manpage for repository creation and user configuration details.

```

原因是没有添加gpg密钥，那就添加上。注意，此处密钥为报错信息中 **NO_PUBKEY**后面的部分。

```shell
gpg --keyserver keyserver.ubuntu.com --recv-keys 8B57C5C2836F4BEB
gpg --export --armor 8B57C5C2836F4BEB | sudo apt-key add -
apt-get update
# 等待更新完毕
```

### 安装Docker.io和 kubeadm

执行命令 `apt-get install -y docker.io kubeadm`，等待安装完毕即可。

```shell
apt-get install -y docker.io kubeadm
```

### 启动Docker服务

```shell
systemctl enable docker
systemctl start docker
systemctl status docker
# 查看Docker版本
docker --version
 Docker version 20.10.7, build 20.10.7-0ubuntu5~18.04.3
```

查看Docker的Cgroup Driver

```shell
docker info | grep -i cgroup
 Cgroup Driver: cgroupfs
 Cgroup Version: 1
```

需要将 `cgroupfs`修改为Kubernetes要求的 `systemd`。

```shell
# cd到 `/etc/docker`目录
cd /etc/docker
# 找到daemon.json文件，如果没有就新建一个
ls
 daemon.json  key.json
vim daemon.json
# 在json中加入如下语句，指定cgroupdriver
{
        "exec-opts": ["native.cgroupdriver=systemd"]
}
# 添加完毕:wq保存
```

然后重启docker服务

```shell
systemctl restart docker
systemctl status docker
```

### 初始化kubeadm

理论上来说可以通过 `kubeadm init`命令初始化节点，第一阶段会自动为我们下载各种配置的images，具体哪些可以通过 `kubeadm config images list`查看。

```shell
root@ubuntu1804m:/etc/docker$ kubeadm config images list
I0504 17:45:48.635321   23708 version.go:255] remote version is much newer: v1.24.0; falling back to: stable-1.23
k8s.gcr.io/kube-apiserver:v1.23.6
k8s.gcr.io/kube-controller-manager:v1.23.6
k8s.gcr.io/kube-scheduler:v1.23.6
k8s.gcr.io/kube-proxy:v1.23.6
k8s.gcr.io/pause:3.6
k8s.gcr.io/etcd:3.5.1-0
k8s.gcr.io/coredns/coredns:v1.8.6
```

理论上我们也可以通过命令 `kubeadm config images pull`手动拉取这几个images，但是由于没有办法访问 `k8s.gcr.io`所以会在等待一段时间后超时。有的同学可能会想欸那我挂个VPN不就行了，我也想到了，but不起作用呀Q^Q（也可能是我姿势不对？）反正google.com能正常访问，但镜像就是没有办法pull下来。

顺便虚拟机如何使用主机VPN参考[这篇文章](https://arctee.cn/686.html)。

经过一番检索找到正确init姿势。(๑•̀ㅂ•́)و✧ aliyun yyds

```shell
$ kubeadm init \
  --apiserver-advertise-address=172.17.0.1 \
  --image-repository registry.aliyuncs.com/google_containers \
  --kubernetes-version v1.23.6 \
  --service-cidr=10.1.0.0/16 \
  --pod-network-cidr=10.244.0.0/16
```

**PS**: `--apiserver-advertise-address`字段值为虚拟机的ip，kubernetes-version为安装的kubernetes版本。

初始化完成可以看到以下几条信息：

```shell
...
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 172.17.0.1:6443 --token oh452y.6k0r7rn21z3cm0v5 \
	--discovery-token-ca-cert-hash sha256:0340616be9f5b3e2fec7091bf6e081816622523fc4ec3a93a223704aeb375b54 

```

可以看到kubeadm 提示我们第一次使用 Kubernetes 集群所需要的配置命令，需要这些配置命令的原因是：Kubernetes 集群默认需要加密方式访问，所以这几条命令，就是将刚刚部署生成的 Kubernetes 集群的安全配置文件，保存到当前用户的.kube 目录下，kubectl 默认会使用这个目录下的授权信息访问 Kubernetes 集群。

现在我们就可以查看当前节点状态了。

```shell
root@ubuntu1804m:/etc/docker$ kubectl get nodes
NAME          STATUS     ROLES                  AGE   VERSION
ubuntu1804m   NotReady   control-plane,master   32m   v1.23.6
```

到这里就基本完成第一个节点的部署，还差一点东西放到下一篇博客。

**提示**：如果出了某些问题导致节点没有成功部署，也没有思路排除错误，可以运行 `kubeadm reset`，然后重新init。