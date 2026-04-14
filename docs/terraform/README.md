# Terraform

Four independent root modules — each has its own GCS backend state and must be applied in the order defined in the root README.

## Modules and their dependencies

`gcp/` and `openstack/` run first and are independent of each other — apply them in parallel or in either order.

`gcp/` provisions all GCP resources: the KMS key ring and crypto key for Vault auto-unseal, the service account with encrypter/decrypter permissions, and writes the service account JSON key to `ansible/files/vault/kms-sa-key.json` for Ansible to pick up.

`openstack/` provisions all OpenStack resources and writes two files that Ansible needs: `ansible/inventory/host_vars/cp-0.yml` and `ansible/inventory/group_vars/all/terraform.yml`. If those files are missing, re-run `terraform apply` in `openstack/`.

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
