# Assignment 3: Configuration and Package Management

**Project:** DSO202 Three-Tier Task Tracker  
**Implementation:** Kustomize, Helm, and etcd workflow integration  
**Status:** Implemented and validated on the local kind cluster  

## Executive Summary

Assignment 1 originally used individually maintained Kubernetes YAML files. The concepts of Unit 4 support has been added without replacing those original manifests. The application can now be rendered and deployed through Kustomize overlays or installed and revised as a Helm release.

Kustomize provides environment-specific configuration through a reusable base, generators, and patches. Helm packages the same architecture as a parameterized chart and adds release history, upgrades, and rollback. Etcd remains an internal Kubernetes control-plane component; documentation explains how the objects produced by Kustomize and Helm are stored, inspected, protected, and backed up without making the application an etcd client.

## 1. Scope

The implementation covers:

- Kustomize base and overlay structure;
- ConfigMap and Secret generators;
- strategic merge and JSON patches;
- `kubectl kustomize` and `kubectl apply -k` workflows;
- a Helm application chart with values, templates, built-in objects, functions, and named helpers;
- local and advanced Helm profiles;
- Helm install, upgrade, history, rollback, and uninstall procedures;
- etcd architecture, read-only inspection, TLS, backup, restore boundaries, and monitoring guidance; and
- version-control practices for generated configuration and credentials.

The original manifests under `assignment-1/`, and the earlier advanced manifests under `assignment-1/advanced/`, remain available for comparison.

## 2. Kustomize Implementation

### 2.1 Base

`assignment-1/kustomize/base` defines the common application architecture:

- PostgreSQL StatefulSet with a `volumeClaimTemplates` PVC;
- headless database Service;
- backend Deployment and ClusterIP Service;
- frontend Deployment and ClusterIP Service;
- generated ConfigMap; and
- generated Secret.

The ConfigMap and Secret names receive content hashes. Kustomize automatically rewrites all workload references to the generated names. A configuration change therefore changes the referenced object name and triggers a workload rollout when applied.

**command:**

```bash
tree assignment-1/kustomize
```

![image](/assignment-3/screenshots/1.png)
>
> *Figure 1: Kustomize base-and-overlay directory structure.*

### 2.2 Local overlay

The local overlay creates resources in `dso202-unit4-local` and demonstrates:

- ConfigMap generator merging for the host-reachable backend URL;
- a strategic merge patch that changes the frontend Service to NodePort `30082`; and
- a JSON patch that adds backend CPU and memory requests and limits.

### 2.3 Advanced overlay

The advanced overlay creates resources in `dso202-unit4-advanced` and demonstrates:

- a strategic merge patch that scales the backend to two replicas;
- a JSON patch that adds frontend CPU and memory settings; and
- Traefik Ingress routes for `/` and `/api` using `unit4-task-tracker.local`.

**command:**

```bash
kubectl kustomize assignment-1/kustomize/overlays/advanced
```

![image](/assignment-3/screenshots/2.png)

> *Figure 2: Rendered Kustomize advanced overlay with generated and patched resources.*

