# CI

All jobs run on every push to `kost` branch. Jobs are independent and run in parallel.

## Jobs

### Conventional commits

Enforces [Conventional Commits](https://www.conventionalcommits.org/) on every commit message. Uses `conventional-pre-commit` via `pre-commit` — config in `config/pre-commit-config.yaml`.

Allowed types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`, `build`, and others from the conventional commits spec.

**Implementation:** Extracts commit message from the most recent commit (or PR head for pull requests) and runs `pre-commit run --hook-stage commit-msg` to validate format.

### Terraform format

Runs `terraform fmt -check -recursive terraform/` to verify all `.tf` files are properly formatted. Does not auto-fix — run `terraform fmt -recursive terraform/` locally before committing. VSCode format-on-save handles this automatically with the HashiCorp Terraform extension.

**Uses:** Terraform 1.11

### Kubernetes manifest validation

Runs [kubeconform](https://github.com/yannh/kubeconform) against all `config/` manifests in `argocd/apps/`. Validates standard Kubernetes resources against upstream schemas for version 1.31. CRDs (ArgoCD, cert-manager, ESO, Traefik, etc.) are skipped with `--ignore-missing-schemas` — schema errors in CRDs will not be caught here.

**Excluded from validation:**
- `*-Application.yaml` (ArgoCD apps, not K8s resources)
- `kustomization.yaml`
- Everything under `helm/` (Helm values files)

**Command:**
```bash
find argocd/apps -name "*.yaml" ! -name "*-Application.yaml" ! -name "kustomization.yaml" ! -path "*/helm/*" \
  | xargs kubeconform --ignore-missing-schemas --kubernetes-version 1.31.0 --summary
```

---

## Removed Jobs

The following jobs were present in earlier versions but have been removed from the CI pipeline:

- **Markdown lint** — removed
- **Terraform validate** — removed (syntax checked by `terraform fmt`)
- **Terraform security scan (tfsec)** — removed
- **Ansible lint** — removed
- **Terraform tfvars example sync** — removed (script still exists in `.github/scripts/check-tfvars-example.sh` but not called)
- **YAML lint** — removed
- **Kubernetes best practices (kube-score)** — removed

These tools can still be run locally if needed.

---

## Config Files

| File | Used by |
|------|---------|
| `config/pre-commit-config.yaml` | Conventional commits job |
| `config/ansible-lint.yaml` | (not used in CI, local only) |
| `config/markdownlint.yaml` | (not used in CI, local only) |
| `config/yamllint.yaml` | (not used in CI, local only) |

---

## Scripts

| File | Purpose | Used in CI |
|------|---------|------------|
| `scripts/check-tfvars-example.sh` | Verify tfvars.example matches variable declarations | No (historical) |
