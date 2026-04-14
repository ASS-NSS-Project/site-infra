# CLAUDE.md — site-infra

Context for Claude Code. Read this before touching anything.

## Keep docs in sync

Every change must be reflected in the right documentation file. README is for humans operating the system. CLAUDE.md files are for understanding conventions and structure.

- Changed something user-facing (URLs, cluster layout, deployment steps, service config)? → update `README.md`
- Changed a project-wide convention (deployment order, ArgoCD settings, security rules)? → update this file
- Changed something Terraform-specific? → update `terraform/CLAUDE.md`
- Changed something Ansible-specific? → update `ansible/CLAUDE.md`
- Changed something ArgoCD-specific (app structure, sync waves, ExternalSecret pattern)? → update `argocd/CLAUDE.md`

When unsure: README is for running the system, CLAUDE.md is for building it.

## Overview

Kubernetes cluster on OpenStack (Metacentrum MetaVO) provisioned with Terraform + Ansible, managed by ArgoCD.

Working branch: `kost`. All ArgoCD `targetRevision` fields point here. PRs target `main`.

## Deployment order

Each step gates the next — do not skip ahead:

```
terraform/infra → ansible → [ArgoCD auto-syncs] → vault operator init → terraform/vault → terraform/keycloak
```

Details for each layer live in the layer's own CLAUDE.md file.

## Writing style

Comments and documentation in this repo are written in plain, natural English — as if explaining to a colleague, not writing a spec.

**In YAML files** (ArgoCD Applications, Kubernetes manifests, Ansible tasks): comments explain *why*, not *what*. The code shows what; the comment gives context a reader couldn't derive from the code alone. One sentence is usually enough.

```yaml
# Wave 1 — must be running before cert-manager can issue certificates
```

not:

```yaml
# traefik helm application
```

**In Terraform files**: block comments above resources explain the role of the resource in the system, not its type. File-level comments explain what the file owns.

**In Ansible tasks**: task `name` fields read as natural sentences, not slugs.

```yaml
- name: Wait for RKE2 API to become available before joining
```

not:

```yaml
- name: rke2_wait_api
```

**In Markdown files**: write in short, direct sentences. Use bullet lists when items are genuinely enumerable and parallel — checklists, option lists, file inventories. Prefer prose when the items have natural flow or depend on each other. Tables only when comparing multiple items across the same attributes.

## Security rules

- Never read or suggest committing: `terraform.tfvars`, `*.tfstate`, `clouds.yaml`, `*-Secret.yaml`, `kubeconfig`, `kms-sa-key.json`, private keys.
- Rollback via `git revert` — never `argocd app rollback`. ArgoCD self-heals from git.
- Secrets live in Vault. Kubernetes gets them only via ExternalSecret → ESO → Vault. Never inject them directly.
- Do not touch stateful helm apps (longhorn-helm, vault-helm, harbor-helm) without explicit confirmation — they own PVCs.
