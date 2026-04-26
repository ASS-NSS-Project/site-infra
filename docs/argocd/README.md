# ArgoCD

All application delivery lives here. ArgoCD self-heals against this directory on the `kost` branch — every change merged to `kost` is applied automatically.

## App-of-apps

`root-Application.yaml` scans `apps/` recursively for `*-Application.yaml` files. It is applied once by Ansible and is not self-managed. Never move it inside `apps/`.

## Adding a new app — checklist

1. Create `apps/<app>/` with the structure below
2. Confirm the sync wave with the developer before committing
3. Set `revisionHistoryLimit: 0` and `syncPolicy.automated` on every Application
4. Add the finalizer only if the app is stateless — see root README for the list of apps that must not have it
5. If the app needs Vault credentials, add an ExternalSecret in `config/`

## Directory structure

Every app follows the same layout:

```text
apps/<app>/
├── helm-Application.yaml     # deploys the Helm chart (multi-source)
├── config-Application.yaml   # deploys manifests from config/
├── helm/values.yaml          # overrides only — no chart defaults repeated
└── config/
    └── <name>-<Kind>.yaml    # one file per resource
```

File naming is always `<name>-<Kind>.yaml`, e.g. `grafana-credentials-ExternalSecret.yaml`, `traefik-gateway-Gateway.yaml`.

## Sync waves

Wave N must be fully healthy before wave N+1 starts. Confirm the wave assignment with the developer before committing.

Each app follows a strict helm → config pairing in dependency order. Stateful apps (longhorn, vault) and the keycloak-operator do not have an immediate config wave — their configs are deferred until all their dependencies (ESO, Keycloak) are ready.

| Wave | Application(s) | Reason |
|------|---------------|--------|
| 1 | longhorn-helm | Storage first — PVCs must exist before dependents |
| 2 | cert-manager-helm | TLS infrastructure |
| 3 | cert-manager-config | ClusterIssuers + Certificates (needs wave 2 CRDs) |
| 4 | traefik-helm | Ingress — depends on cert-manager certificates (wave 3) |
| 5 | traefik-config | Gateway + GatewayClass (needs wave 4 CRDs) |
| 6 | vault-helm | Secret store |
| 7 | vault-config | HTTPRoute + SA ClusterRoleBinding (must exist before ESO wave 8) |
| 8 | eso-helm | External Secrets Operator CRDs + controller |
| 9 | eso-config | ClusterSecretStore → Vault (needs ESO wave 8 + Vault wave 6-7) |
| 10 | cnpg-helm | CloudNativePG operator — Keycloak's database provider |
| 11 | keycloak-operator | Keycloak CRDs + controller (after cnpg wave 10) |
| 12 | keycloak-config | Keycloak CR + CNPG Cluster + ExternalSecret (needs waves 9-11) |
| 13 | argocd-config, longhorn-config | HTTPRoutes + ExternalSecrets now resolvable (after Keycloak wave 12) |
| 14 | alloy-helm | Log collector |
| 15 | loki-helm | Log backend (needs Alloy wave 14, uses Longhorn PVC) |
| 16 | kube-prometheus-stack-helm | Prometheus + Grafana + Alertmanager (needs Loki wave 15) |
| 17 | kube-prometheus-stack-config, rabbitmq-operator | IngressRoutes + Grafana ExternalSecrets; RabbitMQ CRDs |
| 18 | qdrant-helm, rabbitmq-config | Vector DB + RabbitMQ cluster CR |
| 19 | rag-system-config | RAG application (needs all upstream waves) |

Set the wave via annotation: `argocd.argoproj.io/sync-wave: "1"`

## Application template

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <app>-helm           # or <app>-config
  namespace: argocd
  finalizers:                # omit for stateful apps
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "<n>"
spec:
  revisionHistoryLimit: 0
  project: infrastructure    # or observability
  source:
    repoURL: https://github.com/ASS-NSS-Project/site-infra
    targetRevision: kost
    path: argocd/apps/<app>/config
  destination:
    server: https://kubernetes.default.svc
    namespace: <app-namespace>
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

For Helm charts from external registries, use multi-source — the chart from its registry, values from this repo via `ref: values`.

## ExternalSecret pattern

All secrets come from Vault via ESO. The `ClusterSecretStore` named `vault` (wave 9) must exist before any ExternalSecret.

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: <app>-credentials
  namespace: <app-namespace>
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault
    kind: ClusterSecretStore
  target:
    name: <app>-credentials
    creationPolicy: Owner
  data:
    - secretKey: <ENV_VAR>
      remoteRef:
        key: <vault-path>    # secret/<service> or secret/oidc/<app>
        property: <field>
```

## Secret bootstrap ordering

Some apps in early sync waves reference secrets that are only populated by `terraform/keycloak`, which runs after Keycloak is deployed (wave 11–12). To prevent early-wave pods from entering `CreateContainerConfigError` while waiting for those secrets, mark `secretKeyRef` entries as optional:

```yaml
env:
  - name: KEYCLOAK_CLIENT_ID
    valueFrom:
      secretKeyRef:
        name: traefik-keycloak-credentials
        key: client-id
        optional: true
```

The pod starts with an empty env var. Once ESO syncs the real value from Vault, Kubernetes injects it on the next pod restart (or the app reads it from the mounted secret path, depending on how it consumes the env).

Any secret that is sourced from `terraform/keycloak` but consumed by an app before wave 12 **must** be marked optional. Current cases:

| App | Secret | Vault path |
|-----|--------|------------|
| traefik (wave 4) | `traefik-keycloak-credentials` | `secret/oidc/traefik` |

---

## AppProjects

New apps go into one of the two existing projects — do not create new ones without discussion.

- `infrastructure` — traefik, cert-manager, longhorn, vault, cnpg, eso, keycloak, argocd-config
- `observability` — kube-prometheus-stack, loki, alloy