**Actual Output from the `kubectl kustomize` command:**
```bash
sonamdorjighalley@SDGs-MacBook Assignments % kubectl kustomize assignment-1/kustomize/overlays/advanced
apiVersion: v1
kind: Namespace
metadata:
  name: dso202-unit4-advanced
---
apiVersion: v1
data:
  APP_PORT: "8080"
  BACKEND_URL: ""
  CORS_ORIGIN: '*'
  DB_HOST: db-svc
  DB_NAME: taskdb
  DB_PORT: "5432"
  POSTGRES_DB: taskdb
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: task-tracker
    app.kubernetes.io/part-of: task-tracker
  name: task-config-4925t9dk65
  namespace: dso202-unit4-advanced
---
apiVersion: v1
data:
  DB_PASSWORD: cmVwbGFjZS1iZWZvcmUtc2hhcmVkLXVzZQ==
  DB_USER: dW5pdDR1c2Vy
  POSTGRES_PASSWORD: cmVwbGFjZS1iZWZvcmUtc2hhcmVkLXVzZQ==
  POSTGRES_USER: dW5pdDR1c2Vy
kind: Secret
metadata:
  labels:
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: task-tracker
    app.kubernetes.io/part-of: task-tracker
  name: task-credentials-t49bh7f2hc
  namespace: dso202-unit4-advanced
type: Opaque
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: task-tracker
    tier: backend
  name: backend-svc
  namespace: dso202-unit4-advanced
spec:
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  selector:
    tier: backend
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: task-tracker
    tier: database
  name: db-svc
  namespace: dso202-unit4-advanced
spec:
  clusterIP: None
  ports:
  - name: postgres
    port: 5432
    targetPort: 5432
  selector:
    tier: database
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: task-tracker
    tier: frontend
  name: frontend-svc
  namespace: dso202-unit4-advanced
spec:
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  selector:
    tier: frontend
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: task-tracker
    tier: backend
  name: backend
  namespace: dso202-unit4-advanced
spec:
  replicas: 2
  selector:
    matchLabels:
      tier: backend
  template:
    metadata:
      labels:
        tier: backend
    spec:
      containers:
      - env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              key: DB_HOST
              name: task-config-4925t9dk65
        - name: DB_PORT
          valueFrom:
            configMapKeyRef:
              key: DB_PORT
              name: task-config-4925t9dk65
        - name: DB_NAME
          valueFrom:
            configMapKeyRef:
              key: DB_NAME
              name: task-config-4925t9dk65
        - name: APP_PORT
          valueFrom:
            configMapKeyRef:
              key: APP_PORT
              name: task-config-4925t9dk65
        - name: CORS_ORIGIN
          valueFrom:
            configMapKeyRef:
              key: CORS_ORIGIN
              name: task-config-4925t9dk65
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              key: DB_USER
              name: task-credentials-t49bh7f2hc
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              key: DB_PASSWORD
              name: task-credentials-t49bh7f2hc
        image: dso202-backend:v1
        imagePullPolicy: IfNotPresent
        name: backend
        ports:
        - containerPort: 8080
          name: http
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: task-tracker
    tier: frontend
  name: frontend
  namespace: dso202-unit4-advanced
spec:
  replicas: 1
  selector:
    matchLabels:
      tier: frontend
  template:
    metadata:
      labels:
        tier: frontend
    spec:
      containers:
      - env:
        - name: BACKEND_URL
          valueFrom:
            configMapKeyRef:
              key: BACKEND_URL
              name: task-config-4925t9dk65
        image: dso202-frontend:v1
        imagePullPolicy: IfNotPresent
        name: frontend
        ports:
        - containerPort: 8080
          name: http
        resources:
          limits:
            cpu: 250m
            memory: 256Mi
          requests:
            cpu: 50m
            memory: 64Mi
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  labels:
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: task-tracker
    tier: database
  name: db
  namespace: dso202-unit4-advanced
spec:
  replicas: 1
  selector:
    matchLabels:
      tier: database
  serviceName: db-svc
  template:
    metadata:
      labels:
        tier: database
    spec:
      containers:
      - env:
        - name: POSTGRES_DB
          valueFrom:
            configMapKeyRef:
              key: POSTGRES_DB
              name: task-config-4925t9dk65
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              key: POSTGRES_USER
              name: task-credentials-t49bh7f2hc
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              key: POSTGRES_PASSWORD
              name: task-credentials-t49bh7f2hc
        image: dso202-db:v1
        imagePullPolicy: IfNotPresent
        name: database
        ports:
        - containerPort: 5432
          name: postgres
        volumeMounts:
        - mountPath: /var/lib/postgresql/data
          name: db-storage
      terminationGracePeriodSeconds: 30
  volumeClaimTemplates:
  - metadata:
      labels:
        tier: database
      name: db-storage
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 1Gi
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
  name: task-tracker
  namespace: dso202-unit4-advanced
spec:
  ingressClassName: traefik
  rules:
  - host: unit4-task-tracker.local
    http:
      paths:
      - backend:
          service:
            name: backend-svc
            port:
              number: 8080
        path: /api
        pathType: Prefix
      - backend:
          service:
            name: frontend-svc
            port:
              number: 8080
        path: /
        pathType: Prefix

```


### 2.4 Kustomize commands

```bash
kubectl kustomize assignment-1/kustomize/overlays/local
kubectl kustomize assignment-1/kustomize/overlays/advanced

kubectl apply -k assignment-1/kustomize/overlays/local
kubectl apply -k assignment-1/kustomize/overlays/advanced
```

Both overlays rendered successfully with Kustomize `v5.8.1`. The advanced overlay was applied to the local kind cluster. Its PostgreSQL StatefulSet reached `1/1`, backend Deployment `2/2`, and frontend Deployment `1/1`; its persistent volume claim was bound. Validation also confirmed generated-name propagation, namespace transformation, Service type changes, replica patches, resource patches, and Ingress routing.

**Deployment evidence command:**

```bash
kubectl apply -k assignment-1/kustomize/overlays/advanced
```

![image](/assignment-3/screenshots/3.png)
> *Figure 3: Successful deployment of the advanced Kustomize overlay.*

**Workload and storage evidence command:**

