controller_1_private_ip=$(scw ipam ip list resource-name=controller-1 is-ipv6=false --output json | jq -r '.[].address' | cut -d '/' -f 1)
controller_2_private_ip=$(scw ipam ip list resource-name=controller-2 is-ipv6=false --output json | jq -r '.[].address' | cut -d '/' -f 1)
controller_3_private_ip=$(scw ipam ip list resource-name=controller-3 is-ipv6=false --output json | jq -r '.[].address' | cut -d '/' -f 1)

tee private_ip_mappings <<EOF
  controller_1 "$controller_1_private_ip"
  controller_2 "$controller_2_private_ip"
  controller_3 "$controller_3_private_ip"
EOF

for instance in controller-1 controller-2 controller-3; do
  external_ip=$(scw instance server list \
    name=${instance} \
    --output json | jq -r '.[].public_ip.address')

  scp -i kubernetes.ed25519 \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    private_ip_mappings root@${external_ip}:~/

  ssh -i kubernetes.ed25519 \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@$external_ip < ./scripts/bootstrap_etcd_on_controllers.sh
done
