# Assignment 2: Kubernetes Improvement Report

## Executive Summary

The original project successfully deployed a three-tier task-tracking application to Kubernetes using Deployments, Services, a standalone PersistentVolumeClaim (PVC), ConfigMaps, Secrets, and namespace resource controls. It met the original assignment requirements, but two architectural limitations remained:

1. PostgreSQL was managed by a generic Deployment, which did not provide a stable Pod identity or workload-managed storage claims.
2. The browser received the internal address `http://backend-svc:8080`. That address is resolvable inside Kubernetes but not from a browser running on the host machine, so the user interface could not communicate directly with the backend.

An optional advanced deployment was added under `assignment-1/advanced/`. It preserves the original submission while introducing the two improvements most relevant to this application:

- a PostgreSQL StatefulSet connected to a headless Service and using `volumeClaimTemplates`; and
- a Traefik Ingress that exposes one browser-facing endpoint and routes `/api` traffic to the backend while routing all other requests to the frontend.

The advanced deployment was applied to a local `kind` cluster and verified successfully. The database Pod started as `db-0`, its generated PVC reached `Bound`, the frontend and backend became available, and requests through Ingress returned a healthy database connection.

## 1. Scope and Objectives

The work focused on Kubernetes concepts that materially improve this application. The following objectives guided the implementation:

- provide PostgreSQL with a stable workload identity;
- manage database storage through the workload definition;
- preserve database isolation behind an internal Service;
- provide a single HTTP entry point for the browser;
- remove the browser's dependency on Kubernetes-only DNS names;
- retain the original assignment manifests without modification; and
- document a repeatable deployment and verification procedure.

Custom Operators, Custom Resource Definitions, application-specific RBAC, TLS termination, and multi-host routing were excluded. They would add operational complexity without solving a current project requirement.

## 2. Original Architecture

The original deployment uses the namespace `dso202-assignment-01` and the following request path:

```text
Browser
  -> frontend-svc (NodePort 30080)
  -> Frontend Deployment
  -> backend-svc (ClusterIP 8080)
  -> Backend Deployment
  -> db-svc (headless Service 5432)
  -> Database Deployment
  -> standalone db-pvc
```

### 2.1 Original database model

PostgreSQL runs as a one-replica Deployment. The Deployment mounts the separately declared `db-pvc` at `/var/lib/postgresql/data`. This provides persistence, but the Deployment controller treats the database Pod as interchangeable and gives each recreated Pod a generated name.

### 2.2 Original external access model

The frontend is exposed through NodePort `30080`, while the backend remains correctly isolated behind a ClusterIP Service. The frontend configuration injects `http://backend-svc:8080` into browser-side JavaScript. Because `backend-svc` is a Kubernetes DNS name, a browser outside the cluster cannot resolve it.

### 2.3 Existing strengths retained

The modernization keeps the following sound design choices:

- separate frontend, backend, and database tiers;
- ConfigMap and Secret separation;
- an internal-only backend Service;
- a headless database Service;
- PostgreSQL data stored outside the container filesystem;
- consistent `tier` labels; and
- pinned application image tags with `IfNotPresent` pull behavior.

## 3. Implemented Architecture

The advanced deployment uses the namespace `dso202-advanced` and introduces this request path:

