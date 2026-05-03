# Terraform

Six independent root modules — each has its own GCS backend state and must be applied in the order defined in the root README.

## Modules and their dependencies

`gcp/` and `openstack/` run first and are independent of each other — apply them in parallel or in either order. `cloudflare/` runs immediately after `openstack/`, before Ansible, so DNS resolves when cert-manager starts issuing certificates.

`gcp/` provisions all GCP resources: the KMS key ring and crypto key for Vault auto-unseal, the service account with encrypter/decrypter permissions, and writes the service account JSON key to `ansible/files/vault/kms-sa-key.json` for Ansible to pick up.

`openstack/` provisions all OpenStack resources and writes two files that Ansible needs: `ansible/inventory/host_vars/cp-0.yml` and `ansible/inventory/group_vars/all/terraform.yml`. If those files are missing, re-run `terraform apply` in `openstack/`.

`cloudflare/` creates one A record for `nss.jkzl.eu` pointing to the cluster ingress LB IP (taken from `terraform output ingress_lb_public_ip` in `openstack/`) and CNAME records for all service subdomains (including `qdrant.nss.jkzl.eu`, `oauth2.nss.jkzl.eu`, `rag.nss.jkzl.eu`, `rabbitmq.nss.jkzl.eu`).

`du-cesnet/` provisions CESNET S3 buckets used in production (`longhorn-backups`, `rag-evidence-prod`, `rag-documents-prod`). Independent — run anytime before the Longhorn backup configuration is applied by ArgoCD and before RAG production secrets are validated.

`vault/` runs after Vault has been initialized (`vault operator init`). It configures the KV v2 engine, stores service credentials (including RAG system LLM/VLM/S3 credentials, Longhorn S3 backup credentials, Keycloak OIDC secrets), and sets up Kubernetes auth for ESO.

`keycloak/` runs after Vault is provisioned. It creates the realm, Google OIDC identity provider, OIDC clients (including the `traefik` client for oauth2-proxy and the `rag-rbac-sa` service account for role sync), pushes client secrets to Vault, and manages groups and user pre-provisioning. This is the last module in the apply chain.

### Keycloak groups

Four groups are defined in `01-realm.tf`. Access per service is enforced at the application layer — Keycloak only issues the group claim:

| Group | Purpose |
|-------|---------|
| `rag_admin` | Full infrastructure access: Keycloak realm-admin, Grafana Admin, Vault admin, RabbitMQ admin, RAG app admin |
| `rag_curator` | Source / pipeline / incident management |
| `rag_analyst` | Experiments, model testing, index quality evaluation; Grafana Viewer |
| `rag_user` | Standard end user — submits queries, views answers |

Users are pre-created by Gmail address via `keycloak_user` resources. Each user has `required_actions = []` to prevent Keycloak from prompting for profile completion on first login. On first Google login, Keycloak matches by email and links the Google identity automatically. Add Gmail addresses to the corresponding `*_members` variable in `terraform.tfvars` and re-apply. If a user already logged in before being added, import them first:

```bash
terraform import 'keycloak_user.rag_admin["their@gmail.com"]' <realm-id>/users/<user-id>
```

## File conventions

Files are numbered: `00-providers.tf` always first (backend + providers), then `01-*.tf`, `02-*.tf` — one logical resource group per file. Don't merge unrelated resources into one file.

Current files:

