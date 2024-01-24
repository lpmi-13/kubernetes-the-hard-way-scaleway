for instance in worker-1 worker-2 worker-3; do
  external_ip=$(scw instance server list \
    name=${instance} \
    --output json | jq -r '.[].public_ip.address')

  ssh -i kubernetes.ed25519 \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@$external_ip < ./scripts/bootstrap_workers.sh
done

echo "waiting 60 seconds before checking worker status"
sleep 60

external_ip=$(scw instance server list \
  name=controller-1 \
  --output json | jq -r '.[].public_ip.address')

ssh -i kubernetes.ed25519 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  root@$external_ip "kubectl get nodes --kubeconfig admin.kubeconfig"
