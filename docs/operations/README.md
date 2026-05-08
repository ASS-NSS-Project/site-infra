# Operations Runbook

This runbook contains operational details that are intentionally kept out of the root infrastructure README.

## Prerequisites

- Terraform >= 1.11
- Ansible >= 2.16
- Helm >= 3.0
- GCS application-default credentials
- OpenStack `clouds.yaml` placed at `terraform/openstack/clouds.yaml`

```bash
pip install -r requirements.txt
ansible-galaxy collection install -r ansible/requirements.yml
gcloud auth application-default login
```

Create the Terraform state bucket once:

```bash
gcloud storage buckets create gs://enc-ass-nss-project \
  --default-storage-class=STANDARD \
  --location=US \
  --uniform-bucket-level-access \
  --public-access-prevention
```

## Bootstrap Order

Run the independent first-stage Terraform modules:

```bash
cd terraform/gcp && terraform init && terraform apply
cd terraform/openstack && terraform init && terraform apply
cd terraform/du-cesnet && terraform init && terraform apply
```

Configure DNS after OpenStack exposes the ingress floating IP:

```bash
cd terraform/cloudflare
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

Bootstrap nodes and ArgoCD:

```bash
export KUBECONFIG=$(pwd)/ansible/artifacts/kubeconfig
cd ansible
ansible-playbook site.yml
```

Wait for early ArgoCD waves through Vault:

```bash
kubectl -n argocd get applications -w
```

Initialize Vault once:

```bash
kubectl exec -n vault vault-helm-0 -- vault operator init
```

Store recovery keys and the root token in a password manager. Vault auto-unseals via GCP KMS after this.

Provision Vault and Keycloak:

```bash
cd terraform/vault
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply

cd ../keycloak
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

## Teardown

Destroy in reverse dependency order:

```bash
cd terraform/keycloak && terraform destroy
cd terraform/vault && terraform destroy
cd terraform/openstack && terraform destroy
cd terraform/gcp && terraform destroy
```

Delete the GCS state bucket last only when the environment is permanently retired.

## DNS

`terraform/cloudflare` manages the apex A record for `nss.jkzl.eu` and CNAMEs for service subdomains. DNS must resolve before cert-manager can satisfy HTTP-01 challenges.

## Adding a Subdomain

For a normal Gateway API route:

1. Add DNS in `terraform/cloudflare`.
2. Add an HTTPS listener in `argocd/apps/traefik/config/traefik-gateway-Gateway.yaml`.
3. Add a `Certificate` in `argocd/apps/cert-manager/config/`.
4. Add an `HTTPRoute` in the app's `config/` directory.

For Keycloak-protected apps, also add a Traefik middleware and attach it to the route.

## Vault

Vault UI: <https://vault.nss.jkzl.eu>

Vault auto-unseals with GCP KMS. OIDC access is configured by `terraform/keycloak/05-vault-oidc.tf`; root token access is break-glass only.

Vault data lives on a Longhorn PVC. On a full rebuild, the GCP KMS key ring should be imported back into Terraform state rather than recreated.

## Secrets

Credentials flow:

```text
Terraform variables
  -> terraform/vault writes Vault KV v2 paths
  -> External Secrets Operator syncs Kubernetes Secrets
  -> Deployments consume secretKeyRef values
```

Common Vault paths:

| Vault path | Kubernetes secret | Namespace |
|------------|-------------------|-----------|
| `secret/rag` | `webrag-secrets` | `webrag` |
| `secret/oidc/webrag` | `webrag-secrets` | `webrag` |
| `secret/oidc/rag-rbac-sa` | `webrag-secrets` | `webrag` |
| `secret/keycloak` | `keycloak-credentials` | `keycloak` |
| `secret/grafana` | `grafana-credentials` | `monitoring` |
| `secret/longhorn/s3-backup` | `longhorn-s3-backup` | `longhorn-system` |
| `secret/alertmanager/telegram` | `alertmanager-telegram` | `monitoring` |

## SSO and ForwardAuth

Keycloak uses Google as an identity broker. User Gmail addresses are managed in `terraform/keycloak/terraform.tfvars` group member variables.

oauth2-proxy protects infrastructure UIs without native OIDC support:

```text
Browser -> protected host
  -> Traefik ForwardAuth
  -> oauth2-proxy
  -> Keycloak
  -> shared .nss.jkzl.eu session cookie
  -> protected backend
```

Only `webrag_admin` can access Longhorn, Prometheus, Alertmanager, and Qdrant.

## TLS

cert-manager issuers live in `argocd/apps/cert-manager/config/`:

- `letsencrypt-staging`
- `letsencrypt-prod`
- `selfsigned-ca`

Use staging before production when changing DNS or routing.

## Observability

Grafana dashboards are provisioned by ConfigMaps labeled `grafana_dashboard: "1"`:

| Dashboard | UID | Purpose |
|-----------|-----|---------|
| WebRAG Overview | `webrag-overview` | Sources, incidents, jobs, Qdrant, ingest activity |
| WebRAG Audit | `webrag-audit` | Auth, query, security, and pipeline logs |

Logs flow through Grafana Alloy to Loki. Loki ruler evaluates LogQL alert rules and forwards alerts to Alertmanager.

Important RAG labels from Alloy:

| Label | Events |
|-------|--------|
| `webrag="audit"` | login and role sync events |
| `webrag="incident"` | CAPTCHA events |
| `webrag="pipeline"` | ingest, embedding, search events |

CAPTCHA alerts are routed to Telegram through `alertmanager-captcha-AlertmanagerConfig.yaml`.

## Longhorn Backups

Longhorn UI: <https://longhorn.nss.jkzl.eu>

Backups use CESNET S3. The bucket is provisioned by `terraform/du-cesnet`, credentials are stored by `terraform/vault`, and the target/recurring job are managed by ArgoCD from `argocd/apps/longhorn/config/`.

## WebRAG Operations

Scale ingest workers:

```bash
kubectl scale statefulset -n webrag webrag-worker-ingest --replicas=5
```

Scale embedding workers:

```bash
kubectl scale statefulset -n webrag webrag-worker-embed --replicas=2
```

Each worker replica gets its own `hf-cache` PVC for BGE-M3 weights.

Promote a new WebRAG image by editing:

```text
argocd/apps/webrag/config/kustomization.yaml
```

Set:

```yaml
images:
  - name: ghcr.io/ass-nss-project/webrag-backend
    newTag: kost-<sha>
  - name: ghcr.io/ass-nss-project/webrag-frontend
    newTag: kost-<sha>
```

## LLM Inference

The production cluster is CPU-only, so WebRAG uses CERIT-SC AIaaS or another OpenAI-compatible endpoint for LLM/VLM inference.

Why not local LLMs:

- No GPUs on worker nodes.
- CPU inference for 7B-8B models is too slow for interactive RAG.
- Metacentrum Grid is batch-oriented and unsuitable for low-latency API calls.

BGE-M3 embeddings still run locally in the API/worker containers because the model is small enough for CPU inference and avoids external embedding dependency.

## Common Recovery

**Traefik waits for missing Keycloak credentials**

Run `terraform/keycloak`, force ESO re-sync, and restart Traefik.

**Vault TLS or Traefik secret bootstrap loop**

Use `terraform/vault/bootstrap.sh` to port-forward directly to Vault and populate required secrets.

**Stale GCS state lock**

Verify no apply is running, then use `terraform force-unlock <lock-id>`.
