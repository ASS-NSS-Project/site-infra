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

File naming is always `<name>-<Kind>.yaml`, e.g. `harbor-credentials-ExternalSecret.yaml`, `traefik-gateway-Gateway.yaml`.

## Sync waves

Wave N must be fully healthy before wave N+1 starts. Confirm the wave assignment with the developer before committing.

Wave 1 — Helm charts and operators with no runtime dependencies: traefik, cert-manager, longhorn, harbor, vault, cnpg, kube-prometheus-stack, keycloak-operator, eso, oauth2-proxy

Wave 2 — requires wave 1 CRDs: traefik-config (Gateway + GatewayClass), cert-manager-config (ClusterIssuers), eso-config (ClusterSecretStore)

Wave 3 — requires wave 2 resources: all HTTPRoutes, ExternalSecrets, Keycloak CR, CNPG Cluster, argocd-config

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

All secrets come from Vault via ESO. The `ClusterSecretStore` named `vault` (wave 2) must exist before any ExternalSecret (wave 3).

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

- `infrastructure` — traefik, cert-manager, longhorn, harbor, vault, cnpg, eso, keycloak, oauth2-proxy, argocd-config
- `observability` — kube-prometheus-stack, grafana-config
