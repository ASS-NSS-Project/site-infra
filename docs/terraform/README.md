# Terraform

Three independent root modules — each has its own GCS backend state and must be applied in the order defined in the root README.

## Modules and their dependencies

`infra/` runs first, with no dependencies. It provisions all OpenStack resources and writes two files that Ansible needs: `ansible/inventory/host_vars/cp-0.yml` and `ansible/inventory/group_vars/all/terraform.yml`. If those files are missing, re-run `terraform apply` in `infra/`.

`vault/` runs after Vault has been initialized (`vault operator init`). It configures the KV v2 engine, stores service credentials, and sets up Kubernetes auth for ESO.

`keycloak/` runs last, after Keycloak is deployed and Vault is provisioned. It creates the realm, Google OIDC identity provider, OIDC clients, and pushes client secrets to Vault.

## File conventions

Files are numbered: `00-providers.tf` always first (backend + providers), then `01-*.tf`, `02-*.tf` — one logical resource group per file. Don't merge unrelated resources into one file.

Current files:

```text
terraform/
├── infra/
│   ├── 00-providers.tf                   # GCS backend + OpenStack + GCP providers
│   ├── 01-openstack-network.tf           # router, subnet, network
│   ├── 02-openstack-secgroups.tf         # external and internal security groups
│   ├── 03-openstack-ports.tf             # fixed-IP ports for each node
│   ├── 04-openstack-instances.tf         # control plane and worker VMs
│   ├── 05-openstack-volumes.tf           # Cinder volumes for RKE2 and Longhorn
│   ├── 06-openstack-loadbalancers.tf     # Octavia LB for API and ingress
│   ├── 07-openstack-floating-ips.tf      # FIPs for cp-0 and ingress LB
│   ├── 08-ansible-inventory.tf           # writes host_vars and group_vars for Ansible
│   └── 09-gcp-kms.tf                     # KMS key ring and key for Vault auto-unseal
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

All three modules use the GCS backend (`k3s-cluster` bucket) — authenticate with `gcloud auth application-default login`. The `infra/` module also needs `clouds.yaml` for OpenStack credentials (gitignored).

## Lock files

`.terraform.lock.hcl` is committed for all three modules. It pins exact provider versions and checksums. Update it intentionally with `terraform init -upgrade` when upgrading a provider, then commit the result.
