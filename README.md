# Site Infrastructure

Kubernetes cluster on OpenStack (Metacentrum MetaVO / e-INFRA CZ) using Terraform + Ansible + ArgoCD (GitOps).

## Stack

| Layer | Technology |
|-------|------------|
| Infrastructure | OpenStack (Metacentrum MetaVO, Brno) |
| Provisioning | Terraform |
| Configuration | Ansible |
| Kubernetes | RKE2 (3-node HA control plane) |
| GitOps | ArgoCD |
| Ingress | Traefik v3 (Gateway API, DaemonSet on CPs) |
| TLS | cert-manager + Let's Encrypt HTTP-01 |
| Storage | Longhorn (LVM over Cinder volumes) |
| Secrets | HashiCorp Vault + External Secrets Operator |
| Database | CloudNativePG |
| Identity | Keycloak (Keycloak Operator) |
| SSO | oauth2-proxy + Traefik ForwardAuth (Keycloak OIDC) |
| Monitoring | kube-prometheus-stack |
| Logging | Loki + Grafana Alloy |

## Cluster layout

| Node | Flavor | vCPU | RAM | Private IP | Extra storage |
|------|--------|------|-----|------------|---------------|
| cp-0 | c2.8core-16ram | 8 | 16 GB | 10.8.0.10 | 1 × 32 GB → `/var/lib/rancher/rke2` |
| cp-1 | c2.8core-16ram | 8 | 16 GB | 10.8.0.11 | 1 × 32 GB → `/var/lib/rancher/rke2` |
| cp-2 | c2.8core-16ram | 8 | 16 GB | 10.8.0.12 | 1 × 32 GB → `/var/lib/rancher/rke2` |
| worker-0 | c2.8core-30ram | 8 | 30 GB | 10.8.0.20 | 3 × 158 GB → LVM → `/var/lib/longhorn` |
| worker-1 | c2.8core-30ram | 8 | 30 GB | 10.8.0.21 | 3 × 158 GB → LVM → `/var/lib/longhorn` |
| worker-2 | c2.8core-30ram | 8 | 30 GB | 10.8.0.22 | 3 × 158 GB → LVM → `/var/lib/longhorn` |
| worker-3 | c2.8core-30ram | 8 | 30 GB | 10.8.0.23 | 3 × 158 GB → LVM → `/var/lib/longhorn` |

**Totals**: 7 instances / 56 vCPU / 168 GB RAM / 15 Cinder volumes / 1 992 GB

Load balancer VIP `10.8.0.100` — ports 6443 (K8s API), 9345 (RKE2 join, cluster-only), 80/443 (ingress). cp-0 and the cluster LB have floating IPs.

## Layers

- [terraform](docs/terraform/README.md) — four root modules: gcp, openstack, vault, keycloak
- [ansible](docs/ansible/README.md) — OS baseline, RKE2, ArgoCD bootstrap
- [argocd](docs/argocd/README.md) — app-of-apps, sync waves, ExternalSecret patterns
- [.github](docs/.github/README.md) — GitHub Actions jobs and what each enforces

## Prerequisites

- Terraform >= 1.11
- Ansible >= 2.16 + Helm >= 3.0 in PATH
- `terraform/openstack/clouds.yaml` — OpenStack application credentials (gitignored)
- GCS credentials: `gcloud auth application-default login`

```bash
pip install -r requirements.txt
ansible-galaxy collection install -r ansible/requirements.yml
```

## Deployment

```text
terraform/gcp + terraform/openstack → terraform/cloudflare → ansible → [ArgoCD auto-syncs] → vault operator init → terraform/vault → terraform/keycloak
```

Each step gates the next — do not skip ahead.

### 0. Prerequisites

Create the GCS bucket for Terraform state (one-time, before any `terraform init`):

```bash
gcloud storage buckets create gs://site-infra \
    --default-storage-class=STANDARD \
    --location=US \
    --uniform-bucket-level-access \
    --public-access-prevention
```

Authenticate for GCS backend and OpenStack:

```bash
gcloud auth application-default login
# place clouds.yaml in terraform/openstack/clouds.yaml
```

### 1. terraform/gcp, terraform/openstack, terraform/metacentrum-s3

These three modules are independent — run them in parallel or in any order:

```bash
cd terraform/gcp && terraform init && terraform apply
cd terraform/openstack && terraform init && terraform apply
cd terraform/metacentrum-s3 && terraform init && terraform apply  # creates Longhorn S3 backup bucket
```

Note the ingress LB IP for the next step:

