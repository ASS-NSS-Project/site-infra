# Site Infrastructure

Kubernetes cluster on OpenStack (Metacentrum MetaVO / e-INFRA CZ) using Terraform + Ansible + ArgoCD (GitOps).

## Stack

| Layer | Technology |
|-------|-----------|
| Infrastructure | OpenStack (Metacentrum MetaVO, Brno) |
| Provisioning | Terraform |
| Configuration | Ansible |
| Kubernetes | RKE2 (3-node HA control plane) |
| GitOps | ArgoCD |
| Ingress | Traefik v3 (Gateway API, DaemonSet on CPs) |
| Load Balancer | OpenStack Octavia (API LB + Ingress LB) |
| TLS | cert-manager + Let's Encrypt HTTP-01 |
| Storage | Longhorn (LVM over Cinder volumes) |
| Registry | Harbor (container image registry) |
| Secrets | HashiCorp Vault |
| Database | CloudNativePG (PostgreSQL operator) |
| Identity | Keycloak (Keycloak Operator) |
| Monitoring | kube-prometheus-stack (Prometheus + Grafana + Alertmanager) |

## Cluster layout

| Node | Flavor | vCPU | RAM | Private IP | Extra storage |
|------|--------|------|-----|------------|---------------|
| cp-0 | c2.8core-16ram | 8 | 16 GB | 10.8.0.10 | 1 × 32 GB → `/var/lib/rancher/rke2` |
| cp-1 | c2.8core-16ram | 8 | 16 GB | 10.8.0.11 | 1 × 32 GB → `/var/lib/rancher/rke2` |
| cp-2 | c2.8core-16ram | 8 | 16 GB | 10.8.0.12 | 1 × 32 GB → `/var/lib/rancher/rke2` |
| worker-0 | c2.8core-30ram | 8 | 30 GB | 10.8.0.20 | 3 × 158 GB → LVM → `/var/lib/longhorn` |
| worker-1 | c2.8core-30ram | 8 | 30 GB | 10.8.0.21 | 3 × 158 GB → LVM → `/var/lib/longhorn` |
| worker-2 | c2.8core-30ram | 8 | 30 GB | 10.8.0.22 | 3 × 158 GB → LVM → `/var/lib/longhorn` |
| worker-3 | c2.8core-30ram | 8 | 30 GB | 10.8.0.23 | 3 × 158 GB → LVM → `/var/lib/longhorn` |

**Totals**: 7 instances / 56 vCPU / 168 GB RAM / 15 Cinder volumes / 1 992 GB

### Load balancers

| Name | Private VIP | Port | Purpose | Restricted to |
|------|-------------|------|---------|---------------|
| rke2-cluster-lb | 10.8.0.100 | 6443 | Kubernetes API | — |
| rke2-cluster-lb | 10.8.0.100 | 9345 | RKE2 node registration | `10.8.0.0/27` (cluster subnet only) |
| rke2-cluster-lb | 10.8.0.100 | 80 | HTTP ingress → Traefik | — |
| rke2-cluster-lb | 10.8.0.100 | 443 | HTTPS ingress → Traefik | — |

### Floating IPs

| Assigned to | Used for |
|-------------|----------|
| cp-0 | SSH bastion — only node directly reachable from the internet |
| Cluster LB | kubectl access + RKE2 node join endpoint + HTTP/HTTPS ingress |

## Repository structure

