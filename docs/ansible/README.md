# Ansible

Ansible configures cluster nodes and bootstraps ArgoCD. Once ArgoCD is running, it takes over all application delivery — do not manage Kubernetes resources from Ansible beyond the bootstrap phase.

## Inventory

```text
rke2_cluster
├── control_plane: cp-0 (init), cp-1, cp-2 (join)
└── workers: worker-0..3
```

Only `cp-0` has a floating IP. All other nodes are reached via SSH ProxyJump through cp-0. Plays 3 and 4 run on `localhost` using `artifacts/kubeconfig`.

Static files (commit): `hosts.yml`, `host_vars/cp-1.yml`, `host_vars/cp-2.yml`, `host_vars/worker-*.yml`

Generated/gitignored:

- `inventory/host_vars/cp-0.yml` and `inventory/group_vars/all/terraform.yml` — written by `terraform/openstack`
- `artifacts/kubeconfig` — fetched from cp-0 by the rke2 role, needed by plays 3 and 4

## Playbook

`site.yml` runs 4 plays in order. Run individual plays with tags:

- `--tags system` — timezone, NTP, users, SSH keys, open-iscsi, LVM disk setup
- `--tags rke2` — RKE2 init on cp-0, join on cp-1/cp-2, agent on workers
- `--tags argocd` — Gateway API CRDs + ArgoCD Helm install
- `--tags argocd,apps` — bootstrap secrets, AppProjects, root Application

## Linting

`ansible-lint` runs in CI on `ansible/site.yml`. Config is in `.github/config/ansible-lint.yaml` — suppresses `galaxy[no-runtime]` (local roles don't need `runtime.yml`) and `yaml[line-length]` (handled by yamllint). Add suppressions there rather than inline `# noqa` comments unless the suppression is truly one-off.

## Roles

All roles use the `local.` prefix — follow this for any new ones.

`local.system` handles OS baseline for all nodes: timezone, NTP, users, SSH keys, open-iscsi. Disk setup is dispatched by group: workers get LVM over 3 Cinder volumes for Longhorn, control plane nodes get a single extra disk for RKE2.

`local.rke2` dispatches by group and inventory position: cp-0 runs init, cp-1/cp-2 run join, workers run the agent. Join tasks gate on port 9345 being reachable on the LB VIP — all nodes can start in parallel.

`local.argocd` installs Gateway API CRDs then ArgoCD via Helm, using values from `files/k8s/helm/argocd/values.yaml`.
