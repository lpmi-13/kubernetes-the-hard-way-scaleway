# Provisioning Pod Network Routes

Pods scheduled to a node receive an IP address from the node's Pod CIDR range. At this point pods can not communicate with other pods running on different nodes due to missing network routes.

In this lab you will create a route for each worker node that maps the node's Pod CIDR range to the node's internal IP address.

Essentially, we want a pod in each worker node to be able to find a pod in another worker node. So in case of a pod on worker-1 communicating with a pod on worker-2, the route is something like the following:

- pod on worker-1 has a CIDR range of 10.200.1.0/24 (from the kubelet config on that node). It needs to know that for contacting a pod in CIDR range 10.200.2.0/24 (a different subnet), it can use the worker-2 node as a gateway.

- we want to add a route like the following:

```sh
$ ip route add 10.200.2.0/24 via $PRIVATE_IP_ADDRESS_FOR_WORKER_2
```

> There are [other ways](https://kubernetes.io/docs/concepts/cluster-administration/networking/#how-to-achieve-this) to implement the Kubernetes networking model.

## The Routing Table and routes on the workers

Since Scaleway (similar to Digitalocean) doesn't have a nice network routing abstraction from the CLI like AWS/GCP, we have to do this a bit manually, but it has the same effect.

Unfortunately, the previously generated `private_ip_mappings` file won't help us here, since it has the private IP addresses for the controller instances, but we can grab the same values for the worker instances and just update the workers via ssh.

Run the following commands to set all the necessary values in your shell:

```sh
# private IP addresses for setting pod network gateways

worker_1_private_ip=$(scw ipam ip list \
  resource-name=worker-1 \
  is-ipv6=false \
  --output json | jq -r '.[].address' | cut -d / -f1)

worker_2_private_ip=$(scw ipam ip list \
  resource-name=worker-2 \
  is-ipv6=false \
  --output json | jq -r '.[].address' | cut -d / -f1)

worker_3_private_ip=$(scw ipam ip list \
  resource-name=worker-3 \
  is-ipv6=false \
  --output json | jq -r '.[].address' | cut -d / -f1)

# public IP addresses for running commands via ssh

worker_1_public_ip=$(scw instance server list \
  name=worker-1 \
  --output json | jq -r '.[].public_ip.address')

worker_2_public_ip=$(scw instance server list \
  name=worker-2 \
  --output json | jq -r '.[].public_ip.address')

worker_3_public_ip=$(scw instance server list \
  name=worker-3 \
  --output json | jq -r '.[].public_ip.address')
```

run the following commands for each of the worker nodes:

- worker-1

```sh
ssh -i kubernetes.ed25519 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  root@$worker_1_public_ip -C "ip route add 10.200.2.0/24 via $worker_2_private_ip;ip route add 10.200.3.0/24 via $worker_3_private_ip"
```

- worker-2

```sh
ssh -i kubernetes.ed25519 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  root@$worker_2_public_ip -C "ip route add 10.200.1.0/24 via $worker_1_private_ip;ip route add 10.200.3.0/24 via $worker_3_private_ip"
```

- worker-3

```sh
ssh -i kubernetes.ed25519 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  root@$worker_3_public_ip -C "ip route add 10.200.1.0/24 via $worker_1_private_ip;ip route add 10.200.2.0/24 via $worker_2_private_ip"
```

## DNS resolution on the controllers

We also need the controllers to be able to resolve the DNS for `worker-1` to its IP address (eg, `10.240.0.6`). So we need to run the following on each controller:

> Note: substitute whatever values your workers have for private IP addresses. The values given below are examples and yours are likely to be different.

```
cat <<EOF | sudo tee -a /etc/hosts
10.240.0.6 worker-1
10.240.0.7 worker-2
10.240.0.8 worker-3
EOF
```

Next: [Deploying the DNS Cluster Add-on](12-dns-addon.md)