```
├── terraform/              # OpenStack IaC (network, instances, volumes, LBs, FIPs)
│   └── templates/          # Ansible inventory templates (rendered by terraform apply)
├── ansible/
│   ├── site.yml            # Main playbook (4 plays)
│   ├── inventory/          # hosts.yml (static) + host_vars/ + group_vars/
│   ├── artifacts/          # Runtime-generated files — gitignored
│   │   └── kubeconfig      # Fetched from cp-0 by the rke2 role
│   ├── files/
│   │   └── k8s/
│   │       ├── helm/argocd/values.yaml   # ArgoCD Helm values (Ansible-bootstrapped)
│   │       └── manifests/                # Secrets applied by Ansible before ArgoCD syncs
│   └── roles/
│       ├── local.system/   # Timezone, NTP, users, SSH keys, disk setup
│       ├── local.rke2/     # RKE2 server (init + join) + agent; dispatches by group
│       └── local.argocd/   # Gateway API CRDs + ArgoCD bootstrap via Helm
└── argocd/
    ├── root-Application.yaml           # App-of-apps root; scans argocd/apps/ recursively
    ├── projects/                        # ArgoCD AppProjects (RBAC / grouping)
    │   ├── infrastructure-AppProject.yaml
    │   └── observability-AppProject.yaml
    └── apps/                            # One subdirectory per component
        ├── <app>/
        │   ├── helm-Application.yaml    # ArgoCD Application deploying the Helm chart
        │   ├── config-Application.yaml  # ArgoCD Application for config resources
        │   ├── helm/values.yaml         # Helm values file
        │   └── config/                  # K8s manifests: <name>-<Kind>.yaml
        └── keycloak/
            ├── keycloak-operator-Application.yaml
            ├── keycloak-operator/kustomize-Application.yaml
            ├── keycloak-operator/kustomize/kustomization.yaml
            ├── config-Application.yaml
            └── config/
```

## Prerequisites

- Terraform >= 1.11
- Ansible >= 2.16
- Helm >= 3.0 — required by the `kubernetes.core.helm` module, must be in `PATH` on the machine running the playbook
- `clouds.yaml` at `terraform/clouds.yaml` (gitignored) — OpenStack application credentials

Install Python dependencies:
```bash
pip install -r requirements.txt
```

