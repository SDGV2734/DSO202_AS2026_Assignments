# Helm deployment

This chart packages the database StatefulSet, backend, frontend, Services, configuration, optional Secret, and optional Ingress as one Helm release.

## Validate and inspect templates

```bash
helm lint helm/task-tracker
helm template task-tracker helm/task-tracker \
  --namespace dso202-helm \
  -f helm/task-tracker/values-advanced.yaml
```

## Prepare credentials

The default chart expects an existing Secret so credentials do not appear in a committed values file:

```bash
kubectl create namespace dso202-helm
kubectl create secret generic task-tracker-credentials \
  --namespace dso202-helm \
  --from-literal=DB_USER='<user>' \
  --from-literal=DB_PASSWORD='<password>' \
  --from-literal=POSTGRES_USER='<same-user>' \
  --from-literal=POSTGRES_PASSWORD='<same-password>'
```

Alternatively, the chart can create the Secret when values are supplied only at command time:

```bash
helm install task-tracker helm/task-tracker \
  --namespace dso202-helm --create-namespace \
  -f helm/task-tracker/values-advanced.yaml \
  --set credentials.create=true \
  --set-string credentials.username='<user>' \
  --set-string credentials.password='<password>'
```

Avoid placing these values in shell history on shared systems; use a protected values source in real deployments.

## Install

```bash
helm install task-tracker helm/task-tracker \
  --namespace dso202-helm \
  -f helm/task-tracker/values-advanced.yaml
```

Use `values-local.yaml` instead to disable Ingress and expose the frontend as NodePort `30083`.

## Upgrade and inspect revisions

```bash
helm upgrade task-tracker helm/task-tracker \
  --namespace dso202-helm \
  -f helm/task-tracker/values-advanced.yaml \
  --set backend.replicas=3

helm history task-tracker --namespace dso202-helm
```

## Roll back

```bash
helm rollback task-tracker 1 --namespace dso202-helm
helm history task-tracker --namespace dso202-helm
```

## Uninstall

```bash
helm uninstall task-tracker --namespace dso202-helm
```

StatefulSet PVCs are intentionally retained by Kubernetes after release deletion. Review and remove retained claims separately only when their data is no longer required.
