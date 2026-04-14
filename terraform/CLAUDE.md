# terraform/CLAUDE.md

Three independent root modules — each has its own GCS backend state and must be applied in the order defined in the root CLAUDE.md.

## Modules and their dependencies

`infra/` runs first, with no dependencies. It provisions all OpenStack resources and writes two files that Ansible needs: `ansible/inventory/host_vars/cp-0.yml` and `ansible/inventory/group_vars/all/terraform.yml`. If those files are missing, re-run `terraform apply` in `infra/`.

`vault/` runs after Vault has been initialized (`vault operator init`). It configures the KV v2 engine, stores service credentials, and sets up Kubernetes auth for ESO.

`keycloak/` runs last, after Keycloak is deployed and Vault is provisioned. It creates the realm, Google OIDC identity provider, OIDC clients, and pushes client secrets to Vault.

## File conventions

Files are numbered: `00-providers.tf` always first (backend + providers), then `01-*.tf`, `02-*.tf` — one logical resource group per file. Don't merge unrelated resources into one file.

Current files:

- **infra/**: 00-providers, 01-network, 02-secgroups, 03-ports, 04-instances, 05-volumes, 06-loadbalancers, 07-floating-ips, 08-ansible-inventory, 09-gcp-kms
- **vault/**: 00-providers, 01-vault, 02-vault-k8s-auth
- **keycloak/**: 00-providers, 01-realm, 02-identity-providers, 03-clients, 04-vault-secrets, 05-vault-oidc

## Secrets and auth

`terraform.tfvars` is gitignored — never commit it. `terraform.tfvars.example` is committed with placeholder values — keep it in sync with actual variables when adding new ones.

All three modules use the GCS backend (`k3s-cluster` bucket) — authenticate with `gcloud auth application-default login`. The `infra/` module also needs `clouds.yaml` for OpenStack credentials (gitignored).
