# Site Infrastructure

Kubernetes cluster on OpenStack (Metacentrum MetaVO / e-INFRA CZ) using Terraform + Ansible + ArgoCD (GitOps).

## AI-assisted development (Claude Code)

This repo uses [Claude Code](https://claude.ai/code) for AI-assisted development. `.claude/settings.json` is committed intentionally — it enforces shared guardrails (sensitive file access, blocked commands) for every contributor using Claude Code. See `CLAUDE.md` for project conventions.

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
| SSO | oauth2-proxy (ForwardAuth) |
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

### 1. terraform/gcp and terraform/openstack

These two modules are independent — run them in parallel or in either order:

```bash
cd terraform/gcp && terraform init && terraform apply
cd terraform/openstack && terraform init && terraform apply
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

### 4. Wait for ArgoCD wave 1

Wave 1 apps (Vault, cert-manager, Traefik, Keycloak Operator, ESO) must be healthy before proceeding. Vault and Keycloak will not be ready until their secrets exist in Vault — that happens in step 6.

```bash
kubectl -n argocd get applications -w
```

Wait until Vault is `Healthy` (it will stay `Degraded` until initialized — that is expected at this point).

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

This pushes all service credentials into Vault. ESO will now sync them into Kubernetes — wait for all wave 1 and wave 2 apps to become `Healthy` before continuing.

### 7. terraform/keycloak

Register a Google OAuth app first (GCP Console → APIs & Services → Credentials → Create OAuth 2.0 Client ID, redirect URI: `https://keycloak.nss.jkzl.eu/realms/ass-nss-project/broker/google/endpoint`), then:

```bash
cd terraform/keycloak
cp terraform.tfvars.example terraform.tfvars  # fill in keycloak + vault + google credentials + group members
terraform init && terraform apply
```

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
| `secret/oidc/oauth2-proxy` | `oauth2-proxy-credentials` | `oauth2-proxy` |

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
| `prometheus.nss.jkzl.eu` | CNAME | `nss.jkzl.eu` |
| `alertmanager.nss.jkzl.eu` | CNAME | `nss.jkzl.eu` |

## SSO

All UIs are protected by Keycloak (Google SSO). Users log in via Google and are assigned to one of five groups managed by `terraform/keycloak`:

| Group | ArgoCD | Grafana | Vault | Longhorn / Prometheus / Alertmanager |
|-------|--------|---------|-------|--------------------------------------|
| `admin` | full admin | Admin | full access | allowed |
| `curator` | — | — | no access | blocked |
| `analytic` | — | Viewer | no access | blocked |
| `user` | — | — | no access | blocked |
| `unauthorized` | — | — | no access | blocked |

To add a user, put their Gmail address in `admin_members`, `curator_members`, `analytic_members`, or `user_members` in `terraform/keycloak/terraform.tfvars` and re-run `terraform apply`. Users are pre-created in Keycloak before their first login.

## TLS

Three ClusterIssuers in `argocd/apps/cert-manager/config/`: `letsencrypt-staging` (test first), `letsencrypt-prod` (rate-limited: 50 certs/domain/week), `selfsigned-ca` (offline/dev).

Always test with staging first — DNS and port 80 routing must be reachable for HTTP-01 challenge.

## Adding a new subdomain

**Via Gateway API (HTTPRoute)** — no middleware needed:

1. Add DNS A record
2. Add HTTPS listener in `argocd/apps/traefik/config/traefik-gateway-Gateway.yaml`
3. Add `Certificate` in `argocd/apps/cert-manager/config/<name>-tls-Certificate.yaml` (namespace: `traefik`)
4. Add `HTTPRoute` in `argocd/apps/<app>/config/<app>-HTTPRoute.yaml`

**Via Traefik IngressRoute** — for ForwardAuth or other middleware:

1. Add DNS A record
2. Add `Certificate` in `argocd/apps/cert-manager/config/<name>-tls-Certificate.yaml` (namespace: app's namespace)
3. Add `IngressRoute` in `argocd/apps/<app>/config/<app>-IngressRoute.yaml`

Push to `kost` — ArgoCD applies automatically.

## Vault

UI: `https://vault.nss.jkzl.eu` — login via OIDC (leave role blank) or root token (break-glass only).

Auto-unseals via GCP KMS (`enc-ass-nss-project / vault-keyring / vault-unseal-key`) on every restart. OIDC auth is configured by `terraform/keycloak/05-vault-oidc.tf` — re-running it after a cluster rebuild restores access.

> Vault data lives on a Longhorn PVC. The GCP KMS key ring is permanent — import it back into Terraform state on a full rebuild.

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

### Simulate an alert

```bash
kubectl run simulate --image=busybox --restart=Never -- sh -c 'echo "SIMULATE_ALERT test"'
kubectl delete pod simulate
```

The `SimulatedAlert` rule fires within ~1 minute — check `https://alertmanager.nss.jkzl.eu`.

## Longhorn

UI: `https://longhorn.nss.jkzl.eu` (oauth2-proxy protected). Default StorageClass: `longhorn`. Usable capacity: ~333 GB (2-replica default across 4 workers).
