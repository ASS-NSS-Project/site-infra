# CLAUDE.md — site-infra

Context for Claude Code. Read this before touching anything.

## Keep docs in sync

Every change must be reflected in the right documentation file. README is for humans operating the system. CLAUDE.md files are for understanding conventions and structure.

Each layer owns its documentation: update `README.md` for anything user-facing (URLs, cluster layout, deployment steps), this file for project-wide conventions, and the layer's own README under `docs/` for anything scoped to that layer.

All layer READMEs live in `docs/` — not inside their respective source directories. This is intentional: GitHub renders any `README.md` it finds in a directory as that directory's description, which means a `terraform/README.md` or `.github/README.md` would shadow or replace the root `README.md` when browsing the repo. Keeping docs in `docs/` avoids that collision. When you add or change anything in `terraform/`, `ansible/`, `argocd/`, or CI, update the corresponding file in `docs/`.

Layer READMEs are imported at the bottom of this file.

When unsure: README is for running the system, CLAUDE.md is for building it.

## Overview

Kubernetes cluster on OpenStack (Metacentrum MetaVO) provisioned with Terraform + Ansible, managed by ArgoCD.

Working branch: `kost`. All ArgoCD `targetRevision` fields point here. PRs target `main`.

## Deployment order

Each step gates the next — do not skip ahead:

```text
terraform/infra → ansible → [ArgoCD auto-syncs] → vault operator init → terraform/vault → terraform/keycloak
```

Details for each layer live in the layer's own README.md file.

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

## CI

All validation runs in GitHub Actions on push to `kost`. Jobs are documented in `.github/README.md`. The short version of what's enforced:

- Commit messages must follow Conventional Commits
- YAML, Markdown, and Terraform formatting are checked — fix locally before pushing
- Terraform modules are validated and scanned for security issues
- Ansible playbooks are linted
- Kubernetes manifests in `argocd/apps/` are validated against upstream schemas and scored for best practices
- `terraform.tfvars.example` must stay in sync with declared variables

## Security rules

- Never read or suggest committing: `terraform.tfvars`, `*.tfstate`, `clouds.yaml`, `*-Secret.yaml`, `kubeconfig`, `kms-sa-key.json`, private keys.
- Rollback via `git revert` — never `argocd app rollback`. ArgoCD self-heals from git.
- Secrets live in Vault. Kubernetes gets them only via ExternalSecret → ESO → Vault. Never inject them directly.
- Do not touch stateful helm apps (longhorn-helm, vault-helm, harbor-helm) without explicit confirmation — they own PVCs.

## Layer documentation

@docs/terraform/README.md
@docs/ansible/README.md
@docs/argocd/README.md
@docs/.github/README.md
