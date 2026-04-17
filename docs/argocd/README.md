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
| 13 | oauth2-proxy-helm | ForwardAuth proxy (depends on Keycloak wave 12) |
| 14 | oauth2-proxy-config | Credentials via ESO + Traefik middleware |
| 15 | argocd-config, longhorn-config | HTTPRoutes + ExternalSecrets now resolvable (after wave 14) |
| 16 | alloy-helm | Log collector |
| 17 | loki-helm | Log backend (needs Alloy wave 16, uses Longhorn PVC) |
| 18 | kube-prometheus-stack-helm | Prometheus + Grafana + Alertmanager (needs Loki wave 17) |
| 19 | kube-prometheus-stack-config | IngressRoutes + Grafana ExternalSecrets |

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

## AppProjects

New apps go into one of the two existing projects — do not create new ones without discussion.

- `infrastructure` — traefik, cert-manager, longhorn, vault, cnpg, eso, keycloak, oauth2-proxy, argocd-config
- `observability` — kube-prometheus-stack, loki, alloy
