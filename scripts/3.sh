#! /bin/bash

VPC_ID=$(scw vpc vpc create \
  name=kubernetes \
  region=fr-par \
  --output json | jq -r '.id')

echo -e "vpc created\n\n"

PRIVATE_NETWORK_ID=$(scw vpc private-network create \
  name=kubernetes \
  vpc-id=$VPC_ID \
  region=fr-par \
  subnets.0=10.240.0.0/24 \
  --output json | jq -r '.id')

echo -e "private network created\n\n"

LOAD_BALANCER_ID=$(scw lb lb create \
  name=kubernetes-lb \
  type=LB-S \
  --output json | jq -r '.id')

echo -e "load balancer created\n\n"

echo "waiting 10 seconds for load balancer to be ready for attachment to private network..."
sleep 10 

scw lb private-network attach \
  $LOAD_BALANCER_ID \
  private-network-id=$PRIVATE_NETWORK_ID

CONTROLLER_SECURITY_GROUP_ID=$(scw instance security-group create name=controller-ingress inbound-default-policy=drop --output json | jq -r '.security_group.id')

scw instance security-group create-rule security-group-id=$CONTROLLER_SECURITY_GROUP_ID protocol=TCP direction=inbound action=accept dest-port-from=6443

scw instance security-group create-rule security-group-id=$CONTROLLER_SECURITY_GROUP_ID protocol=TCP direction=inbound action=accept dest-port-from=22

scw instance security-group create-rule security-group-id=$CONTROLLER_SECURITY_GROUP_ID protocol=ICMP direction=inbound action=accept

scw instance security-group create-rule security-group-id=$CONTROLLER_SECURITY_GROUP_ID protocol=TCP direction=inbound action=accept ip-range=10.240.0.0/24

scw instance security-group create-rule security-group-id=$CONTROLLER_SECURITY_GROUP_ID protocol=UDP direction=inbound action=accept ip-range=10.240.0.0/24

WORKER_SECURITY_GROUP_ID=$(scw instance security-group create name=worker-ingress inbound-default-policy=drop --output json | jq -r '.security_group.id')

echo -e "waiting 5 seconds for the backend to be ready...\n\n"

scw instance security-group create-rule security-group-id=$WORKER_SECURITY_GROUP_ID protocol=TCP direction=inbound action=accept dest-port-from=22 dest-port-to=22

scw instance security-group create-rule security-group-id=$WORKER_SECURITY_GROUP_ID protocol=TCP direction=inbound action=accept ip-range=10.240.0.0/24

scw instance security-group create-rule security-group-id=$WORKER_SECURITY_GROUP_ID protocol=UDP direction=inbound action=accept ip-range=10.240.0.0/24

scw instance security-group create-rule security-group-id=$WORKER_SECURITY_GROUP_ID protocol=TCP direction=inbound action=accept ip-range=10.200.0.0/24

scw instance security-group create-rule security-group-id=$WORKER_SECURITY_GROUP_ID protocol=UDP direction=inbound action=accept ip-range=10.200.0.0/24

ssh-keygen -t ed25519 -o -a 100 -f kubernetes.ed25519 -N ""

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

BACKEND_ID=$(scw lb backend create \
  name=kube-backend \
  forward-protocol=tcp \
  forward-port=6443 \
  lb-id=$LOAD_BALANCER_ID \
  health-check.port=6443 \
  health-check.check-max-retries=3 \
  --output json | jq -r '.id')

echo -e "waiting 5 seconds for the backend to be ready...\n\n"
sleep 5

for server_ip in $(scw instance server list tags.0=controller --output json | jq -r '.[].private_ip'); do
  scw lb backend add-servers $BACKEND_ID server-ip.0=$server_ip
done

echo -e "creating forwarding rules from load balancer to backend servers...\n\n"

scw lb frontend create \
  name=kube-frontend \
  inbound-port=443 \
  lb-id=$LOAD_BALANCER_ID \
  backend-id=$BACKEND_ID