```bash
kubectl get statefulset,deployment,pods,pvc \
  --namespace dso202-unit4-advanced
```

![image](/assignment-3/screenshots/4.png)
> *Figure 4: Healthy Kustomize workloads and bound persistent storage.*

**Ingress evidence command:**

```bash
kubectl describe ingress task-tracker \
  --namespace dso202-unit4-advanced
```

![image](/assignment-3/screenshots/5.png)
> *Figure 5: Traefik Ingress rules for frontend and backend traffic.*

## 3. Helm Implementation

### 3.1 Chart structure

The chart is located at `assignment-1/helm/task-tracker`:

```text
task-tracker/
├── Chart.yaml
├── values.yaml
├── values-local.yaml
├── values-advanced.yaml
└── templates/
    ├── _helpers.tpl
    ├── configmap.yaml
    ├── secret.yaml
    ├── db-statefulset.yaml
    ├── db-service.yaml
    ├── backend-deployment.yaml
    ├── backend-service.yaml
    ├── frontend-deployment.yaml
    ├── frontend-service.yaml
    ├── ingress.yaml
    └── NOTES.txt
```

**command:**

```bash
tree assignment-1/helm/task-tracker
```

![image](/assignment-3/screenshots/6.png)
> *Figure 6: Helm chart, values files, helpers, and templates.*

### 3.2 Templates and values

The chart uses:

- `.Values` for images, replicas, ports, persistence, resources, configuration, Services, and Ingress;
- `.Release` for release names, namespaces, instance labels, and operational notes;
- `.Chart` for chart and application version labels;
- `default`, `required`, `quote`, `include`, `dict`, `toYaml`, and `nindent` functions;
- named templates for names, labels, selectors, generated resource names, and Service names; and
- conditional templates for Secret creation and Ingress creation.

The default profile expects an existing Secret. This keeps credentials out of committed values files. Optional chart-managed Secret creation requires credentials to be supplied at command time.

**Chart validation command:**

```bash
helm lint assignment-1/helm/task-tracker
```

![image](/assignment-3/screenshots/7.png)
> *Figure 7: Successful Helm chart validation.*

### 3.3 Values profiles

| Profile | Frontend exposure | Backend replicas | Browser API address |
|---|---|---:|---|
| `values-local.yaml` | NodePort `30083` | 1 | `http://localhost:18086` |
| `values-advanced.yaml` | Traefik Ingress | 2 | Relative `/api` path |

**Release and workload evidence commands:**

```bash
helm list --namespace dso202-helm
kubectl get statefulset,deployment,pods,pvc,ingress \
  --namespace dso202-helm
```

![image](/assignment-3/screenshots/8.png)
> *Figure 8: Deployed Helm release with healthy workloads, storage, and Ingress.*

### 3.4 Release lifecycle

```bash
helm install task-tracker assignment-1/helm/task-tracker \
  --namespace dso202-helm --create-namespace \
  -f assignment-1/helm/task-tracker/values-advanced.yaml

helm upgrade task-tracker assignment-1/helm/task-tracker \
  --namespace dso202-helm \
  -f assignment-1/helm/task-tracker/values-advanced.yaml \
  --set backend.replicas=3

helm history task-tracker --namespace dso202-helm
helm rollback task-tracker 1 --namespace dso202-helm
```

Helm lint passed for the default and chart-created Secret modes. Template rendering passed for the local and advanced profiles using Helm `v4.3.0`. The advanced profile was installed as release `task-tracker`, upgraded from two to three backend replicas, and rolled back to revision 1. The rollback created revision 3 and restored the backend to two replicas, demonstrating release revision management rather than only documenting it.

**Revision-history evidence command:**

```bash
helm history task-tracker --namespace dso202-helm
```

![image](/assignment-3/screenshots/9.png)
> *Figure 9: Helm release history demonstrating upgrade and rollback.*

## 4. Etcd Integration

Kustomize does not write directly to etcd. Helm does not write directly to etcd. Both produce Kubernetes API objects:

```text
Git configuration
  -> Kustomize build or Helm render
  -> kube-apiserver
  -> authentication, authorization, validation, admission
  -> etcd stores desired state
  -> controllers reconcile actual state
```

Kubernetes Services and EndpointSlices are stored as API state in etcd. CoreDNS and cluster networking consume that state to provide service discovery. PostgreSQL, the backend, and the frontend continue to use Kubernetes Services rather than etcd endpoints.

`assignment-1/unit4/ETCD_OPERATIONS.md` documents read-only health and status commands, certificate-based access, snapshot creation, restore boundaries, monitoring indicators, and snapshot security. A live health check entered the etcd runtime container through the kind control-plane node and confirmed that the TLS endpoint successfully committed a proposal.

