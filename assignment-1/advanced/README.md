# Advanced Kubernetes version

This directory is an optional extension of the assignment deployment. The original manifests remain unchanged for marking compatibility.

## What was added

1. `db-statefulset.yaml` replaces the database Deployment with a one-replica StatefulSet.
   - `serviceName: db-svc` connects it to the headless database Service.
   - The database Pod has the stable identity `db-0`.
   - `volumeClaimTemplates` creates and binds the `db-storage-db-0` PVC.
   - PostgreSQL data is mounted at `/var/lib/postgresql/data`.

2. `ingress.yaml` exposes one HTTP entry point.
   - `/api` routes to `backend-svc`.
   - `/` routes to `frontend-svc`.
   - The host used for local testing is `task-tracker.local`.

3. `traefik-values.yaml` configures the official Traefik Helm chart to expose its HTTP entry point on NodePort `30081`; the original assignment frontend already uses `30080`.

## Apply in stages

```bash
cd assignment-1

# Stage 1: namespace and shared configuration
kubectl apply -f advanced/namespace.yaml
kubectl apply -f advanced/configmap.yaml
kubectl apply -f advanced/secret.yaml

# Stage 2: database StatefulSet and headless Service
kubectl apply -f advanced/db-service.yaml
kubectl apply -f advanced/db-statefulset.yaml
kubectl -n dso202-advanced rollout status statefulset/db

# Stage 3: backend and frontend Services/Deployments
kubectl apply -f advanced/backend-service.yaml
kubectl apply -f advanced/backend-deployment.yaml
kubectl apply -f advanced/frontend-service.yaml
kubectl apply -f advanced/frontend-deployment.yaml
kubectl -n dso202-advanced rollout status deployment/backend
kubectl -n dso202-advanced rollout status deployment/frontend

# Stage 4: install Traefik once per cluster
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm upgrade --install traefik traefik/traefik \
  --namespace traefik --create-namespace \
  --version 41.6.1 \
  -f advanced/traefik-values.yaml

# Stage 5: route traffic through Ingress
kubectl apply -f advanced/ingress.yaml
```

For local testing, add `127.0.0.1 task-tracker.local` to `/etc/hosts`, then open `http://task-tracker.local:30081`. The Traefik NodePort must be reachable from the kind cluster; otherwise use `kubectl port-forward -n traefik svc/traefik 8080:80` and open `http://task-tracker.local:8080`.

## Verification

```bash
kubectl get statefulset,pods,pvc,svc -n dso202-advanced
kubectl get ingress -n dso202-advanced
kubectl describe ingress task-tracker -n dso202-advanced
kubectl exec -n dso202-advanced db-0 -- hostname
```

The last command should print `db-0`, demonstrating the stable StatefulSet identity.
