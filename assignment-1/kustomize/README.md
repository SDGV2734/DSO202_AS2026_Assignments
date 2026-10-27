# Kustomize deployment

This directory packages the Task Tracker using one reusable base and two overlays.

## Prepare local credentials

`base/secret.env` is intentionally ignored by Git. Create it from the example and replace every placeholder before deploying:

```bash
cp kustomize/base/secret.env.example kustomize/base/secret.env
```

The backend and PostgreSQL values must match:

```text
DB_USER=POSTGRES_USER
DB_PASSWORD=POSTGRES_PASSWORD
```

## Render without changing the cluster

```bash
kubectl kustomize kustomize/overlays/local
kubectl kustomize kustomize/overlays/advanced
```

Generated ConfigMap and Secret names include a content hash. Kustomize also updates workload references to those generated names.

## Apply an overlay

```bash
kubectl apply -k kustomize/overlays/local
# or
kubectl apply -k kustomize/overlays/advanced
```

The local overlay demonstrates a strategic merge patch by changing `frontend-svc` to NodePort `30082`. It also uses a JSON patch to add backend resource requests and limits. Run the local services with port-forwarding when the kind cluster has no matching host port mapping:

```bash
kubectl port-forward -n dso202-unit4-local svc/frontend-svc 18083:8080
kubectl port-forward -n dso202-unit4-local svc/backend-svc 18084:8080
```

The advanced overlay keeps both application Services internal, scales the backend to two replicas through a strategic merge patch, adds frontend resources through a JSON patch, and routes `/` and `/api` through Traefik Ingress.

## Remove an overlay

```bash
kubectl delete -k kustomize/overlays/local
kubectl delete -k kustomize/overlays/advanced
```