```bash
terraform output ingress_lb_public_ip
```

### 2. terraform/cloudflare

Creates the A record for `nss.jkzl.eu` and CNAME records for all subdomains. DNS must resolve before cert-manager can issue certificates.

```bash
cd terraform/cloudflare
cp terraform.tfvars.example terraform.tfvars  # fill in cloudflare_api_token, cloudflare_zone_id (ingress_ip is written automatically by openstack)
terraform init && terraform apply
```

### 3. Ansible

```bash
export KUBECONFIG=$(pwd)/ansible/artifacts/kubeconfig
cd ansible && ansible-playbook site.yml
```

### 4. Wait for ArgoCD waves 1–6

Waves 1–6 deploy storage, TLS, ingress, and Vault. Vault will stay `Degraded` until initialized — that is expected at this point. All other apps in this range should reach `Healthy`.

```bash
kubectl -n argocd get applications -w
```

Wait until `vault-helm` is `Synced` before continuing (it will not be `Healthy` yet).

### 5. Vault init (one-time manual)

```bash
kubectl exec -n vault vault-helm-0 -- vault operator init
```

Save all recovery keys and the root token in a password manager. Vault auto-unseals via GCP KMS on every restart — the keys are only needed for break-glass recovery.

### 6. terraform/vault

```bash
cd terraform/vault
cp terraform.tfvars.example terraform.tfvars  # fill in vault_root_token
terraform init && terraform apply
```

This pushes all service credentials into Vault. ESO will now sync them into Kubernetes — wait for waves 7–9 (`vault-config`, `eso-helm`, `eso-config`) to become `Healthy` before continuing.

### 7. terraform/keycloak

Register a Google OAuth app first (GCP Console → APIs & Services → Credentials → Create OAuth 2.0 Client ID, redirect URI: `https://keycloak.nss.jkzl.eu/realms/ass-nss-project/broker/google/endpoint`), then:

```bash
cd terraform/keycloak
cp terraform.tfvars.example terraform.tfvars  # fill in keycloak + vault + google credentials + group members
terraform init && terraform apply
```

This also creates the `rag-rbac-sa` service account (`03-clients.tf`) and pushes its credentials to Vault (`secret/oidc/rag-rbac-sa`). ESO syncs them into the `rag-system` deployment as `KEYCLOAK_ADMIN_CLIENT_ID` / `KEYCLOAK_ADMIN_CLIENT_SECRET`, enabling role changes made in the WebRAG UI to be synced back to Keycloak group membership.

## Teardown

Destroy in reverse order to respect dependencies:

```bash
cd terraform/keycloak && terraform destroy
cd terraform/vault && terraform destroy
cd terraform/openstack && terraform destroy
cd terraform/gcp && terraform destroy
```

Delete the GCS state bucket last (this is irreversible):

```bash
gcloud storage rm -r gs://site-infra
```

## Secrets management

Credentials live in Vault (KV v2, path `secret/`) and are synced into Kubernetes by ESO — no static secrets in git.

| Vault path | Kubernetes Secret | Namespace |
|------------|-------------------|-----------|
| `secret/grafana` | `grafana-credentials` | `monitoring` |
| `secret/keycloak` | `keycloak-credentials` | `keycloak` |
| `secret/oidc/argocd` | `argocd-oidc-secret` | `argocd` |
| `secret/oidc/grafana` | `grafana-oidc-secret` | `monitoring` |
| `secret/oidc/traefik` | `traefik-keycloak-credentials` | `traefik` |
| `secret/oidc/rag-system` | `rag-secrets` (`keycloak-client-id/secret`) | `rag-system` |
| `secret/oidc/rag-rbac-sa` | `rag-secrets` (`keycloak-admin-client-id/secret`) | `rag-system` |
| `secret/alertmanager/telegram` | `alertmanager-telegram` | `monitoring` |

## DNS records

Managed by `terraform/cloudflare`. One A record at the apex, all subdomains are CNAMEs to it.

| Hostname | Type | Target |
|----------|------|--------|
| `nss.jkzl.eu` | A | Ingress LB floating IP |
| `argocd.nss.jkzl.eu` | CNAME | `nss.jkzl.eu` |
| `longhorn.nss.jkzl.eu` | CNAME | `nss.jkzl.eu` |
| `vault.nss.jkzl.eu` | CNAME | `nss.jkzl.eu` |
| `keycloak.nss.jkzl.eu` | CNAME | `nss.jkzl.eu` |
| `grafana.nss.jkzl.eu` | CNAME | `nss.jkzl.eu` |
| `oauth2.nss.jkzl.eu` | CNAME | `nss.jkzl.eu` |
| `prometheus.nss.jkzl.eu` | CNAME | `nss.jkzl.eu` |
| `alertmanager.nss.jkzl.eu` | CNAME | `nss.jkzl.eu` |

