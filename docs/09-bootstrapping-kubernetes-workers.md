# Bootstrapping the Kubernetes Worker Nodes

In this lab you will bootstrap three Kubernetes worker nodes. The following components will be installed on each node: [runc](https://github.com/opencontainers/runc), [gVisor](https://github.com/google/gvisor), [container networking plugins](https://github.com/containernetworking/cni), [containerd](https://github.com/containerd/containerd), [kubelet](https://kubernetes.io/docs/admin/kubelet), and [kube-proxy](https://kubernetes.io/docs/concepts/cluster-administration/proxies).

## Prerequisites

The remaining commands in this lab must be run on each worker instance: `worker-1`, `worker-2`, and `worker-3`. Login to each worker instance using the `ssh` command. Example:

```sh
for instance in worker-1 worker-2 worker-3; do
  external_ip=$(scw instance server list \
    name=${instance} \
    --output json | jq -r '.[].public_ip.address')

  echo ssh -i kubernetes.ed25519 root@$external_ip
done
```

Now ssh into each one of the IP addresses received in last step.

### Running commands in parallel with tmux

[tmux](https://github.com/tmux/tmux/wiki) can be used to run commands on multiple compute instances at the same time. See the [Running commands in parallel with tmux](01-prerequisites.md#running-commands-in-parallel-with-tmux) section in the Prerequisites lab.

## Provisioning a Kubernetes Worker Node

Install the OS dependencies:

```sh
sudo apt-get update
sudo apt-get -y install socat conntrack ipset
```

> The socat binary enables support for the `kubectl port-forward` command.

### Download and Install Worker Binaries

```sh
wget -q --show-progress --https-only --timestamping \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.17.0/crictl-v1.17.0-linux-amd64.tar.gz \
  https://github.com/opencontainers/runc/releases/download/v1.0.0-rc10/runc.amd64 \
  https://github.com/containernetworking/plugins/releases/download/v0.8.5/cni-plugins-linux-amd64-v0.8.5.tgz \
  https://github.com/containerd/containerd/releases/download/v1.3.2/containerd-1.3.2.linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-release/release/v1.17.2/bin/linux/amd64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v1.17.2/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v1.17.2/bin/linux/amd64/kubelet
```

Create the installation directories:

```sh
sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes
```

Install the worker binaries:

```sh
chmod +x kubectl kube-proxy kubelet runc.amd64
sudo mv runc.amd64 runc
sudo mv kubectl kube-proxy kubelet runc /usr/local/bin/
sudo tar -xvf crictl-v1.17.0-linux-amd64.tar.gz -C /usr/local/bin/
sudo tar -xvf cni-plugins-linux-amd64-v0.8.5.tgz -C /opt/cni/bin/
sudo tar -xvf containerd-1.3.2.linux-amd64.tar.gz -C /
```

### Configure CNI Networking

Retrieve the number needed for the Pod CIDR based on the current hostname:

```sh
WORKER_NUMBER=$(hostname | cut -d '-' -f2)
```

> the actual number we use doesn't technically matter, since the pod CIDRs are completely separate to the nodes themselves, but we just need to make sure they don't overlap, and just using each of the hostname numbers is an easy way to make sure each of the workers has non-overlapping ranges.

Create the `bridge` network configuration file:

```sh
cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "10.200.${WORKER_NUMBER}.0/24"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF
```

Create the `loopback` network configuration file:

```sh
cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.3.1",
    "type": "loopback"
}
EOF
```

### Configure containerd

Create the `containerd` configuration file:

```sh
sudo mkdir -p /etc/containerd/
```

```sh
cat << EOF | sudo tee /etc/containerd/config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
EOF
```

Create the `containerd.service` systemd unit file:

```sh
cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF
```

### Configure the Kubelet

```sh
sudo mv $(hostname)-key.pem $(hostname).pem /var/lib/kubelet/
sudo mv $(hostname).kubeconfig /var/lib/kubelet/kubeconfig
sudo mv ca.pem /var/lib/kubernetes/
```

Create the `kubelet-config.yaml` configuration file:

```sh
WORKER_NAME=$(hostname)

cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "10.200.${WORKER_NUMBER}.0/24"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${WORKER_NAME}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${WORKER_NAME}-key.pem"
resolvConf: "/run/systemd/resolve/resolv.conf"
EOF
```

Create the `kubelet.service` systemd unit file:

```sh
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Configure the Kubernetes Proxy

```sh
sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
```

Create the `kube-proxy-config.yaml` configuration file:

```sh
cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF
```

Create the `kube-proxy.service` systemd unit file:

```sh
cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Start the Worker Services

Before we enable kubelet, let's turn swap off, since this is going to crash the service, and we definitely don't need it here anyway.

```sh
swapoff -a
```

Now kubelet should start as usual.

```sh
sudo systemctl daemon-reload
sudo systemctl enable containerd kubelet kube-proxy
sudo systemctl start containerd kubelet kube-proxy
```

> Remember to run the above commands on each worker node: `worker-1`, `worker-2`, and `worker-3`.

## Verification

> The compute instances created in this tutorial will not have permission to complete this section. Run the following commands from the same machine used to create the compute instances.

List the registered Kubernetes nodes:

```sh
external_ip=$(scw instance server list \
  name=controller-1 \
  --output json | jq -r '.[].public_ip.address')

ssh -i kubernetes.ed25519 root@${external_ip}

kubectl get nodes --kubeconfig admin.kubeconfig
```

> output

```sh
NAME       STATUS   ROLES    AGE    VERSION
worker-1   Ready    <none>   103s   v1.17.2
worker-2   Ready    <none>   72s    v1.17.2
worker-3   Ready    <none>   41s    v1.17.2
```

Next: [Configuring kubectl for Remote Access](10-configuring-kubectl.md)
