# Smoke Test

In this lab you will complete a series of tasks to ensure your Kubernetes cluster is functioning correctly.

## Data Encryption

In this section you will verify the ability to [encrypt secret data at rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#verifying-that-data-is-encrypted).

Create a generic secret:

```sh
kubectl create secret generic kubernetes-the-hard-way --from-literal="mykey=mydata"
```

Print a hexdump of the `kubernetes-the-hard-way` secret stored in etcd:

```sh
external_ip=$(scw instance server list \
  name=controller-1 \
  --output json | jq -r '.[].public_ip.address')

ssh -i kubernetes.ed25519 root@${external_ip}
```
Run below command in controller-1

```sh
sudo ETCDCTL_API=3 etcdctl get \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem \
  /registry/secrets/default/kubernetes-the-hard-way | hexdump -C
```

> output

```sh
00000000  2f 72 65 67 69 73 74 72  79 2f 73 65 63 72 65 74  |/registry/secret|
00000010  73 2f 64 65 66 61 75 6c  74 2f 6b 75 62 65 72 6e  |s/default/kubern|
00000020  65 74 65 73 2d 74 68 65  2d 68 61 72 64 2d 77 61  |etes-the-hard-wa|
00000030  79 0a 6b 38 73 3a 65 6e  63 3a 61 65 73 63 62 63  |y.k8s:enc:aescbc|
00000040  3a 76 31 3a 6b 65 79 31  3a 7b 8e 59 78 0f 59 09  |:v1:key1:{.Yx.Y.|
00000050  e2 6a ce cd f4 b6 4e ec  bc 91 aa 87 06 29 39 8d  |.j....N......)9.|
00000060  70 e8 5d c4 b1 66 69 49  60 8f c0 cc 55 d3 69 2b  |p.]..fiI`...U.i+|
00000070  49 bb 0e 7b 90 10 b0 85  5b b1 e2 c6 33 b6 b7 31  |I..{....[...3..1|
00000080  25 99 a1 60 8f 40 a9 e5  55 8c 0f 26 ae 76 dc 5b  |%..`.@..U..&.v.[|
00000090  78 35 f5 3e c1 1e bc 21  bb 30 e2 0c e3 80 1e 33  |x5.>...!.0.....3|
000000a0  90 79 46 6d 23 d8 f9 a2  d7 5d ed 4d 82 2e 9a 5e  |.yFm#....].M...^|
000000b0  5d b6 3c 34 37 51 4b 83  de 99 1a ea 0f 2f 7c 9b  |].<47QK....../|.|
000000c0  46 15 93 aa ba 72 ba b9  bd e1 a3 c0 45 90 b1 de  |F....r......E...|
000000d0  c4 2e c8 d0 94 ec 25 69  7b af 08 34 93 12 3d 1c  |......%i{..4..=.|
000000e0  fd 23 9b ba e8 d1 25 56  f4 0a                    |.#....%V..|
000000ea
```

The etcd key should be prefixed with `k8s:enc:aescbc:v1:key1`, which indicates the `aescbc` provider was used to encrypt the data with the `key1` encryption key.

## Deployments  - To be run on local laptop

In this section you will verify the ability to create and manage [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/).

Create a deployment for the [nginx](https://nginx.org/en/) web server:

```sh
kubectl create deployment nginx --image=nginx
```

List the pod created by the `nginx` deployment:

```sh
kubectl get pods -l app=nginx
```

> output

```sh
NAME                     READY     STATUS    RESTARTS   AGE
nginx-65899c769f-xkfcn   1/1       Running   0          15s
```

### Port Forwarding

In this section you will verify the ability to access applications remotely using [port forwarding](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/).

Retrieve the full name of the `nginx` pod:

```sh
POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}")
```

Forward port `8080` on your local machine to port `80` of the `nginx` pod:

```sh
kubectl port-forward $POD_NAME 8080:80
```

> output

```sh
Forwarding from 127.0.0.1:8080 -> 80
Forwarding from [::1]:8080 -> 80
``` 
In a new terminal make an HTTP request using the forwarding address:

```sh
curl --head http://127.0.0.1:8080
```

> output

```sh
HTTP/1.1 200 OK
Server: nginx/1.25.3
Date: Wed, 24 Jan 2024 23:07:06 GMT
Content-Type: text/html
Content-Length: 615
Last-Modified: Tue, 24 Oct 2023 13:46:47 GMT
Connection: keep-alive
ETag: "6537cac7-267"
Accept-Ranges: bytes
```

Switch back to the previous terminal and stop the port forwarding to the `nginx` pod:

```sh
Forwarding from 127.0.0.1:8080 -> 80
Forwarding from [::1]:8080 -> 80
Handling connection for 8080
^C
```

### Logs

In this section you will verify the ability to [retrieve container logs](https://kubernetes.io/docs/concepts/cluster-administration/logging/).

Print the `nginx` pod logs:

```sh
kubectl logs $POD_NAME
```

> output

```sh
127.0.0.1 - - [24/Jan/2024:23:07:06 +0000] "HEAD / HTTP/1.1" 200 0 "-" "curl/7.68.0" "-"
```

### Exec

In this section you will verify the ability to [execute commands in a container](https://kubernetes.io/docs/tasks/debug-application-cluster/get-shell-running-container/#running-individual-commands-in-a-container).
Print the nginx version by executing the `nginx -v` command in the `nginx` container:

```sh
kubectl exec -ti $POD_NAME -- nginx -v
```

> output

```sh
nginx version: nginx/1.25.3
```

## Services

In this section you will verify the ability to expose applications using a [Service](https://kubernetes.io/docs/concepts/services-networking/service/).

Expose the `nginx` deployment using a [NodePort](https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport) service:

```sh
kubectl expose deployment nginx --port 80 --type NodePort
```

> The LoadBalancer service type can not be used because your cluster is not configured with [cloud provider integration](https://kubernetes.io/docs/getting-started-guides/scratch/#cloud-provider). Setting up cloud provider integration is out of scope for this tutorial.

Retrieve the node port assigned to the `nginx` service:

```sh
NODE_PORT=$(kubectl get svc nginx \
  --output=jsonpath='{range .spec.ports[0]}{.nodePort}')
```

Create a firewall rule that allows remote access to the `nginx` node port:

```sh
WORKER_SECURITY_GROUP=$(scw instance security-group list \
  name=worker-ingress \
  --output json | jq -r '.[].id')

scw instance security-group create-rule \
  security-group-id=$WORKER_SECURITY_GROUP \
  protocol=TCP \
  direction=inbound \
  action=accept \
  dest-port-from=$NODE_PORT \
  dest-port-to=$NODE_PORT
```

Retrieve the external IP address of a worker instance:

```sh
INSTANCE_NAME=$(kubectl get pod $POD_NAME --output=jsonpath='{.spec.nodeName}')
EXTERNAL_IP=$(scw instance server list \
  name=$INSTANCE_NAME \
  --output json | jq -r '.[].public_ip.address')
```

Make an HTTP request using the external IP address and the `nginx` node port:

```sh
curl -I http://${EXTERNAL_IP}:${NODE_PORT}
```

> output

```sh
HTTP/1.1 200 OK
Server: nginx/1.25.3
Date: Wed, 24 Jan 2024 23:21:55 GMT
Content-Type: text/html
Content-Length: 615
Last-Modified: Tue, 24 Oct 2023 13:46:47 GMT
Connection: keep-alive
ETag: "6537cac7-267"
Accept-Ranges: bytes
```

# Check images/pods/containers on worker nodes using crictl

Log in to a worker node. You can do this on all 3 workers to see the resources on each of them:

```sh
external_ip=$(scw instance server list \
  name=worker-1 \
  --output json | jq -r '.[].public_ip.address')

ssh -i kubernetes.ed25519 root@${external_ip}
```
Run the following commands and check output

```sh
sudo crictl -r unix:///var/run/containerd/containerd.sock images
```

Output
```sh
IMAGE                       TAG                 IMAGE ID            SIZE
docker.io/library/busybox   1.28.4              8c811b4aec35f       728kB
docker.io/library/nginx     latest              f652ca386ed13       56.7MB
k8s.gcr.io/pause            3.1                 da86e6ba6ca19       317kB
```

```sh
sudo crictl -r unix:///var/run/containerd/containerd.sock pods
```

Output
```sh
POD ID              CREATED             STATE               NAME                     NAMESPACE           ATTEMPT
5a0f7e5e51bc3       14 minutes ago      Ready               nginx-86c57db685-hlkhs   default             0
edd820ca15374       23 minutes ago      Ready               busybox                  default             0
```

```sh
sudo crictl -r unix:///var/run/containerd/containerd.sock ps
```

Output
```sh
CONTAINER           IMAGE               CREATED             STATE               NAME                ATTEMPT             POD ID
cdb2d7f5e0694       f652ca386ed13       15 minutes ago      Running             nginx               0                   5a0f7e5e51bc3
2949f174a3364       8c811b4aec35f       24 minutes ago      Running             busybox             0                   edd820ca15374
```

Next: [Cleaning Up](14-cleanup.md)