## SSO

All UIs are protected by Keycloak (Google SSO). Users log in via Google and are assigned to one of four groups managed by `terraform/keycloak`:

| Group | ArgoCD | Grafana | Vault | Longhorn / Prometheus / Alertmanager | RAG System role |
|-------|--------|---------|-------|--------------------------------------|-----------------|
| `rag_admin` | full admin | Admin | full access | allowed | `rag_admin` |
| `rag_curator` | — | — | no access | blocked | `rag_curator` |
| `rag_analyst` | — | Viewer | no access | blocked | `rag_analyst` |
| `rag_user` | — | — | no access | blocked | `rag_user` |

To add a user, put their Gmail address in the corresponding `*_members` variable in `terraform/keycloak/terraform.tfvars` and re-run `terraform apply`. Users are pre-created in Keycloak before their first login.

`rag_admin` holds the `realm-admin` Keycloak role — full console access across the entire realm.

### oauth2-proxy auth flow (Longhorn, Prometheus, Alertmanager)

These services have no native OIDC support and are protected by oauth2-proxy (`argocd/apps/oauth2-proxy/`) acting as a ForwardAuth gate via Traefik. Only users in the `rag_admin` Keycloak group can access them.

```text
Browser → longhorn.nss.jkzl.eu
  → Traefik: chain middleware (errors outer + forwardAuth inner)
  → forwardAuth: GET oauth2-proxy /oauth2/auth → 401 (no session)
  → errors catches 401: GET oauth2-proxy /oauth2/sign_in?rd=<original-url> → 302
  → Browser follows 302 to Keycloak (client_id=traefik, redirect_uri=oauth2.nss.jkzl.eu/oauth2/callback)
  → User authenticates via Google identity broker
  → Keycloak → oauth2.nss.jkzl.eu/oauth2/callback
  → oauth2-proxy checks groups claim → user in rag_admin → sets .nss.jkzl.eu cookie → 302 back to original URL
  → forwardAuth: GET /oauth2/auth with cookie → 200
  → Traefik forwards to Longhorn backend
```

Subsequent requests skip Keycloak entirely — the shared `.nss.jkzl.eu` cookie covers all protected subdomains.

## TLS

Three ClusterIssuers in `argocd/apps/cert-manager/config/`: `letsencrypt-staging` (test first), `letsencrypt-prod` (rate-limited: 50 certs/domain/week), `selfsigned-ca` (offline/dev).

Always test with staging first — DNS and port 80 routing must be reachable for HTTP-01 challenge.

## Adding a new subdomain

**Via Gateway API (HTTPRoute)** — no middleware needed:

1. Add DNS A record
2. Add HTTPS listener in `argocd/apps/traefik/config/traefik-gateway-Gateway.yaml`
3. Add `Certificate` in `argocd/apps/cert-manager/config/<name>-tls-Certificate.yaml` (namespace: `traefik`)
4. Add `HTTPRoute` in `argocd/apps/<app>/config/<app>-HTTPRoute.yaml`

**With keycloakopenid authentication** — for apps that need Keycloak SSO via the plugin middleware:

1. Add DNS A record
2. Add HTTPS listener in `argocd/apps/traefik/config/traefik-gateway-Gateway.yaml`
3. Add `Certificate` in `argocd/apps/cert-manager/config/<name>-tls-Certificate.yaml` (namespace: `traefik`)
4. Add a `Middleware` CRD (plugin: keycloakopenid) in `argocd/apps/<app>/config/<app>-auth-Middleware.yaml`
5. Add `HTTPRoute` referencing the middleware via `ExtensionRef`

Push to `kost` — ArgoCD applies automatically.

## Vault

UI: `https://vault.nss.jkzl.eu` — login via OIDC (leave role blank) or root token (break-glass only).

Auto-unseals via GCP KMS (`enc-ass-nss-project / vault-keyring / vault-unseal-key`) on every restart. OIDC auth is configured by `terraform/keycloak/05-vault-oidc.tf` — re-running it after a cluster rebuild restores access.

> Vault data lives on a Longhorn PVC. The GCP KMS key ring is permanent — import it back into Terraform state on a full rebuild.

## Grafana dashboards