```text
terraform/
├── cloudflare/
│   ├── 00-providers.tf  # GCS backend + Cloudflare provider
│   └── 01-dns.tf        # A record for nss.jkzl.eu + CNAME records for all subdomains
├── gcp/
│   ├── 00-providers.tf  # GCS backend + GCP provider
│   └── 01-kms.tf        # KMS key ring, crypto key, service account for Vault auto-unseal
├── du-cesnet/
│   ├── terraform.tf     # GCS backend + S3 provider (CESNET Metacentrum)
│   ├── 01-buckets.tf    # Longhorn + RAG production buckets
│   └── 02-bucket-policies.tf # Bucket policies (deny anonymous)
├── openstack/
│   ├── 00-providers.tf       # GCS backend + OpenStack provider
│   ├── 01-network.tf         # router, subnet, network
│   ├── 02-secgroups.tf       # external and internal security groups
│   ├── 03-ports.tf           # fixed-IP ports for each node
│   ├── 04-instances.tf       # control plane and worker VMs
│   ├── 05-volumes.tf         # Cinder volumes for RKE2 and Longhorn
│   ├── 06-loadbalancers.tf   # Octavia LB for API and ingress
│   ├── 07-floating-ips.tf    # FIPs for cp-0 and ingress LB
│   ├── 08-ansible-inventory.tf  # writes host_vars and group_vars for Ansible
│   └── templates/            # Jinja2 templates for Ansible inventory generation
├── vault/
│   ├── terraform.tf             # GCS backend + Vault provider (vault_address variable for port-forward bootstrap)
│   ├── 01-vault.tf              # KV v2 engine and service credentials (RAG, Longhorn, Keycloak, Grafana, Alertmanager)
│   ├── 02-vault-k8s-auth.tf     # Kubernetes auth backend for ESO
│   └── bootstrap.sh             # Emergency script: port-forwards Vault pod, runs apply, forces ESO re-sync
└── keycloak/
    ├── 00-providers.tf          # GCS backend + Keycloak + Vault providers
    ├── 01-realm.tf              # realm definition + groups + user pre-provisioning
    ├── 02-identity-providers.tf # Google OIDC federation
    ├── 03-clients.tf            # OIDC clients: argocd, grafana, traefik (oauth2-proxy), rag-system, rag-rbac-sa (role sync)
    ├── 04-vault-secrets.tf      # pushes client secrets to Vault
    └── 05-vault-oidc.tf         # Vault OIDC auth method
```

## SSO for internal services (Longhorn, Prometheus, Alertmanager, Qdrant)

Longhorn, Prometheus, Alertmanager, and Qdrant do not have native OIDC support. They are protected by **oauth2-proxy** acting as a Traefik ForwardAuth middleware. Unauthenticated requests are redirected to Keycloak (via the `traefik` OIDC client created in `03-clients.tf`). Only users in the `rag_admin` Keycloak group can access these UIs.

### How the credentials flow

```text
terraform/keycloak/03-clients.tf
  → creates one "traefik" OIDC client in Keycloak
  → valid_redirect_uris covers all three services

terraform/keycloak/04-vault-secrets.tf
  → pushes client_id + client_secret to Vault at secret/oidc/traefik

argocd/apps/traefik/config/traefik-keycloak-ExternalSecret.yaml
  → ESO syncs secret/oidc/traefik → K8s Secret "traefik-keycloak-credentials"
    in the traefik namespace (keys: client-id, client-secret)

argocd/apps/traefik/helm/values.yaml
  → Traefik Deployment env:
      KEYCLOAK_CLIENT_ID     ← secretKeyRef traefik-keycloak-credentials/client-id
      KEYCLOAK_CLIENT_SECRET ← secretKeyRef traefik-keycloak-credentials/client-secret

argocd/apps/longhorn/config/longhorn-auth-Middleware.yaml
argocd/apps/kube-prometheus-stack/config/monitoring-auth-Middleware.yaml
  → Traefik Middleware CRDs reference $KEYCLOAK_CLIENT_ID / $KEYCLOAK_CLIENT_SECRET
    (Traefik plugin substitutes from its own env at runtime)

argocd/apps/longhorn/config/longhorn-ui-HTTPRoute.yaml
argocd/apps/kube-prometheus-stack/config/prometheus-HTTPRoute.yaml
argocd/apps/kube-prometheus-stack/config/alertmanager-HTTPRoute.yaml
  → HTTPRoutes attach the respective Middleware — all traffic goes through OIDC
```

### Why "Client not found" appears

`terraform/keycloak` has not been applied yet, so Vault has no value at `secret/oidc/traefik`. ESO cannot sync the secret, Traefik starts with empty env vars (`optional: true` prevents a crash), and the plugin cannot locate the client in Keycloak.

### How to fix it

1. Confirm Keycloak pod is running and healthy (`kubectl get pods -n keycloak`)
2. Confirm Vault is unsealed and ESO's `ClusterSecretStore` is ready
3. Apply the Keycloak Terraform module:

   ```bash
   cd terraform/keycloak
   terraform apply
   ```

4. Force ESO to re-sync immediately (instead of waiting up to 1 hour):

   ```bash
   kubectl annotate externalsecret traefik-keycloak-credentials \
     -n traefik force-sync="$(date +%s)" --overwrite
   ```

5. Restart Traefik to pick up the new env vars:

   ```bash
   kubectl rollout restart deployment/traefik -n traefik
   ```

