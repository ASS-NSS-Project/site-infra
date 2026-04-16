# CLAUDE.md — site-infra

Read `README.md` and the `docs/` layer files to understand the project. The rules below are the only things that can't be inferred from the code.

## Non-negotiable rules

- Working branch is `kost`. All ArgoCD `targetRevision` fields point here. PRs target `main`.
- Rollback via `git revert` — never `argocd app rollback`. ArgoCD self-heals from git.
- Never read or suggest committing: `terraform.tfvars`, `*.tfstate`, `clouds.yaml`, `*-Secret.yaml`, `kubeconfig`, `kms-sa-key.json`, private keys.
- Secrets live in Vault. Kubernetes gets them only via ExternalSecret → ESO → Vault. Never inject them directly.
- Do not touch stateful helm apps (longhorn-helm, vault-helm) without explicit confirmation — they own PVCs.
- Layer READMEs live in `docs/`, not inside their source directories — GitHub would shadow the root README otherwise. Update the relevant `docs/` file whenever you change `terraform/`, `ansible/`, `argocd/`, or CI.
