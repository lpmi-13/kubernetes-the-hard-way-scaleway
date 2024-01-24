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

# now we ssh in and add associations to each worker for the _other two_ workers
ssh -i kubernetes.ed25519 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  root@$worker_1_public_ip -C "ip route add 10.200.2.0/24 via $worker_2_private_ip;ip route add 10.200.3.0/24 via $worker_3_private_ip"

ssh -i kubernetes.ed25519 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  root@$worker_2_public_ip -C "ip route add 10.200.1.0/24 via $worker_1_private_ip;ip route add 10.200.3.0/24 via $worker_3_private_ip"

ssh -i kubernetes.ed25519 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  root@$worker_3_public_ip -C "ip route add 10.200.1.0/24 via $worker_1_private_ip;ip route add 10.200.2.0/24 via $worker_2_private_ip"


cat > scripts/update_dns.sh <<FIN
cat <<EOF | sudo tee -a /etc/hosts
$worker_1_private_ip worker-1
$worker_2_private_ip worker-2
$worker_3_private_ip worker-3
EOF
FIN

for instance in controller-1 controller-2 controller-3; do
  external_ip=$(scw instance server list \
    name=${instance} \
    --output json | jq -r '.[].public_ip.address')

  ssh -i kubernetes.ed25519 \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@$external_ip < ./scripts/update_dns.sh
done
