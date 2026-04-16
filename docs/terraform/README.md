# Terraform

Four independent root modules — each has its own GCS backend state and must be applied in the order defined in the root README.

## Modules and their dependencies

`gcp/` and `openstack/` run first and are independent of each other — apply them in parallel or in either order. `cloudflare/` runs immediately after `openstack/`, before Ansible, so DNS resolves when cert-manager starts issuing certificates.

`gcp/` provisions all GCP resources: the KMS key ring and crypto key for Vault auto-unseal, the service account with encrypter/decrypter permissions, and writes the service account JSON key to `ansible/files/vault/kms-sa-key.json` for Ansible to pick up.

`openstack/` provisions all OpenStack resources and writes two files that Ansible needs: `ansible/inventory/host_vars/cp-0.yml` and `ansible/inventory/group_vars/all/terraform.yml`. If those files are missing, re-run `terraform apply` in `openstack/`.

`cloudflare/` creates one A record for `nss.jkzl.eu` pointing to the cluster ingress LB IP (taken from `terraform output ingress_lb_public_ip` in `openstack/`) and CNAME records for all service subdomains.

`vault/` runs after Vault has been initialized (`vault operator init`). It configures the KV v2 engine, stores service credentials, and sets up Kubernetes auth for ESO.

`keycloak/` runs last, after Keycloak is deployed and Vault is provisioned. It creates the realm, Google OIDC identity provider, OIDC clients, pushes client secrets to Vault, and manages groups and user pre-provisioning.

### Keycloak groups

Five groups are defined in `01-realm.tf`. Access per service is enforced at the application layer — Keycloak only issues the group claim:

| Group | Purpose |
|-------|---------|
| `admin` | Full access to all services and infrastructure |
| `curator` | Data source management, collection rules, legal titles |
| `analytic` | Experiments, model testing, index quality; Grafana Viewer |
| `user` | Standard end user — submits queries, views answers |
| `unauthorized` | Explicitly blocked; no access to any service |

Users are pre-created by Gmail address via `keycloak_user` resources. On first Google login, Keycloak matches by email and links the Google identity automatically. Add Gmail addresses to the corresponding `*_members` variable in `terraform.tfvars` and re-apply. If a user already logged in before being added, import them first:

```bash
terraform import 'keycloak_user.admin["their@gmail.com"]' <realm-id>/users/<user-id>
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
├── openstack/
│   ├── 00-providers.tf       # GCS backend + OpenStack provider
│   ├── 01-network.tf         # router, subnet, network
│   ├── 02-secgroups.tf       # external and internal security groups
│   ├── 03-ports.tf           # fixed-IP ports for each node
│   ├── 04-instances.tf       # control plane and worker VMs
│   ├── 05-volumes.tf         # Cinder volumes for RKE2 and Longhorn
│   ├── 06-loadbalancers.tf   # Octavia LB for API and ingress
│   ├── 07-floating-ips.tf    # FIPs for cp-0 and ingress LB
│   └── 08-ansible-inventory.tf  # writes host_vars and group_vars for Ansible
├── vault/
│   ├── 00-providers.tf          # GCS backend + Vault provider
│   ├── 01-vault.tf              # KV v2 engine and service credentials
│   └── 02-vault-k8s-auth.tf     # Kubernetes auth backend for ESO
└── keycloak/
    ├── 00-providers.tf          # GCS backend + Keycloak + Vault providers
    ├── 01-realm.tf              # realm definition
    ├── 02-identity-providers.tf # Google OIDC federation
    ├── 03-clients.tf            # OIDC clients per service
    ├── 04-vault-secrets.tf      # pushes client secrets to Vault
    └── 05-vault-oidc.tf         # Vault OIDC auth method
```

## Secrets and auth

`terraform.tfvars` is gitignored — never commit it. `terraform.tfvars.example` is committed with placeholder values — keep it in sync with actual variables when adding new ones. CI enforces this automatically for `vault/` and `keycloak/` via `.github/scripts/check-tfvars-example.sh`.

All four modules use the GCS backend (`site-infra` bucket) — authenticate with `gcloud auth application-default login`. The `openstack/` module also needs `clouds.yaml` for OpenStack credentials (gitignored).

## Lock files

`.terraform.lock.hcl` is committed for all four modules. It pins exact provider versions and checksums. Update it intentionally with `terraform init -upgrade` when upgrading a provider, then commit the result.

## Troubleshooting

### GCS backend: state writes fail with 404

`terraform init` may succeed (the bucket is reachable) but `terraform apply` then fails with a misleading 404 on the lock file:

```text
Error loading state: writing "gs://site-infra/terraform/gcp/state/default.tflock" failed:
googleapi: Error 404: The specified bucket does not exist., notFound
```

GCS returns 404 instead of 403 when the authenticated identity lacks write permissions — the bucket exists but your credentials can't write to it. Fix:

```bash
# Check which identity you're using
gcloud auth application-default print-access-token

# Re-authenticate if needed
gcloud auth application-default login

# Or grant write access explicitly
gsutil iam ch user:YOUR_EMAIL:objectAdmin gs://site-infra
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
