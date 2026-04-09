# Site Infrastructure

Kubernetes cluster on OpenStack (Metacentrum MetaVO / e-INFRA CZ) using Terraform + Ansible + ArgoCD (GitOps).

## Stack

| Layer | Technology |
|-------|-----------|
| Infrastructure | OpenStack (Metacentrum MetaVO, Brno) |
| Provisioning | Terraform |
| Configuration | Ansible |
| Kubernetes | k3s v1.32.3 (3-node HA control plane) |
| GitOps | ArgoCD |
| Ingress | Traefik v3 (Gateway API, DaemonSet on CPs) |
| Load Balancer | OpenStack Octavia (API LB + Ingress LB) |
| TLS | cert-manager + Let's Encrypt HTTP-01 |
| Storage | Longhorn (LVM over Cinder volumes) |
| Registry | Harbor (container image registry) |

## Cluster layout

| Node | Flavor | vCPU | RAM | Private IP | Extra storage |
|------|--------|------|-----|------------|---------------|
| cp-0 | e1.large | 4 | 8 GB | 192.168.0.10 | 1 × 111 GB → `/var/lib/rancher/k3s` |
| cp-1 | e1.large | 4 | 8 GB | 192.168.0.11 | 1 × 111 GB → `/var/lib/rancher/k3s` |
| cp-2 | e1.large | 4 | 8 GB | 192.168.0.12 | 1 × 111 GB → `/var/lib/rancher/k3s` |
| worker-0 | e1.4core-16ram | 4 | 16 GB | 192.168.0.20 | 3 × 111 GB → LVM → `/var/lib/longhorn` |
| worker-1 | e1.4core-16ram | 4 | 16 GB | 192.168.0.21 | 3 × 111 GB → LVM → `/var/lib/longhorn` |

**Totals**: 5 instances / 20 vCPU / 56 GB RAM / 9 Cinder volumes / 999 GB

### Load balancers

| Name | Private VIP | Purpose |
|------|-------------|---------|
| k8s-api-lb | 192.168.0.100 | k3s API (port 6443) → all 3 CPs |
| k8s-ingress-lb | 192.168.0.101 | HTTP/HTTPS (→ NodePort 30080/30443 on CPs) |

### Floating IPs

| Assigned to | Used for |
|-------------|----------|
| cp-0 | SSH bastion — only node directly reachable from the internet |
| API LB | kubectl access + k3s node join endpoint |
| Ingress LB | HTTP/HTTPS traffic — **point all DNS A records here** |

## Repository structure

```
├── terraform/          # OpenStack IaC (network, instances, volumes, LBs, FIPs)
├── ansible/
│   ├── site.yml        # Main playbook
│   ├── inventory/      # hosts.yml + group_vars
│   └── roles/
│       ├── local.system/   # Timezone, NTP, users, SSH keys, disk setup
│       ├── local.k3s/      # k3s server (init + join) + agent installation
│       └── local.argocd/   # Helm + Gateway API CRDs + ArgoCD bootstrap
└── k8s/
    ├── apps/           # ArgoCD App of Apps (one Application per component)
    ├── helm-values/    # Helm values files for all charts
    ├── traefik/        # GatewayClass + Gateway + HTTP→HTTPS redirect
    ├── cert-manager/   # ClusterIssuers (prod, staging, self-signed)
    ├── longhorn/       # Longhorn HTTPRoute
    ├── argocd/         # ArgoCD HTTPRoute
    └── harbor/         # Harbor HTTPRoute
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

`terraform apply` automatically writes two files from live resource outputs:
- `ansible/inventory/hosts.yml` — cp-0 floating IP filled in
- `ansible/inventory/group_vars/all/terraform.yml` — API LB floating IP for kubeconfig + TLS SANs

The only manual step remaining is updating DNS A records:
```bash
terraform output ingress_lb_public_ip
# → point all hostnames to this IP
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
| `--tags k3s` | k3s HA control plane (init + join) + k3s agents on workers |
| `--tags bootstrap` | Helm install, Gateway API CRDs, ArgoCD, all ArgoCD Applications |

The full playbook in order:

| Play | Hosts | Description |
|------|-------|-------------|
| 1 — System setup | all | OS configuration, disk setup |
| 2 — k3s init | cp_primary (cp-0) | `--cluster-init`, fetches kubeconfig to `artifacts/kubeconfig` |
| 3 — k3s join | cp_followers (cp-1, cp-2) | Join cluster via API LB VIP |
| 4 — k3s workers | workers | k3s agents, join cluster via API LB VIP |
| 5 — Bootstrap ArgoCD | cp-0 | Installs Helm, Gateway API CRDs, ArgoCD via Helm, applies root App of Apps |
| 6 — Deploy ArgoCD applications | cp-0 | Applies all `k8s/apps/` manifests directly |

> **Note**: Only cp-0 has a floating IP. Ansible reaches cp-1, cp-2, and workers via SSH ProxyJump through cp-0 (configured automatically in `group_vars/cp_followers.yml` and `group_vars/workers.yml`).

### 3. GitOps — ArgoCD takes over

Once bootstrapped, ArgoCD syncs `k8s/apps/` from this repo and deploys all components in sync waves:

| Wave | Applications deployed |
|------|-----------------------|
| 1 | `traefik`, `cert-manager`, `longhorn`, `harbor` (Helm charts) |
| 2 | `traefik-config` (Gateway + GatewayClass), `cert-manager-config` (ClusterIssuers) |
| 3 | `longhorn-config`, `argocd-config`, `harbor-config` (HTTPRoutes) |

Monitor sync status:
```bash
export KUBECONFIG=artifacts/kubeconfig
kubectl -n argocd get applications
```

## DNS records

All A records point to the **Ingress LB floating IP** (`terraform output ingress_lb_public_ip`):

| Hostname | Service |
|----------|---------|
| `ass-nss.jkuzel02.online` | Root domain |
| `argocd.ass-nss.jkuzel02.online` | ArgoCD UI |
| `longhorn.ass-nss.jkuzel02.online` | Longhorn UI |
| `harbor.ass-nss.jkuzel02.online` | Harbor container registry |

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

1. Add a DNS A record → Ingress LB floating IP
2. Add an HTTPS listener in `k8s/traefik/gateway.yaml`
3. Add a `Certificate` in `k8s/cert-manager/clusterissuer-prod.yaml`
4. Add an `HTTPRoute` in your application namespace
5. Push to `kost` branch — ArgoCD applies automatically

## Harbor container registry

UI: `https://harbor.ass-nss.jkuzel02.online`

Initial credentials: `admin` / `Harbor12345` — **change on first login**.

To use Harbor as the image registry:
```bash
docker login harbor.ass-nss.jkuzel02.online
docker tag myimage harbor.ass-nss.jkuzel02.online/<project>/myimage:tag
docker push harbor.ass-nss.jkuzel02.online/<project>/myimage:tag
```

To pull images in Kubernetes, create an image pull secret:
```bash
kubectl create secret docker-registry harbor-credentials \
  --docker-server=harbor.ass-nss.jkuzel02.online \
  --docker-username=<user> \
  --docker-password=<password> \
  -n <namespace>
```

## Longhorn storage

- **Raw capacity**: 333 GB per worker (3 × 111 GB), 666 GB total
- **Usable capacity**: ~333 GB with 2-replica default (666 GB ÷ 2)
- **Default StorageClass**: `longhorn`
- **UI**: `https://longhorn.ass-nss.jkuzel02.online`
