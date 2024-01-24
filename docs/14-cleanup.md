In this lab you will delete the compute resources created during the tutorial.

## Compute Instances

```sh
for server_id in $(scw instance server list --output json | jq -r '.[].id'); do
  scw instance server terminate ${server_id} with-ip=true with-block=true
done
```

## Local SSH Keys

```sh
rm -rf kubernetes.ed25519
rm -rf kubernetes.ed25519.pub
```

## Load Balancer

```sh
for load_balancer_id in $(scw lb lb list --output json | jq -r '.[].id'); do
  scw lb lb delete $load_balancer_id release-ip=true
done
```

## Security Groups

```sh
for security_group in $(scw instance security-group list project-default=false --output json | jq -r '.[].id'); do
  scw instance security-group delete $security_group
done
```

## VPC and Private Subnet

Deleting the network also deletes all the private networks in it, so we can just delete the whole thing.

```sh
VPC_ID=$(scw vpc vpc list name=kubernetes --output json | jq -r '.[].id')

scw vpc vpc delete $VPC_ID
```

And as one last cleanup, we can just delete all the config for the remote nodes/pods/etc:

```sh
rm -rf ./*.{csr,json,kubeconfig,pem,yaml}
rm private_ip_mappings
```