Install Ansible collections:
```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

## Deployment

### 1. Infrastructure — Terraform

Unlike Ansible's imperative approach, Terraform is **declarative** — you describe the desired end state and Terraform figures out what needs to be created, updated, or destroyed to reach it. Resource ordering follows automatically from the **dependency graph** — each resource declares which other resources it depends on (explicitly via `depends_on`, or implicitly by referencing their attributes), and Terraform applies them in the correct order, parallelising independent resources where possible.

Terraform compares the state file against your configuration on every `plan`. If the state is missing or out of sync with reality — e.g. a resource was deleted manually outside of Terraform — it will try to recreate it, which can cause conflicts or outright failures if the underlying provider rejects a duplicate. Keeping state intact and in sync is therefore critical.

Terraform state is stored remotely rather than locally so that the state file is not lost when cloning the repo fresh, multiple team members share a single source of truth.

Terraform state is stored remotely in a **Google Cloud Storage bucket** (`k3s-cluster`, prefix `terraform/state`), configured in `terraform/00-provider.tf`. This requires GCS credentials to be available before running any Terraform command — authenticate with `gcloud auth application-default login` or set the `GOOGLE_APPLICATION_CREDENTIALS` environment variable.

```bash
cd terraform
terraform init
terraform apply
```

`terraform apply` automatically writes two files from live resource outputs:
- `ansible/inventory/host_vars/cp-0.yml` — cp-0 floating IP (gitignored, regenerated on each apply)
- `ansible/inventory/group_vars/all/terraform.yml` — API LB floating IP for kubeconfig + TLS SANs

The only manual step remaining is updating DNS A records:
```bash
terraform output ingress_lb_public_ip
# → point all hostnames to this IP
```

### 2. Cluster provisioning — Ansible

Ansible executes tasks in **declaration order** — top to bottom within each play, play by play within the playbook. There is no dependency graph; ordering is the author's responsibility. The playbook is structured so that each play's prerequisites are guaranteed to be complete before the next one starts (e.g. RKE2 must be initialised before nodes can join, and the cluster must be healthy before ArgoCD is bootstrapped).

```bash
cd ansible
ansible-playbook site.yml
```

Available tags to run individual plays:

| Tag | What it runs |
|-----|-------------|
| `--tags system` | Timezone, NTP, users, SSH keys, LVM disk setup, open-iscsi |
| `--tags rke2` | RKE2 HA control plane (init + join) + RKE2 agents on workers |
| `--tags argocd` | Gateway API CRDs + ArgoCD Helm install |
| `--tags argocd,apps` | All of the above + apply secrets, ArgoCD projects, and root Application |

The full playbook in order:

| Play | Hosts | Description |
|------|-------|-------------|
| 1 — System setup | `rke2_cluster` (all nodes) | OS configuration, disk setup |
| 2 — Install RKE2 | `rke2_cluster` (all nodes) | Role dispatches init/join/worker by group; fetches `artifacts/kubeconfig` from cp-0 |
| 3 — Bootstrap ArgoCD | `localhost` | Installs Gateway API CRDs and ArgoCD via Helm using `artifacts/kubeconfig` |
| 4 — Deploy ArgoCD applications | `localhost` | Applies bootstrap Secrets, ArgoCD AppProjects, and the root Application |

> **Note**: Only cp-0 has a floating IP. Ansible reaches cp-1, cp-2, and workers via SSH ProxyJump through cp-0 (configured in `host_vars/` for each non-primary node). Plays 3 and 4 run entirely from localhost using `ansible/artifacts/kubeconfig`.

> **RKE2 join ordering**: cp-1, cp-2, and all workers wait for port 9345 on the LB VIP to be reachable before attempting to join, so all nodes can start in parallel — ordering is self-enforced by the role.

### 3. GitOps — ArgoCD takes over

Once bootstrapped, ArgoCD syncs `argocd/apps/` from this repo and deploys all components in **sync waves**.

Sync waves are a **deployment ordering mechanism**: ArgoCD applies all resources in wave N, waits for them to reach a healthy state, and only then proceeds to wave N+1. This guarantees that operators and core infrastructure are fully ready before the resources that depend on them are created — for example, the CNPG operator (wave 1) must be running and its CRDs registered before a `Cluster` resource (wave 2) can be applied, and the Traefik Gateway (wave 2) must be up before HTTPRoutes (wave 3) can be programmed.

| Wave | Applications deployed | Why this wave |
|------|-----------------------|---------------|
| 1 | `traefik`, `cert-manager`, `longhorn`, `harbor`, `vault`, `cnpg`, `kube-prometheus-stack` (Helm charts), `keycloak-operator` (CRDs + controller) | Core infrastructure and operators — must be running before anything depends on them |
| 2 | `traefik-config` (Gateway + GatewayClass), `cert-manager-config` (ClusterIssuers), `keycloak-postgres` (CNPG Cluster) | Requires wave 1: Gateway needs Traefik, ClusterIssuers need cert-manager, CNPG Cluster needs the CNPG operator |
| 3 | `longhorn-config`, `argocd-config`, `harbor-config`, `vault-config`, `keycloak-config` (Keycloak CR + HTTPRoute), `grafana-config` (HTTPRoute) | Requires wave 2: HTTPRoutes need the Gateway to exist, Keycloak needs its database |

Monitor sync status:
```bash
export KUBECONFIG=ansible/artifacts/kubeconfig
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
| `vault.ass-nss.jkuzel02.online` | HashiCorp Vault |
| `keycloak.ass-nss.jkuzel02.online` | Keycloak |
| `grafana.ass-nss.jkuzel02.online` | Grafana |

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

### ArgoCD AppProjects

Applications are grouped into AppProjects for RBAC and organisational clarity:

| Project | Applications |
|---------|-------------|
| `infrastructure` | traefik, cert-manager, longhorn, cnpg, argocd-config |
| `observability` | kube-prometheus-stack, grafana-config |

Projects are defined in `argocd/projects/` and applied by Ansible (play 4) before the root Application.

## TLS certificates

Three issuers are available in `argocd/apps/cert-manager/config/`:

| Issuer | Use case |
|--------|---------|
| `letsencrypt-staging` | Testing — untrusted CA, no rate limits |
| `letsencrypt-prod` | Production — trusted, rate limited |
| `selfsigned-ca` | Offline / dev — import `selfsigned-ca-tls` secret as trusted CA |

