---
layout: post
title: "🔧【k8s】Ubuntu部署kubernetes集群(二)"
categories: kubernetes
author: "ooTao"
typora-root-url: ..
---



## 配置网络插件

集群初始化成功后执行 `kubectl get pods -n kube-system`查看节点上各个pod的状态。

```shell
root@ubuntu1804m:/etc/docker$ kubectl get pods -n kube-system
NAME                                  READY   STATUS     RESTARTS   AGE
coredns-6d8c4cb4d-qfrrx               0/1     Pending    0          170m
coredns-6d8c4cb4d-w779m               0/1     Pending    0          170m
etcd-ubuntu1804m                      1/1     Running    0          170m
kube-apiserver-ubuntu1804m            1/1     Running    0          170m
kube-controller-manager-ubuntu1804m   1/1     Running    4          170m
kube-proxy-nb9z9                      1/1     Running    0          170m
kube-scheduler-ubuntu1804m            1/1     Running    4          170m
```

可以看到两个coreDNS并没有运行，因为我们的节点网络并没有配置就绪，使用如下命令安装对应版本网络插件weave。

```shell
$ kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
```

稍等几分钟后再查看pod状态 `kubectl get pods -n kube-system`

![Snipaste_2022-05-06_15-16-11](/media/Snipaste_2022-05-06_15-16-11.jpg)

至此，集群的master节点就部署完成了

### 可能出现的问题

`kubectl apply`时报错

```shell
root@k8s-master:~# kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
Unable to connect to the server: dial tcp: lookup cloud.weave.works on 127.0.0.53:53: server misbehaving
```

原因是未配置正确的DNS，临时解决办法：修改/etc/resolv.conf

```shell
vim /etc/resolv.conf
# nameserver 127.0.0.1
# 改成
# nameserver 114.114.114.114或者8.8.8.8，改成公网的DNS服务器地址
```

永久修改：

```shell
vim /etc/network/interfaces
# 添加一行dns-nameservers 8.8.8.8
# 多个dns用空格隔开
# 重启生效
```



如果有遇到**CoreDNS** 状态是 **CrashLoopBackOff** ，可以参考[Kubernetes CoreDNS 状态是 CrashLoopBackOff 解决思路](https://blog.csdn.net/qq_24046745/article/details/93988920)。

## 部署worker节点

首先禁用swap并关闭防火墙

```shell
vim /etc/fstab             
# 注释掉包含swap的行，重启后生效。或者执行swapoff -a，本次有效。
systemctl stop ufw 
systemctl disable ufw
```

然后执行kubeadm init成功后提示的 `kubeadm join`命令，没记住找不到也没关系，在master节点重新生成一个

```shell
root@k8s-master:/# kubeadm token create --print-join-command
kubeadm join 192.168.137.131:6443 --token 4yyyli.zkdkv2kykbszv6e4 --discovery-token-ca-cert-hash sha256:c1099d0b2f47fbd1f802048a89e88438e8376b83689358953ce81a07ddbe7acb
```

然后在node节点执行

```shell
root@k8s-node1:/etc/kubernetes# kubeadm join 192.168.137.131:6443 --token 4yyyli.zkdkv2kykbszv6e4 --discovery-token-ca-cert-hash sha256:c1099d0b2f47fbd1f802048a89e88438e8376b83689358953ce81a07ddbe7acb 
# 显示如下信息说明加入成功
...
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.

```

在master节点使用 `kubectl get nodes` 查看node状态

```shell
root@k8s-master:/$ kubectl get nodes
NAME         STATUS     ROLES                  AGE   VERSION
k8s-master   Ready      control-plane,master   66m   v1.23.6
k8s-node1    NotReady   <none>                 11m   v1.23.6

```

发现node1没有就绪？那就详细看一下是为什么 ` kubectl describe pod weave-net-qtd5v --namespace=kube-system`

运行上面那条命令会打印出很多信息，在 `Events`中发现了有用信息

```shell
Events:
  Type     Reason     Age                   From               Message
  ----     ------     ----                  ----               -------
  Normal   Scheduled  25m                   default-scheduler  Successfully assigned kube-system/weave-net-qtd5v to k8s-node1
  Normal   Pulling    23m (x4 over 25m)     kubelet            Pulling image "ghcr.io/weaveworks/launcher/weave-kube:2.8.1"
  Warning  Failed     23m (x4 over 25m)     kubelet            Failed to pull image "ghcr.io/weaveworks/launcher/weave-kube:2.8.1": rpc error: code = Unknown desc = Error response from daemon: Get https://ghcr.io/v2/: dial tcp: lookup ghcr.io: no such host
  Warning  Failed     23m (x4 over 25m)     kubelet            Error: ErrImagePull
  Warning  Failed     23m (x6 over 24m)     kubelet            Error: ImagePullBackOff
  Normal   BackOff    4m51s (x87 over 24m)  kubelet            Back-off pulling image "ghcr.io/weaveworks/launcher/weave-kube:2.8.1"

```

发现是weave的镜像拉取失败，那我们在node1上手动拉取镜像试试。我怀疑可能是国外网站访问比较困难，所以这里科学地pull一下镜像。

```shell
root@k8s-node1:/$ docker pull ghcr.io/weaveworks/launcher/weave-kube:2.8.1
2.8.1: Pulling from weaveworks/launcher/weave-kube
21c83c524219: Pull complete 
3c1275a4379d: Pull complete 
e207e25b5e7f: Pull complete 
ae65035f6b5f: Pull complete 
e9e9e78f4d22: Pull complete 
cbd17873e599: Pull complete 
Digest: sha256:d797338e7beb17222e10757b71400d8471bdbd9be13b5da38ce2ebf597fb4e63
Status: Downloaded newer image for ghcr.io/weaveworks/launcher/weave-kube:2.8.1
ghcr.io/weaveworks/launcher/weave-kube:2.8.1
```

经过漫长的等待pull成功了，再查看节点状态，已经就绪。

```shell
root@k8s-master:/$ kubectl get nodes
NAME         STATUS   ROLES                  AGE    VERSION
k8s-master   Ready    control-plane,master   123m   v1.23.6
k8s-node1    Ready    <none>                 68m    v1.23.6
```

再等待一段时间等node1的网络插件初始化成功，最后查看各个pod状态 `kubectl get pods -n kube-system`

![Snipaste_2022-05-06_16-50-37](/media/Snipaste_2022-05-06_16-50-37.jpg)

ALL right.

下一篇介绍部署第一个应用。