**Etcd health evidence commands:**

```bash
ETCD_CONTAINER=$(docker exec dso202-p2-control-plane \
  crictl ps --name etcd --quiet)

docker exec dso202-p2-control-plane \
  crictl exec "$ETCD_CONTAINER" etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health
```

![image](/assignment-3/screenshots/10.png)
> *Figure 10: Etcd endpoint health verified using mutual TLS.*

## 5. End-to-End Application Validation

The frontend and backend API were tested through Traefik. The following temporary port-forward exposes the Ingress Controller locally:

```bash
kubectl port-forward --namespace traefik service/traefik 18087:80
```

With the port-forward running, open a second terminal and test the application routes:

```bash
curl -i -H "Host: helm-task-tracker.local" \
  http://127.0.0.1:18087/

curl -i -H "Host: helm-task-tracker.local" \
  http://127.0.0.1:18087/api/tasks
```

![image](/assignment-3/screenshots/11.png)
> *Figure 11: Frontend responding successfully through Traefik Ingress.*

![image](/assignment-3/screenshots/12.png)
> *Figure 12: Backend API responding successfully through Traefik Ingress.*

For visual evidence, add `127.0.0.1 helm-task-tracker.local` to the local hosts file while the port-forward is active, open `http://helm-task-tracker.local:18087`, and replace Figure 11 with a browser screenshot of the working interface if preferred.

## 6. Version-Control Strategy

The project follows these configuration-management rules:

- bases contain reusable configuration;
- overlays contain environment differences only;
- Helm defaults remain non-secret and reusable;
- local Kustomize `secret.env` is ignored by Git;
- only `secret.env.example` is version controlled;
- passwords are not stored in Helm values files;
- image tags and Helm chart versions are pinned;
- rendered output is inspected but not committed as a second source of truth; and
- Kustomize overlays and Helm releases use separate namespaces to avoid ownership conflicts.

Kustomize and Helm should not manage the same live resources simultaneously. Each method is a complete alternative deployment workflow for demonstrating Unit 4 concepts.

## 7. Validation Summary

| Validation | Result |
|---|---|
| Kustomize local overlay render | Passed |
| Kustomize advanced overlay render | Passed |
| Kustomize advanced overlay deployment | Passed |
| Kustomize StatefulSet, Deployments, and PVC readiness | Passed |
| Generated ConfigMap/Secret references | Passed |
| Strategic merge patches | Passed |
| JSON patches | Passed |
| Helm lint with existing Secret mode | Passed |
| Helm lint with chart-created Secret mode | Passed |
| Helm local profile render | Passed |
| Helm advanced profile render | Passed |
| Helm install and workload readiness | Passed |
| Helm upgrade, history, and rollback | Passed |
| Kustomize Ingress frontend and `/api` routes | HTTP 200 |
| Helm Ingress frontend and `/api` routes | HTTP 200 |
| Etcd mutual-TLS endpoint health | Passed |
| Credential file ignored by Git | Passed |
| Tracked-file plaintext credential scan | Passed |

## 8. Concept Traceability

| Unit 4 topic | Project evidence |
|---|---|
| Kustomization structure | Base and two overlay `kustomization.yaml` files |
| Bases and overlays | `kustomize/base`, `overlays/local`, `overlays/advanced` |
| Resources and patches | Workload resources plus overlay patch files |
| ConfigMap generator | `task-config` generator and overlay merge |
| Secret generator | Ignored `secret.env` input and `task-credentials` generator |
| Strategic merge patch | Frontend NodePort and backend replica patches |
| JSON patch | Backend and frontend resource additions |
| `kubectl apply -k` | Documented deployment workflow |
| Viewing Kustomize output | Documented `kubectl kustomize` workflow |
| Helm chart structure | `Chart.yaml`, values, templates, notes |
| Go templates | Parameterized Kubernetes manifests |
| Built-in objects and functions | `.Values`, `.Release`, `.Chart`, helper functions |
| Named templates | `_helpers.tpl` |
| Install, upgrade, rollback | Documented release lifecycle |
| Release revisions | `helm history` workflow |
| Etcd cluster state | API-server-to-etcd architecture documentation |
| `etcdctl` | TLS-authenticated read-only commands |
| Backup and restore | Snapshot procedure and restore boundary |
| Etcd monitoring and security | Health indicators, TLS, access and snapshot guidance |

## 9. Conclusion

Assignment 1 can now demonstrate Unit 4 through two complete configuration-management approaches. Kustomize emphasizes reusable YAML with environment overlays and patches. Helm emphasizes packaging, values, templating, and managed release revisions. Etcd is correctly treated as protected control-plane storage rather than an application configuration database.
