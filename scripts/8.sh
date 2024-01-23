# this runs a local script on the remote controllers to bootstrap the control plane
for instance in controller-1 controller-2 controller-3; do
  external_ip=$(scw instance server list \
    name=${instance} \
    --output json | jq -r '.[].public_ip.address')

  ssh -i kubernetes.ed25519 \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@$external_ip < ./scripts/bootstrap_control_plane.sh
done

echo "waiting 30 seconds for etcd to be fully initialized..."
sleep 30

for instance in controller-1; do
  external_ip=$(scw instance server list \
    name=${instance} \
    --output json | jq -r '.[].public_ip.address')

  ssh -i kubernetes.ed25519 \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@$external_ip "kubectl get componentstatus"
done

echo "setting up RBAC from controller-1"

external_ip=$(scw instance server list \
  name=controller-1 \
  --output json | jq -r '.[].public_ip.address')

ssh -i kubernetes.ed25519 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  root@$external_ip < ./scripts/set_up_rbac.sh

KUBERNETES_PUBLIC_ADDRESS=$(scw lb ip list \
  --output json | jq -r '.[] | select(.ip_address | contains(".")).ip_address')

curl -k --cacert ca.pem https://${KUBERNETES_PUBLIC_ADDRESS}/version

