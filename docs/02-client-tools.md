# Installing the Client Tools

In this lab you will install the command line utilities required to complete this tutorial: [cfssl](https://github.com/cloudflare/cfssl), [cfssljson](https://github.com/cloudflare/cfssl), [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl), and [jq](https://stedolan.github.io/jq/download/).


## Install CFSSL

The `cfssl` and `cfssljson` command line utilities will be used to provision a [PKI Infrastructure](https://en.wikipedia.org/wiki/Public_key_infrastructure) and generate TLS certificates.

Download and install `cfssl` and `cfssljson` from the [cfssl repository](https://pkg.cfssl.org):

### OS X

```sh
curl -o cfssl https://pkg.cfssl.org/R1.2/cfssl_darwin-amd64
curl -o cfssljson https://pkg.cfssl.org/R1.2/cfssljson_darwin-amd64
```

```sh
chmod +x cfssl cfssljson
```

```sh
sudo mv cfssl cfssljson /usr/local/bin/
```

Some OS X users may experience problems using the pre-built binaries in which case [Homebrew](https://brew.sh) might be a better option:

```sh
brew install cfssl
```

### Linux

```sh
wget -q --show-progress --https-only --timestamping \
  https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 \
  https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
```

```sh
chmod +x cfssl_linux-amd64 cfssljson_linux-amd64
```

```sh
sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl
```

```sh
sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
```

### Verification

Verify `cfssl` version 1.2.0 or higher is installed:

```sh
cfssl version
```

> output

```sh
Version: 1.2.0
Revision: dev
Runtime: go1.6
```

> The cfssljson command line utility does not provide a way to print its version.

## Install kubectl

The `kubectl` command line utility is used to interact with the Kubernetes API Server. Download and install `kubectl` from the official release binaries:

### OS X

```sh
curl -o kubectl https://storage.googleapis.com/kubernetes-release/release/v1.26.13/bin/darwin/amd64/kubectl
```

```sh
chmod +x kubectl
```

```sh
sudo mv kubectl /usr/local/bin/
```

### Linux

```sh
wget https://storage.googleapis.com/kubernetes-release/release/v1.17.2/bin/linux/amd64/kubectl
```

```sh
chmod +x kubectl
```

```sh
sudo mv kubectl /usr/local/bin/
```

### Verification

Verify `kubectl` version 1.26.13 or higher is installed:

```sh
kubectl version --short
```

> output

```sh
Flag --short has been deprecated, and will be removed in the future. The --short output will become the default.
Client Version: v1.26.13
Kustomize Version: v4.5.7
The connection to the server 0.0.0.0:41769 was refused - did you specify the right host or port?
```

## Install jq
(to make it easier to parse the output from the CLI commands)

for non-standard systems, follow the instructions [here](https://stedolan.github.io/jq/download/).

### OS X

```sh
brew install jq
```

### Linux (on ubuntu/debian...for other distros see the link above)

```sh
sudo apt-get install jq
```

### Verification

```sh
jq --version
```

> output

```sh
jq-1.6
```

Next: [Provisioning Compute Resources](03-compute-resources.md)