Three dashboards are provisioned automatically via ConfigMap (Grafana sidecar watches for `grafana_dashboard: "1"` label across all namespaces and places them in the **RAG System** folder via `defaultFolderName`):

| Dashboard | UID | ConfigMap | Panels |
|-----------|-----|-----------|--------|
| WebRAG — Overview | `rag-overview` | `rag-grafana-overview-dashboard` | Active sources, Qdrant size, open incidents, total jobs; 24 h ingest bar chart; strategy distribution; recent pipeline logs |
| WebRAG — Metrics | `rag-metrics` | `rag-grafana-metrics-dashboard` | Prometheus stats + timeseries: jobs, error rates, latency, embeddings, CAPTCHA rate |
| WebRAG — Audit | `rag-audit` | `rag-grafana-audit-dashboard` | Loki log panels: auth, query, and security events |

All ConfigMaps live in `argocd/apps/kube-prometheus-stack/config/` and are applied by ArgoCD automatically.

## ArgoCD

UI: `https://argocd.nss.jkzl.eu`

Initial admin password (before SSO):

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

## Logging and alerting

Logs are collected by Grafana Alloy (Deployment, `alloy` namespace) via the Kubernetes API and shipped to Loki (SingleBinary, `monitoring` namespace). Loki's ruler evaluates LogQL alert rules and forwards firing alerts to Alertmanager.

Rules live in `argocd/apps/loki/config/loki-rules-ConfigMap.yaml`, mounted into Loki at `/var/loki/rules/fake/`.

### rag_app Loki labels

Alloy's pipeline (`argocd/apps/alloy/helm/values.yaml`) tags structured JSON logs from the `rag-system` namespace with a `rag_app` label for easy querying:

| `rag_app` value | Events captured | Example LogQL |
|-----------------|-----------------|---------------|
| `audit` | `login_success`, `login_failed`, `user_registered`, `keycloak_role_synced` | `{namespace="rag-system", rag_app="audit"}` |
| `incident` | `captcha_detected` | `{namespace="rag-system", rag_app="incident"}` |
| `pipeline` | `ingest_*`, `embedding_*`, `search_*` | `{namespace="rag-system", rag_app="pipeline"}` |

### CAPTCHA alerting (Telegram)

Firing condition: any `captcha_detected` log event in the `rag-system` namespace within the past 5 minutes. Defined in `argocd/apps/loki/config/loki-rules-ConfigMap.yaml` (`rag-captcha` group). Alertmanager routes it via `argocd/apps/kube-prometheus-stack/config/alertmanager-captcha-AlertmanagerConfig.yaml` to a Telegram bot.

**Provisioning**: credentials are pushed to Vault via Terraform (`terraform/vault/01-vault.tf`, resource `vault_kv_secret_v2.alertmanager_telegram`). Add `telegram_bot_token` and `telegram_chat_id` to `terraform.tfvars` and run `terraform apply`.

ESO syncs `bot_token` → `bot-token` and `chat_id` → `chat-id` in the `alertmanager-telegram` Secret. The `AlertmanagerConfig` reads `botToken` and `chatIDRef` from that Secret (prometheus-operator ≥0.75 `chatIDRef` field — available in kube-prometheus-stack ≥68).

### Simulate a log alert

```bash
# Start — alert fires within ~1 minute
kubectl run simulate --image=busybox --restart=Never -- sh -c 'while true; do echo "SIMULATE_ALERT test"; sleep 5; done'

# Stop — alert resolves within ~1 minute
kubectl delete pod simulate
```

The `SimulatedAlert` rule fires within ~1 minute — check `https://alertmanager.nss.jkzl.eu`.

```bash
pkill -f "port-forward.*3100"
```

## Longhorn

UI: `https://longhorn.nss.jkzl.eu` (keycloakopenid protected — requires Keycloak login). Default StorageClass: `longhorn`. Usable capacity: ~333 GB (2-replica default across 4 workers).

### S3 backups

Backups go to Metacentrum CESNET S3 (`https://s3.cl4.du.cesnet.cz`, bucket `longhorn-backup`). A recurring job runs daily at 02:00 UTC and retains 7 backups.

**Setup** (once per cluster build):

1. Create the bucket:

   ```bash
   cd terraform/metacentrum-s3 && terraform apply -auto-approve
   ```

1. Store credentials in Vault:

   ```bash
   cd terraform/vault && terraform apply -auto-approve
   ```

ESO syncs the credentials into `longhorn-system/longhorn-s3-backup`. The `BackupTarget` and `RecurringJob` CRs are managed by ArgoCD from `argocd/apps/longhorn/config/`.
