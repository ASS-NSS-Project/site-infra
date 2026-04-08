# Site Infrastructure

Kubernetes cluster on OpenStack (Metacentrum MetaVO / e-INFRA CZ) using Terraform + Ansible + ArgoCD (GitOps).

## Stack

| Layer | Technology |
|-------|-----------|
| Infrastructure | OpenStack (Metacentrum MetaVO, Brno) |
| Provisioning | Terraform |
| Configuration | Ansible |
| Kubernetes | k3s v1.32.3 |
| GitOps | ArgoCD |
| Ingress | Traefik v3 (Gateway API) |
| TLS | cert-manager + Let's Encrypt HTTP-01 |
| Storage | Longhorn (LVM over Cinder volumes) |

## Cluster layout

| Node | Flavor | vCPU | RAM | Extra storage |
|------|--------|------|-----|---------------|
| k8s-control-plane | e1.large | 4 | 8 GB | 1 × 100 GB → `/var/lib/rancher/k3s` |
| k8s-worker-0 | e1.4core-16ram | 4 | 16 GB | 3 × 100 GB → LVM → `/var/lib/longhorn` |
| k8s-worker-1 | e1.4core-16ram | 4 | 16 GB | 3 × 100 GB → LVM → `/var/lib/longhorn` |
| k8s-worker-2 | e1.4core-16ram | 4 | 16 GB | 3 × 100 GB → LVM → `/var/lib/longhorn` |

**Totals**: 4 instances / 16 vCPU / 56 GB RAM / 10 Cinder volumes / 1000 GB

## Repository structure

```
├── terraform/          # OpenStack infrastructure (instances, volumes, security groups, FIP)
├── ansible/
│   ├── site.yml        # Main playbook
│   ├── inventory/      # hosts.yml + group_vars
│   └── roles/
│       ├── local.system/   # Timezone, NTP, users, SSH keys, disk setup
│       ├── local.k3s/      # k3s server + agent installation
│       └── local.argocd/   # Helm + Gateway API CRDs + ArgoCD bootstrap
└── k8s/
    ├── apps/           # ArgoCD App of Apps (one Application per component)
    ├── helm-values/    # Helm values files for all charts
    ├── traefik/        # GatewayClass + Gateway + HTTP→HTTPS redirect
    ├── cert-manager/   # ClusterIssuers (prod, staging, self-signed)
    ├── longhorn/       # Longhorn HTTPRoute
    └── argocd/         # ArgoCD HTTPRoute
```

## Prerequisites

- Terraform >= 1.11
- Ansible >= 2.16
- `clouds.yaml` at `terraform/clouds.yaml` (gitignored) — OpenStack application credentials

Install Ansible collections:
```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

## Deployment

### 1. Infrastructure — Terraform

```bash
cd terraform
terraform init
terraform apply
```

Copy the output IPs into `ansible/inventory/hosts.yml`:
```bash
terraform output
```

### 2. Cluster provisioning — Ansible

```bash
cd ansible
ansible-playbook site.yml
```

Available tags to run individual plays:

| Tag | What it runs |
|-----|-------------|
| `--tags system` | Timezone, NTP, users, SSH keys, LVM disk setup, open-iscsi |
| `--tags k3s` | k3s server on control plane + k3s agent on workers |
| `--tags bootstrap` | Helm install, Gateway API CRDs, ArgoCD, all ArgoCD Applications |

The full playbook in order:

| Play | Hosts | Description |
|------|-------|-------------|
| 1 — System setup | all | OS configuration, disk setup |
| 2 — k3s control plane | control_plane | k3s server, fetches kubeconfig to `artifacts/kubeconfig` |
| 3 — k3s workers | workers | k3s agents, join cluster via private network through jump host |
| 4 — Bootstrap ArgoCD | control_plane | Installs Helm, Gateway API CRDs, ArgoCD via Helm, applies root App of Apps |
| 5 — Deploy ArgoCD applications | control_plane | Applies all `k8s/apps/` manifests directly |

> **Note**: Workers have no public IP. Ansible reaches them via SSH ProxyJump through the control plane (configured automatically in `group_vars/workers.yml`).

### 3. GitOps — ArgoCD takes over

Once bootstrapped, ArgoCD syncs `k8s/apps/` from this repo and deploys all components in sync waves:

| Wave | Applications deployed |
|------|-----------------------|
| 1 | `traefik`, `cert-manager`, `longhorn` (Helm charts) |
| 2 | `traefik-config` (Gateway + GatewayClass), `cert-manager-config` (ClusterIssuers) |
| 3 | `longhorn-config` (HTTPRoute), `argocd-config` (HTTPRoute) |

Monitor sync status:
```bash
export KUBECONFIG=artifacts/kubeconfig
kubectl -n argocd get applications
```

## DNS records

All A records point to the control-plane floating IP (`147.251.255.198`):

| Hostname | Service |
|----------|---------|
| `ass-nss.jkuzel02.online` | Root domain |
| `argocd.ass-nss.jkuzel02.online` | ArgoCD UI |
| `longhorn.ass-nss.jkuzel02.online` | Longhorn UI |

## ArgoCD

UI: `https://argocd.ass-nss.jkuzel02.online`

Initial admin password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

The repo is **public** — ArgoCD pulls from `https://github.com/ASS-NSS-Project/site-infra` without credentials.

For a **private** repo, register credentials before applying the root app:
```bash
kubectl -n argocd create secret generic github-repo \
  --from-literal=type=git \
  --from-literal=url=https://github.com/ASS-NSS-Project/site-infra \
  --from-literal=username=<github-user> \
  --from-literal=password=<personal-access-token>
kubectl label secret github-repo -n argocd \
  argocd.argoproj.io/secret-type=repository
```

## TLS certificates

Three issuers are available in `k8s/cert-manager/`:

| Issuer | Use case |
|--------|---------|
| `letsencrypt-staging` | Testing — untrusted CA, no rate limits |
| `letsencrypt-prod` | Production — trusted, rate limited |
| `selfsigned-ca` | Offline / dev — import `selfsigned-ca-tls` secret as trusted CA |

cert-manager uses **HTTP-01 challenge** — one certificate per hostname (wildcard requires DNS-01).
Port 80 must be reachable from the internet during issuance. Renewals are automatic.

Export the self-signed CA for local trust:
```bash
kubectl -n cert-manager get secret selfsigned-ca-tls \
  -o jsonpath="{.data.ca\.crt}" | base64 -d > selfsigned-ca.crt
```

## Adding a new subdomain

1. Add a DNS A record → `147.251.255.198`
2. Add an HTTPS listener in `k8s/traefik/gateway.yaml`
3. Add a `Certificate` in `k8s/cert-manager/clusterissuer-prod.yaml`
4. Add an `HTTPRoute` in your application namespace
5. Push to `main` — ArgoCD applies automatically

## Longhorn storage

- **Raw capacity**: 300 GB per worker node (3 × 100 GB Cinder volumes via LVM)
- **Usable capacity**: ~450 GB with 2-replica default (900 GB ÷ 2)
- **Default StorageClass**: `longhorn`
- **UI**: `https://longhorn.ass-nss.jkuzel02.online`
