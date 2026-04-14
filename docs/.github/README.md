# CI

All jobs run on every push to `kost` branch. Jobs are independent and run in parallel.

## Jobs

### Conventional commits

Enforces [Conventional Commits](https://www.conventionalcommits.org/) on every commit message. Uses `conventional-pre-commit` via `pre-commit` — config in `config/pre-commit-config.yaml`.

Allowed types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`, and others from the conventional commits spec.

### Markdown lint

Runs `markdownlint-cli` on all `.md` files not in `.gitignore`. Config in `config/markdownlint.yaml`. Line length and inline HTML are not enforced.

### Terraform format

Runs `terraform fmt -check -recursive terraform/` to verify all `.tf` files are properly formatted. Does not auto-fix — run `terraform fmt -recursive terraform/` locally before committing. VSCode format-on-save handles this automatically with the HashiCorp Terraform extension.

### Terraform validate

Runs `terraform validate` on each of the three modules (`infra`, `vault`, `keycloak`) in parallel via a matrix. Uses `init -backend=false` to skip GCS and provider auth — only syntax and internal references are checked.

### Terraform security scan

Runs [tfsec](https://github.com/aquasecurity/tfsec) across all three modules. Flags security issues such as open ingress rules, unencrypted storage, or overly broad policies. Add `#tfsec:ignore:<rule>` inline to suppress intentional findings.

### Ansible lint

Runs `ansible-lint` on `ansible/site.yml` with all collections installed first. Catches deprecated syntax, missing `changed_when`, incorrect module usage, and other best-practice violations. Config in `.github/config/ansible-lint.yaml` — suppresses `galaxy[no-runtime]` (local roles don't need `runtime.yml`) and `yaml[line-length]` (handled by the YAML lint job).

### Terraform tfvars example sync

Runs `.github/scripts/check-tfvars-example.sh` to verify that every variable declared in a module's `.tf` files is present in `terraform.tfvars.example` and vice versa. Applies to `vault` and `keycloak` modules only — `infra` uses `clouds.yaml` for credentials instead of a tfvars file.

### YAML lint

Runs `yamllint` across the entire repo. Config in `config/yamllint.yaml`. Notable rules:

- Line length: 120 chars (warning only, not a failure)
- `document-start` (`---`): optional — Ansible uses it, Kubernetes often doesn't
- `truthy`: allows both `true`/`false` (Kubernetes) and `yes`/`no` (Ansible)
- Brackets: allows spaces inside (Ansible role lists use `[ "role.name" ]` style)

### Kubernetes manifest validation

Runs [kubeconform](https://github.com/yannh/kubeconform) against all `config/` manifests in `argocd/apps/`. Validates standard Kubernetes resources against upstream schemas for version 1.31. CRDs (ArgoCD, cert-manager, ESO, Traefik, etc.) are skipped with `--ignore-missing-schemas` — schema errors in CRDs will not be caught here.

Excluded from validation: `*-Application.yaml` (ArgoCD apps, not K8s resources), `kustomization.yaml`, and everything under `helm/`.

### Kubernetes best practices

Runs [kube-score](https://github.com/zegl/kube-score) on the same manifest set as kubeconform. Scores resources for reliability and security best practices — resource limits, liveness/readiness probes, security contexts, etc. Only critical findings (red) fail the build; warnings (yellow) are informational.

## Config files

| File | Used by |
|------|---------|
| `config/yamllint.yaml` | YAML lint |
| `config/markdownlint.yaml` | Markdown lint |
| `config/pre-commit-config.yaml` | Conventional commits |