After the rollout completes, `https://longhorn.nss.jkzl.eu`, `https://prometheus.nss.jkzl.eu`, and `https://alertmanager.nss.jkzl.eu` will redirect to Keycloak on first visit and admit users whose group membership is validated by the plugin.

---

## Secrets and auth

`terraform.tfvars` is gitignored — never commit it. `terraform.tfvars.example` is committed with placeholder values — keep it in sync with actual variables when adding new ones. CI enforces this automatically for `vault/` and `keycloak/` via `.github/scripts/check-tfvars-example.sh`.

All four modules use the GCS backend (`enc-ass-nss-project` bucket) — authenticate with `gcloud auth application-default login`. The `openstack/` module also needs `clouds.yaml` for OpenStack credentials (gitignored).

## Lock files

`.terraform.lock.hcl` is committed for all four modules. It pins exact provider versions and checksums. Update it intentionally with `terraform init -upgrade` when upgrading a provider, then commit the result.

## Troubleshooting

### Stale GCS state lock

If a previous `terraform apply` was interrupted, the GCS lock file may be left behind:

```text
Error: Error acquiring the state lock
Lock Info:
  ID:  1777160824954221
  Who: xkuzel@fedora
```

Force-unlock it — it is safe if no other apply is actually in progress (check the `Who` and `Created` fields):

```bash
terraform force-unlock 1777160824954221
```

---

### Bootstrap deadlock: Vault TLS broken, Traefik down, secrets missing

On a fresh cluster boot or after cert expiry, the following circular dependency can form:

```text
Vault TLS broken → ESO can't sync → Traefik secret missing → Traefik down
→ ACME challenges fail → certs can't issue → Vault TLS broken
```

Break it using `bootstrap.sh`, which port-forwards directly to the Vault pod (bypassing external TLS) and runs `terraform apply`:

```bash
export VAULT_TOKEN=<root-or-admin-token>
cd terraform/vault
./bootstrap.sh
```

The script uses `-var="vault_address=http://localhost:8200"` to override the provider's hardcoded URL. After apply succeeds, ESO re-syncs all secrets in the `traefik` namespace, Traefik pods start, ACME challenges run, and all certificates issue within ~2 minutes.

The root cause of Traefik being stuck is that the `traefik-keycloak-credentials` secret (synced from Vault path `secret/oidc/traefik`) did not exist yet. The Traefik Helm values mark this secret as `optional: true` so a missing secret no longer prevents startup — but the env vars will be empty until ESO syncs the real values.

---

### GCS backend: state writes fail with 404

`terraform init` may succeed (the bucket is reachable) but `terraform apply` then fails with a misleading 404 on the lock file:

```text
Error loading state: writing "gs://enc-ass-nss-project/terraform/gcp/state/default.tflock" failed:
googleapi: Error 404: The specified bucket does not exist., notFound
```

GCS returns 404 instead of 403 when the authenticated identity lacks write permissions — the bucket exists but your credentials can't write to it. Fix:

```bash
# Check which identity you're using
gcloud auth application-default print-access-token

# Re-authenticate if needed
gcloud auth application-default login

# Or grant write access explicitly
gsutil iam ch user:YOUR_EMAIL:objectAdmin gs://enc-ass-nss-project
```

### GCP KMS resources already exist (409 on first apply)

If the GCP module was applied before without Terraform managing the state, `apply` will fail with 409 conflicts on KMS resources. Import each conflicting resource into state rather than trying to recreate it:

```bash
terraform import google_kms_key_ring.vault \
  projects/enc-ass-nss-project/locations/global/keyRings/vault-keyring

terraform import google_kms_crypto_key.vault_unseal \
  projects/enc-ass-nss-project/locations/global/keyRings/vault-keyring/cryptoKeys/vault-unseal-key
```

After importing, `terraform plan` should show only the IAM bindings and local file as pending — no key ring or crypto key creation. Then `terraform apply` completes cleanly.

### OpenStack network quota exceeded (409 on first apply)

When redeploying into a project that already has a network and router from a previous deployment, `apply` fails with quota errors on `openstack_networking_network_v2` and `openstack_networking_router_v2`. The fix is to delete the leftover resources so Terraform can recreate them:

```bash
bash terraform/openstack/cleanup-network.sh
```

The script removes the router, subnet, and network in the correct dependency order, then Terraform creates them fresh on the next `apply`.
