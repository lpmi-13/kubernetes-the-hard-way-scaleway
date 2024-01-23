cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF

echo "generating ca-key.pem, ca.pem"
cfssl gencert -initca ca-csr.json | cfssljson -bare ca

cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

echo "generating admin-key.pem, admin.pem"

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

for i in 1 2 3; do
  instance_hostname="worker-${i}"
  cat > ${instance_hostname}-csr.json <<EOF
{
  "CN": "system:node:${instance_hostname}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

external_ip=$(scw instance server list \
  name=worker-${i} \
  --output json | jq -r '.[].public_ip.address')

internal_ip=$(scw ipam ip list \
  resource-name=worker-${i} \
  is-ipv6=false \
  --output json | jq -r '.[].address' | cut -d '/' -f 1)


echo "generating certificate and private key for ${instance_hostname}"

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${instance_hostname},${external_ip},${internal_ip} \
  -profile=kubernetes \
  worker-${i}-csr.json | cfssljson -bare worker-${i}
done

cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

echo "generating kube-controller-manager-key.pem and kube-controller-manager.pem"

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

echo "generating kube-proxy-key.pem and kube-proxy.pem"

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

echo "generating kube-schedule-key.pem and kube-scheduler.pem"

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler


cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

KUBERNETES_PUBLIC_ADDRESS=$(scw lb ip list \
  --output json | jq -r '.[] | select(.ip_address | contains(".")).ip_address')

KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

controller_1_private_ip=$(scw ipam ip list resource-name=controller-1 is-ipv6=false --output json | jq -r '.[].address' | cut -d '/' -f 1)
controller_2_private_ip=$(scw ipam ip list resource-name=controller-2 is-ipv6=false --output json | jq -r '.[].address' | cut -d '/' -f 1)
controller_3_private_ip=$(scw ipam ip list resource-name=controller-3 is-ipv6=false --output json | jq -r '.[].address' | cut -d '/' -f 1)

echo "generating kubernetes-key.pem and kubernetes.pem"

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,${controller_1_private_ip},${controller_2_private_ip},${controller_3_private_ip},${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

echo "generating service-account-key.pem and service-account.pem"

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account

for instance in worker-1 worker-2 worker-3; do
  external_ip=$(scw instance server list \
    name=${instance} \
    --output json | jq -r '.[].public_ip.address')

  scp -i kubernetes.ed25519 \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    ca.pem ${instance}-key.pem ${instance}.pem root@${external_ip}:~/
done

for instance in controller-1 controller-2 controller-3; do
  external_ip=$(scw instance server list \
    name=${instance} \
    --output json | jq -r '.[].public_ip.address')

  scp -i kubernetes.ed25519 \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem root@${external_ip}:~/
done