**Always test with `letsencrypt-staging` first.** Staging has relaxed rate limits — if issuance succeeds (browser will show a warning, that's expected), DNS and port 80 routing are confirmed working. Then switch `issuerRef.name` to `letsencrypt-prod`. Production is rate-limited to 50 certificates per domain per week; repeated failed attempts can lock you out for hours ([Let's Encrypt rate limits](https://letsencrypt.org/docs/rate-limits/)).

cert-manager uses **HTTP-01 challenge** — one certificate per hostname (wildcard requires DNS-01).
Port 80 must be reachable from the internet during issuance. Renewals are automatic.

Export the self-signed CA for local trust:
```bash
kubectl -n cert-manager get secret selfsigned-ca-tls \
  -o jsonpath="{.data.ca\.crt}" | base64 -d > selfsigned-ca.crt
```

## Adding a new subdomain

1. Add a DNS A record → Ingress LB floating IP
2. Add an HTTPS listener in `argocd/apps/traefik/config/traefik-gateway-Gateway.yaml`
3. Add a `Certificate` in `argocd/apps/cert-manager/config/<name>-tls-Certificate.yaml`
4. Add an `HTTPRoute` in your application's `argocd/apps/<app>/config/<app>-HTTPRoute.yaml`
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

## Keycloak

UI: `https://keycloak.ass-nss.jkuzel02.online`

Deployed via the **official Keycloak Operator** (`k8s.keycloak.org/v2alpha1`) at v26.5.5. Uses **CloudNativePG** for PostgreSQL — the operator auto-generates database credentials into secret `keycloak-postgres-app`.

**Prerequisite** — populate and apply the admin bootstrap secret before running Ansible play 4:
```bash
# Edit ansible/files/k8s/manifests/keycloak-credentials-Secret.yaml (gitignored), then:
kubectl apply -f ansible/files/k8s/manifests/keycloak-credentials-Secret.yaml \
  --kubeconfig ansible/artifacts/kubeconfig
```

Retrieve the admin password later:
```bash
kubectl get secret keycloak-credentials -n keycloak \
  -o jsonpath="{.data.admin-password}" | base64 -d
```

## HashiCorp Vault

UI: `https://vault.ass-nss.jkuzel02.online`

Vault runs in **standalone mode** (single pod, file storage on Longhorn). TLS is terminated at Traefik; Vault itself listens on plain HTTP internally.

**First-time initialization** (required once after the pod first starts):
```bash
kubectl exec -n vault vault-0 -- vault operator init
```

Save the 5 unseal keys and root token somewhere safe (e.g. a password manager). Then unseal:
```bash
# Run 3 times with 3 different unseal keys
kubectl exec -n vault vault-0 -- vault operator unseal
```

> Vault re-seals on every pod restart and must be manually unsealed again. For a production setup, configure auto-unseal via a cloud KMS or a transit seal.

## Grafana

UI: `https://grafana.ass-nss.jkuzel02.online`

Deployed as part of **kube-prometheus-stack** (Prometheus + Grafana + Alertmanager). Prometheus scrapes cluster metrics via ServiceMonitors; Grafana visualises them.

**Prerequisite** — populate and apply the admin password secret before running Ansible play 4:
```bash
# Edit ansible/files/k8s/manifests/grafana-credentials-Secret.yaml (gitignored), then:
kubectl apply -f ansible/files/k8s/manifests/grafana-credentials-Secret.yaml \
  --kubeconfig ansible/artifacts/kubeconfig
```

Retrieve Prometheus and Alertmanager (cluster-internal only):
```bash
kubectl get svc -n monitoring | grep -E 'prometheus|alertmanager'
```

## Longhorn storage

- **Raw capacity**: 333 GB per worker (3 × 111 GB), 666 GB total
- **Usable capacity**: ~333 GB with 2-replica default (666 GB ÷ 2)
- **Default StorageClass**: `longhorn`
- **UI**: `https://longhorn.ass-nss.jkuzel02.online`
