for server_id in $(scw instance server list --output json | jq -r '.[].id'); do
  scw instance server terminate ${server_id}
done

LOCAL_PRIVATE_SSH_KEY=kubernetes.ed25519
if [ -f "$LOCAL_PRIVATE_SSH_KEY" ]; then
  echo "deleting local private ssh key previously generated"
  rm -rf kubernetes.ed25519
else
  echo "no local private key found"
fi

LOCAL_PUBLIC_SSH_KEY=kubernetes.ed25519.pub
if [ -f "$LOCAL_PUBLIC_SSH_KEY" ]; then
  echo "deleting local public ssh key previously generated"
  rm -rf kubernetes.ed25519.pub
else
  echo "no local public key found"
fi

for load_balancer_id in $(scw lb lb list --output json | jq -r '.[].id'); do
  scw lb lb delete $load_balancer_id
done

echo "waiting 10 seconds for the security group associations to clear out..."
sleep 10

for security_group in $(scw instance security-group list project-default=false --output json | jq -r '.[].id'); do
  scw instance security-group delete $security_group
done

echo "waiting 5 seconds for all VPC resources to be cleaned up..."
sleep 5

VPC_ID=$(scw vpc vpc list name=kubernetes --output json | jq -r '.[].id')

scw vpc vpc delete $VPC_ID

echo "cleaning up local *.{csr,json,kubeconfig,pem,yaml} files"
rm -rf ./*.{csr,json,kubeconfig,pem,yaml}
