#! /bin/sh
wget -q --show-progress --https-only --timestamping \
  https://github.com/cloudflare/cfssl/releases/download/v1.4.1/cfssl_1.4.1_linux_amd64 \
  https://github.com/cloudflare/cfssl/releases/download/v1.4.1/cfssljson_1.4.1_linux_amd64

chmod +x cfssl_1.4.1_linux_amd64 cfssljson_1.4.1_linux_amd64

sudo mv cfssl_1.4.1_linux_amd64 /usr/local/bin/cfssl
sudo mv cfssljson_1.4.1_linux_amd64 /usr/local/bin/cfssljson

cfssl version

wget https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kubectl

chmod +x kubectl

sudo mv kubectl /usr/local/bin

kubectl version --client

sudo apt install jq

jq --version
