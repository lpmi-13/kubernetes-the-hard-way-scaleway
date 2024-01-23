# Provisioning Compute Resources

## Networking

In this step, we'll create a VPC, a load balancer and some firewall rules.

### VPC

```sh
VPC_ID=$(scw vpc vpc create
  name=kubernetes \
  region=fr-par \
  --output json | jq -r '.id')
```

Scaleway uses the term "Private Networks" to mean a private subnet, so we'll need one of those.

```sh
PRIVATE_NETWORK_ID=$(scw vpc private-network create \
  name=kubernetes \
  vpc-id=$VPC_ID \
  region=fr-par \
  subnets.0=10.240.0.0/24 \
  --output json | jq -r '.id')
```

> the maximum subnet CIDR for scaleway is /20, even though most of the k8s the hard way walkthroughs specify `/16` for the private subnet, we can easily use `/24` for it, since we only need 6 addresses anyway.

### Kubernetes Public Access - Create a Network Load Balancer

First, we create the load balancer, and then we can attach it to the network.

```sh
LOAD_BALANCER_ID=$(scw lb lb create \
  name=kubernetes-lb \
  type=LB-S \
  --output json | jq -r '.id')
```

```sh
scw lb private-network attach \
  $LOAD_BALANCER_ID \
  private-network-id=$PRIVATE_NETWORK_ID
```

> For some strange reason, the above command requires one positional argument for the load balancer and one named argument for the private network id.

And now we're ready to set the public address for the system.

```sh
KUBERNETES_PUBLIC_ADDRESS=$(scw lb ip list \
  --output json | jq -r '.[] | select(.ip_address | contains(".")).ip_address')
```

> we need to do some minor filtering, since the `scw lb ip list` command also brings back an IPv6 address

### Firewall rules

We need to set these up first, since the only way to associate instances with security groups via the CLI is on instance creation.

We'll create the firewall for the controllers first, since these need to be publicly accessible from the internet.

```sh
$CONTROLLER_SECURITY_GROUP_ID=$(scw instance security-group create name=controller-ingress inbound-default-policy=drop --output json | jq -r '.security_group.id')
```

The controller nodes will have their own certs, so we can pass the https traffic directly to them via the network load balancer when connecting with `kubectl`. The load balancer will listen on port 443 and forward to port 6443.

```sh
scw instance security-group create-rule security-group-id=$CONTROLLER_SECURITY_GROUP_ID protocol=TCP direction=inbound action=accept dest-port-from=6443 dest-port-to=6443
```

We also want to allow SSH access in

```sh
scw instance security-group create-rule security-group-id=$CONTROLLER_SECURITY_GROUP_ID protocol=TCP direction=inbound action=accept dest-port-from=22 dest-port-to=22
```

Let's include ICMP access for the load balancers

```sh
scw instance security-group create-rule security-group-id=$CONTROLLER_SECURITY_GROUP_ID protocol=ICMP direction=inbound action=accept
```

We need internode access from the internal network on TCP

```sh
scw instance security-group create-rule security-group-id=$CONTROLLER_SECURITY_GROUP_ID protocol=TCP direction=inbound action=accept ip-range=10.240.0.0/24
```

And also via UDP

```sh
scw instance security-group create-rule security-group-id=$CONTROLLER_SECURITY_GROUP_ID protocol=UDP direction=inbound action=accept ip-range=10.240.0.0/24
```

And now we can do the same for the worker nodes, but with a slightly different configuration.

```sh
$WORKER_SECURITY_GROUP_ID=$(scw instance security-group create name=worker-ingress inbound-default-policy=drop --output json | jq -r '.security_group.id')
```

We need to allow SSH access in for copying over the certs and stuff.

```sh
scw instance security-group create-rule security-group-id=$WORKER_SECURITY_GROUP_ID protocol=TCP direction=inbound action=accept dest-port-from=22 dest-port-to=22
```

We need internode access from the internal network on TCP

```sh
scw instance security-group create-rule security-group-id=$WORKER_SECURITY_GROUP_ID protocol=TCP direction=inbound action=accept ip-range=10.240.0.0/24
```

And also via UDP

```sh
scw instance security-group create-rule security-group-id=$WORKER_SECURITY_GROUP_ID protocol=UDP direction=inbound action=accept ip-range=10.240.0.0/24
```

And since these are workers creating pods, we also need a rule for interpod traffic on TCP

```sh
scw instance security-group create-rule security-group-id=$WORKER_SECURITY_GROUP_ID protocol=TCP direction=inbound action=accept ip-range=10.200.0.0/24
```

And also via UDP

```sh
scw instance security-group create-rule security-group-id=$WORKER_SECURITY_GROUP_ID protocol=UDP direction=inbound action=accept ip-range=10.200.0.0/24
```

## Compute Instances

### SSH Key

```
ssh-keygen -t ed25519 -o -a 100 -f kubernetes.ed25519
```

We'll attach it directly to the instances as we create them.

### Kubernetes Controllers

Using `DEV1-S` instancess, the smallest that scaleway has, and are easily big enough for our purposes.

```sh
for i in 1 2 3; do
  SERVER_ID=$(scw instance server create \
    image=ubuntu_jammy \
    type=DEV1-S \
    name=controller-${i} \
    tags.0=controller \
    security-group-id=$CONTROLLER_SECURITY_GROUP_ID \
    ip=new \
    --output json | jq -r '.id')
  
  scw instance ssh add-key \
    server-id=$SERVER_ID \
    public-key="$(cat kubernetes.ed25519.pub)"

  scw instance private-nic create \
    server-id=$SERVER_ID \
    private-network-id=$PRIVATE_NETWORK_ID
done
```

### Kubernetes Workers


```sh
for i in 1 2 3; do
  SERVER_ID=$(scw instance server create \
    image=ubuntu_jammy \
    type=DEV1-S \
    name=worker-${i} \
    tags.0=worker \
    security-group-id=$WORKER_SECURITY_GROUP_ID \
    ip=new \
    --output json | jq -r '.id')
  
  scw instance ssh add-key \
    server-id=$SERVER_ID \
    public-key="$(cat kubernetes.ed25519.pub)"

  scw instance private-nic create \
    server-id=$SERVER_ID \
    private-network-id=$PRIVATE_NETWORK_ID
done

```

### Add the Controller nodes to the load balancer

Scaleway likes to be verbose about adding both backends and frontends to load balancers, so we need to do all those bits separately.

```sh
BACKEND_ID=$(scw lb backend create \
  name=kube-backend \
  forward-protocol=tcp \
  forward-port=6443 \
  lb-id=$LOAD_BALANCER_ID \
  health-check.port=6443 \
  health-check.check-max-retries=3 \
  --output json | jq -r '.id')
```

And we'll attach all the controller nodes to the backend for the loadbalancer using their IP addresses.

```sh
for server_ip in $(scw instance server list tags.0=controller --output json | jq -r '.[].id'); do
  scw lb backend add-servers $BACKEND_ID server-ip.0=$server_ip
done
```

We also need a frontend that receives requests at the load balancer public IP and forwards them to our backend.

```sh
scw lb frontend create \
  name=kube-frontend \
  inbound-port=443 \
  lb-id=$LOAD_BALANCER_ID \
  backend-id=$BACKEND_ID
```

Next: [Certificate Authority](04-certificate-authority.md)
