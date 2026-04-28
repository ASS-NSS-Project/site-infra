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
| 13 | argocd-config, longhorn-config, oauth2-proxy-helm, oauth2-proxy-config | HTTPRoutes + ExternalSecrets now resolvable; oauth2-proxy ForwardAuth gate for Longhorn/Prometheus/Alertmanager |
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

## rag-system — Prometheus scraping

`apps/rag-system/config/rag-api-ServiceMonitor.yaml` tells kube-prometheus-stack to scrape the RAG API's `/metrics` endpoint every 30 s. The `rag-api` Service (`rag-api-Service.yaml`) exposes port `http` (8000) with a matching `app: rag-api` metadata label so the ServiceMonitor selector can find it.

The `prometheusSpec` in `kube-prometheus-stack/helm/values.yaml` sets `serviceMonitorSelector: {matchLabels: {release: kube-prometheus-stack}}` and `serviceMonitorNamespaceSelector: {}` so Prometheus picks up ServiceMonitors with that label from all namespaces — this is required because the ServiceMonitor lives in `rag-system` while Prometheus runs in `monitoring`. The same explicit label selectors are applied for PodMonitors and PrometheusRules. All monitored resources must carry the `release: kube-prometheus-stack` label.

Dashboard ConfigMaps (`rag-grafana-metrics-dashboard-ConfigMap.yaml`, `rag-grafana-loki-dashboard-ConfigMap.yaml`) carry `grafana_dashboard: "1"` which the Grafana sidecar picks up automatically and loads as dashboards.

## RKE2 Kubernetes component monitoring

kube-prometheus-stack auto-enables scraping of Kubernetes internals but needs explicit endpoint configuration for RKE2 because the static-pod components do not register in the standard discovery paths:

| Component | Port | Notes |
|-----------|------|-------|
| kube-scheduler | 10259 (HTTPS) | `insecureSkipVerify: true`, `serverName: localhost` |
| kube-controller-manager | 10257 (HTTPS) | `insecureSkipVerify: true`, `serverName: localhost` |
| kube-etcd | 2381 (HTTP) | Metrics-only endpoint, no TLS required |
| kube-proxy | disabled | RKE2 uses Canal CNI, kube-proxy does not run |

All three control-plane nodes (10.8.0.10–12) are listed as explicit `endpoints` in the values. kubelet, kube-state-metrics, node-exporter, and coreDNS are auto-discovered by the chart.

## CAPTCHA alerting — Telegram

`apps/kube-prometheus-stack/config/rag-captcha-PrometheusRule.yaml` defines the `RagCaptchaIncident` alert: it fires immediately (`for: 0m`) whenever `increase(rag_captcha_incidents_total[5m]) > 0` — i.e. a new CAPTCHA block was recorded in the last 5 minutes. The alert carries `rag_app: incident` label.

`apps/kube-prometheus-stack/config/alertmanager-captcha-AlertmanagerConfig.yaml` routes alerts with `rag_app: incident` to the `telegram-captcha` receiver, reading the bot token from the `alertmanager-telegram` secret (provisioned by ESO from Vault `secret/alertmanager/telegram`). The route uses `repeatInterval: 4h` so a single CAPTCHA wave produces one message, not a flood.

Both the PrometheusRule and the AlertmanagerConfig are deployed to the `monitoring` namespace, which ensures the Prometheus Operator's automatic `namespace: monitoring` label injection aligns with the AlertmanagerConfig sub-route matcher.

---

## rag-system API HTTPRoute — `/api` prefix

`apps/rag-system/config/rag-system-HTTPRoute.yaml` includes a rule that routes `https://rag.nss.jkzl.eu/api/*` to the backend API, stripping the `/api` prefix before forwarding (Gateway API `URLRewrite` filter with `ReplacePrefixMatch: /`). This lets `cURL` users and external scripts call a stable public endpoint without knowing which path the frontend nginx proxies:

```bash
# Login
curl -s -X POST https://rag.nss.jkzl.eu/api/auth/login \
  -d "username=user@example.com&password=secret" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])"

# Query (replace TOKEN)
curl -s -X POST https://rag.nss.jkzl.eu/api/query/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"question": "What are the latest findings?", "top_k": 5}'
```

The `/api` rule is placed before the catch-all frontend rule so Gateway API specificity routing does not interfere.

---

## rag-system worker — StatefulSet

`apps/rag-system/config/worker-Deployment.yaml` is a **StatefulSet** (not a Deployment). The BGE-M3 model cache uses a `ReadWriteOnce` Longhorn volume, and RWO volumes cannot be shared across Deployment pods. A StatefulSet with `volumeClaimTemplates` creates one independent PVC per replica:

```text
hf-cache-rag-worker-0   (5 Gi, Longhorn RWO)
hf-cache-rag-worker-1   (5 Gi, Longhorn RWO)
…
```

`apps/rag-system/config/rag-worker-PersistentVolumeClaim.yaml` holds the **headless Service** (`clusterIP: None`) required by the StatefulSet — not a PVC (the StatefulSet owns its own PVCs). The old standalone `rag-worker` PVC was replaced by the `volumeClaimTemplates` entry.

**Scaling workers:** set `replicas` in `worker-Deployment.yaml` to any odd number (1, 3, 5, 7, 9, …). Each replica independently pulls jobs from the shared RabbitMQ `ingest` queue (`prefetch_count=1`) — N replicas process N jobs in parallel with no coordination needed.

**Caution:** StatefulSet PVCs are not pruned automatically when the StatefulSet is deleted or scaled down. Delete orphaned PVCs manually if you scale down permanently.

---

## AppProjects

New apps go into one of the two existing projects — do not create new ones without discussion.

- `infrastructure` — traefik, cert-manager, longhorn, vault, cnpg, eso, keycloak, argocd-config
- `observability` — kube-prometheus-stack, loki, alloy