```text
Browser
  -> Traefik Ingress (task-tracker.local)
     |-> /api/* -> backend-svc -> Backend Deployment
     `-> /*     -> frontend-svc -> Frontend Deployment

Backend Deployment
  -> db-svc (headless Service)
  -> PostgreSQL StatefulSet Pod db-0
  -> generated PVC db-storage-db-0
```

The advanced resources are isolated from the original assignment resources. Both versions can therefore run in the same cluster for comparison.

## 4. Changes and Improvements

### 4.1 Database Deployment replaced with a StatefulSet

**Original:** `kind: Deployment`, with a separate `db-pvc`.  
**Advanced:** `kind: StatefulSet`, with `serviceName: db-svc` and an embedded `volumeClaimTemplates` definition.

The StatefulSet creates the database Pod with the predictable identity `db-0`. This makes the workload identity stable across Pod replacement and expresses that the Pod is a stateful member rather than an interchangeable stateless replica.

The StatefulSet remains at one replica because this project runs a single PostgreSQL instance. Increasing the replica count would create additional independent PostgreSQL instances; database replication requires PostgreSQL-specific configuration and cannot be achieved safely by changing only `replicas`.

### 4.2 Standalone PVC replaced with a volume claim template

**Original:** the database Deployment references the manually created claim `db-pvc`.  
**Advanced:** the StatefulSet generates `db-storage-db-0` from `volumeClaimTemplates`.

This places the storage lifecycle definition beside the stateful workload. Kubernetes associates the generated claim with the StatefulSet Pod identity, reducing manual coupling between an independently named PVC and the workload manifest. The storage request remains `1Gi` with `ReadWriteOnce` access, matching the original project's needs.

### 4.3 Headless Service integrated with the StatefulSet

The original `clusterIP: None` database pattern was retained and connected directly to the StatefulSet through `serviceName: db-svc`. The backend continues to use `DB_HOST=db-svc`, so application code does not depend on Pod IP addresses.

This change combines two complementary features:

- the headless Service provides Kubernetes DNS discovery; and
- the StatefulSet provides stable Pod identity and ordered lifecycle behavior.

### 4.4 Ingress added as the single HTTP entry point

A `networking.k8s.io/v1` Ingress named `task-tracker` was added with `ingressClassName: traefik`. It defines two prefix routes:

| Incoming path | Destination | Purpose |
|---|---|---|
| `/api` | `backend-svc:8080` | REST API and health requests |
| `/` | `frontend-svc:8080` | Static frontend application |

The frontend and backend Services remain ClusterIP Services in the advanced namespace. Traefik is the only component responsible for external HTTP routing, which centralizes access control and avoids exposing each application tier separately.

### 4.5 Browser API addressing corrected

The advanced ConfigMap sets `BACKEND_URL` to an empty value. The existing frontend code then produces relative URLs such as `/api/tasks` and `/api/status`.

Relative URLs send API requests back to the same host and port that served the frontend. Ingress receives those requests and routes `/api` to the backend. This removes the browser's dependency on the internal `backend-svc` DNS name and allows the user interface and API to share one origin.

This also reduces CORS complexity because the frontend and API are accessed through the same browser origin. The backend's existing CORS setting was retained for compatibility, but it can be restricted in a later security-hardening phase.

### 4.6 Traefik Ingress Controller installed

The official Traefik Helm chart was pinned to chart version `41.6.1`, which deployed Traefik Proxy `v3.7.13`. The chart creates the controller Deployment, IngressClass, ServiceAccount, ClusterRole, and ClusterRoleBinding required for Traefik to observe and implement Ingress resources.

Traefik is configured as a NodePort Service, and its HTTP entry point uses NodePort `30081`. NodePort `30080` was already allocated to the original frontend Service, so selecting `30081` allowed both deployments to coexist without a port conflict.

### 4.7 Dedicated namespace and configuration

The advanced version uses `dso202-advanced`, `dso202-advanced-config`, and `dso202-advanced-secret`. This isolation prevents naming collisions and allows the original and advanced architectures to run simultaneously.

Credentials remain stored as Kubernetes Secret data. Their decoded values are intentionally omitted from this report.

## 5. Before-and-After Comparison

| Area | Original implementation | Advanced implementation | Improvement |
|---|---|---|---|
| Database controller | Deployment | StatefulSet | Stable stateful identity and ordered lifecycle |
| Database Pod name | Generated Deployment name | `db-0` | Predictable identity across recreation |
| Persistent claim | Separate `db-pvc` manifest | `db-storage-db-0` generated from template | Storage definition follows the stateful workload |
| Database discovery | Headless `db-svc` | Headless `db-svc` linked through `serviceName` | Service and StatefulSet operate as one stateful pattern |
| Frontend exposure | Direct NodePort | ClusterIP behind Ingress | Centralized HTTP entry point |
| Backend exposure | Internal ClusterIP | Internal ClusterIP behind `/api` route | Backend remains isolated while becoming browser-accessible through Ingress |
| Browser backend address | `http://backend-svc:8080` | Relative `/api` path | Removes external dependency on cluster DNS |
| Routing | Separate Service access | Host and path-based Ingress routing | One coherent application URL |
| Deployment isolation | Assignment namespace | Separate advanced namespace | Original submission remains unaffected |

## 6. Validation and Results

The advanced deployment was validated on a three-node local `kind` cluster running Kubernetes `v1.36.1`.

### 6.1 Workload and storage validation

The following conditions were observed after deployment:

| Resource | Observed result |
|---|---|
| StatefulSet `db` | `1/1` ready |
| Database Pod | `db-0`, `1/1 Running` |
| Backend Pod | `1/1 Running` |
| Frontend Pod | `1/1 Running` |
| PVC `db-storage-db-0` | `Bound`, `1Gi`, `ReadWriteOnce` |
| Traefik Deployment | `1/1` available |
| IngressClass | `traefik` registered |
| Ingress | `task-tracker`, host `task-tracker.local`, port 80 |

Running the following command returned `db-0`, confirming the stable StatefulSet identity:

```bash
kubectl exec -n dso202-advanced db-0 -- hostname
```

### 6.2 Routing validation

Traefik was temporarily port-forwarded for a host-independent test. Requests included `Host: task-tracker.local` so they matched the Ingress rule.

```bash
curl -H 'Host: task-tracker.local' http://127.0.0.1:18082/api/status
```

Observed API response:

```json
{"status":"ok","db":"connected"}
```

A request to `/` returned HTTP `200`, confirming that the frontend route and backend route both worked through the same Ingress.

## 7. Deployment Procedure

The advanced version should be applied in dependency order:

1. Create the namespace, ConfigMap, and Secret.
2. Create the headless database Service and StatefulSet.
3. Wait for `db-0` and its PVC to become ready.
4. Create the backend and frontend Services and Deployments.
5. Install Traefik with the pinned Helm chart and project values.
6. Apply the Ingress resource.
7. Verify the workloads, generated PVC, IngressClass, and HTTP routes.

The exact commands are maintained in `assignment-1/advanced/README.md` to keep operational instructions close to the manifests.

## 8. Risks, Constraints, and Tradeoffs

### 8.1 Single-replica PostgreSQL

The StatefulSet improves identity and storage management but does not make PostgreSQL highly available. The project still has one database Pod and one `ReadWriteOnce` volume. Production high availability would require replication, leader election, backups, recovery testing, and usually a PostgreSQL-aware operator or managed database service.

### 8.2 Local NodePort accessibility

The Traefik Service exposes HTTP on NodePort `30081`, but a `kind` cluster must have a matching host port mapping for direct browser access. Where that mapping is absent, `kubectl port-forward` remains the supported local access method.

### 8.3 Hostname resolution

The Ingress rule uses `task-tracker.local`. Local clients must resolve that name to the address used to reach Traefik, commonly through a hosts-file entry during development.

### 8.4 TLS remains out of scope

The current Ingress serves HTTP only. TLS termination would require a certificate, a `kubernetes.io/tls` Secret, and an Ingress `tls` section. Local certificate trust and certificate renewal would also need an explicit operating procedure.

### 8.5 Secrets are encoded rather than encrypted

As in the original assignment, Kubernetes Secret values are base64-encoded. Encryption at rest, external secret stores, key rotation, and repository-safe secret generation remain future security work.

### 8.6 Controller-level RBAC is present

The Traefik Helm release created the RBAC resources Traefik needs to watch cluster networking resources. The application Pods do not call the Kubernetes API, so custom application Roles and RoleBindings were not added. Adding unused permissions would not improve the application.

### 8.7 Operators were intentionally excluded

An Operator would be appropriate if the project required automated PostgreSQL replication, failover, backup, restore, and version upgrades. For this single-instance teaching application, an Operator would substantially increase scope and obscure the Kubernetes fundamentals being demonstrated.

## 9. Maintainability and Operational Impact

The modernization improves maintainability in three ways:

- **Clear workload intent:** the database manifest now communicates that PostgreSQL is stateful.
- **Centralized traffic management:** routing rules are declared in one Ingress rather than distributed across externally exposed application Services.
- **Safe comparison:** the original and advanced versions are isolated by namespace, making demonstrations and rollback straightforward.

The main operational cost is the additional Traefik controller. It introduces another Deployment, Service, Helm release, and cluster-level RBAC configuration that must be upgraded and monitored.

## 10. Recommended Next Steps

The following work should be considered only if the project evolves beyond the assignment environment:

1. Add readiness, liveness, and startup probes to all three workloads.
2. Restrict `CORS_ORIGIN` after confirming the final public hostname.
3. Add TLS termination and automated certificate management.
4. Add backup and restore procedures for PostgreSQL and test them regularly.
5. Define explicit CPU and memory requests and limits in each workload rather than relying only on namespace defaults.
6. Add NetworkPolicies to restrict traffic to the required frontend-to-backend and backend-to-database paths.
7. Evaluate a PostgreSQL operator only when replication, failover, and automated database lifecycle management become requirements.

## 11. Conclusion

The advanced deployment addresses the two most relevant architectural gaps without disrupting the original assignment. PostgreSQL now uses Kubernetes' stateful workload pattern with a stable identity and generated persistent storage, while Traefik Ingress provides a browser-compatible, single-origin route to both the frontend and API.

The implementation was validated end to end: all workloads became ready, persistent storage bound successfully, the database reported a stable `db-0` identity, the frontend returned HTTP `200`, and the API reported both the backend and database as healthy.

## Appendix A: Files Added

| File | Purpose |
|---|---|
| `assignment-1/advanced/namespace.yaml` | Isolates the advanced deployment |
| `assignment-1/advanced/configmap.yaml` | Supplies non-sensitive runtime configuration and same-origin frontend behavior |
| `assignment-1/advanced/secret.yaml` | Supplies database credentials to the database and backend |
| `assignment-1/advanced/db-service.yaml` | Provides headless database discovery |
| `assignment-1/advanced/db-statefulset.yaml` | Defines PostgreSQL as a StatefulSet with a volume claim template |
| `assignment-1/advanced/backend-service.yaml` | Keeps the backend internally reachable |
| `assignment-1/advanced/backend-deployment.yaml` | Runs the backend API |
| `assignment-1/advanced/frontend-service.yaml` | Makes the frontend reachable by Ingress |
| `assignment-1/advanced/frontend-deployment.yaml` | Runs the frontend with relative API addressing |
| `assignment-1/advanced/ingress.yaml` | Routes `/api` and `/` through Traefik |
| `assignment-1/advanced/traefik-values.yaml` | Pins and configures the Traefik installation |
| `assignment-1/advanced/README.md` | Documents deployment and verification commands |

## Appendix B: Traceability to Requested Concepts

| Concept | Implementation evidence |
|---|---|
| Stateful application deployment | PostgreSQL StatefulSet |
| Stable network/workload identity | `db-0` with `serviceName: db-svc` |
| Ordered deployment behavior | StatefulSet controller semantics |
| Headless Service | `clusterIP: None` on `db-svc` |
| Volume claim template | `db-storage` template producing `db-storage-db-0` |
| Ingress resource | `task-tracker` Ingress |
| Basic routing rules | `/api` and `/` prefix routes |
| Name-based routing | `task-tracker.local` host rule |
| Ingress Controller | Traefik Helm release and `traefik` IngressClass |
| Controller annotation | Traefik `router.entrypoints: web` annotation |
