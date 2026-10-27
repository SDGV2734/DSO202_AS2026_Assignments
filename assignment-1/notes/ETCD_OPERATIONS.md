# Etcd Operations for the Task Tracker Cluster

## Purpose

Etcd is the strongly consistent distributed key-value store used by the Kubernetes control plane. The Task Tracker does not connect to etcd directly. `kubectl`, Kustomize, and Helm submit Kubernetes objects to the API server; after validation and admission, the API server stores the resulting cluster state in etcd.

```text
Kustomize or Helm
  -> kube-apiserver
  -> validation and admission
  -> etcd
  -> controllers and scheduler
  -> workloads on nodes
```

Application configuration remains in ConfigMaps and Secrets. Direct application access to etcd would bypass Kubernetes API validation, authorization, versioning, and reconciliation.

## Etcd and service discovery

Etcd stores Service, Pod, and EndpointSlice objects as cluster state. CoreDNS watches the Kubernetes API and turns that state into DNS records. Application Pods therefore use Service names such as `task-tracker-db`; they do not query etcd.

## Read-only inspection in kind

First identify the control-plane container:

```bash
docker ps --filter label=io.x-k8s.kind.role=control-plane \
  --format '{{.Names}}'
```

For the `dso202-p2` cluster, the expected node container is `dso202-p2-control-plane`. Locate the etcd runtime container inside that node:

```bash
ETCD_CONTAINER=$(docker exec dso202-p2-control-plane \
  crictl ps --name etcd --quiet)
```

Check endpoint health through mutual TLS:

```bash
docker exec dso202-p2-control-plane crictl exec "$ETCD_CONTAINER" etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health
```

Display endpoint status and Raft information:

```bash
docker exec dso202-p2-control-plane crictl exec "$ETCD_CONTAINER" etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint status --write-out=table
```

List cluster members:

```bash
docker exec dso202-p2-control-plane crictl exec "$ETCD_CONTAINER" etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list --write-out=table
```

These commands inspect control-plane health without reading or modifying application keys.

## Snapshot backup procedure

Create a snapshot in the etcd data directory, which is mounted from the control-plane node:

```bash
docker exec dso202-p2-control-plane crictl exec "$ETCD_CONTAINER" etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /var/lib/etcd/etcd-snapshot.db
```

Verify the snapshot before copying it out:

```bash
docker exec dso202-p2-control-plane crictl exec "$ETCD_CONTAINER" etcdutl \
  snapshot status /var/lib/etcd/etcd-snapshot.db --write-out=table

docker cp dso202-p2-control-plane:/var/lib/etcd/etcd-snapshot.db \
  ./etcd-snapshot.db
```

Store snapshots outside the Git repository because they can contain Secret data and complete cluster state.

## Restore boundary

Restoring etcd replaces cluster state and requires stopping or reconfiguring control-plane components. It is intentionally not automated in this project. A restore should be performed only in an isolated recovery exercise with a verified snapshot, matching etcd tooling, and a documented rollback plan.

## Security considerations

- Etcd listens on a TLS-protected endpoint in the kind control plane.
- Client certificates authenticate control-plane access.
- Kubernetes RBAC protects the API layer; direct etcd access bypasses Kubernetes RBAC.
- Etcd access must remain limited to cluster administrators and control-plane components.
- Snapshots must be protected as sensitive data because they may contain Kubernetes Secrets.
- Application Pods should use ConfigMaps and Secrets instead of etcd credentials.

## Monitoring indicators

For this local cluster, useful checks include endpoint health, database size, current Raft leader, Raft term, and applied index. Production monitoring should additionally alert on leader changes, slow requests, failed proposals, disk latency, space quota, and snapshot age.
