# --- Vault Kubernetes auth — used by External Secrets Operator ---
# ESO pods authenticate to Vault using their K8s service account JWT.
# No static tokens or credentials needed — fully automatic.

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "default" {
  backend         = vault_auth_backend.kubernetes.path
  kubernetes_host = "https://kubernetes.default.svc"
  # Vault is running inside K8s — it uses its own service account for token review.
  # Requires the Vault SA to have system:auth-delegator ClusterRole (see argocd/apps/vault/config/).
}

resource "vault_policy" "eso" {
  name = "eso-read"

  policy = <<-EOT
    path "secret/data/*" {
      capabilities = ["read"]
    }
    path "secret/metadata/*" {
      capabilities = ["read", "list"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "eso" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "eso"
  bound_service_account_names      = ["external-secrets"]
  bound_service_account_namespaces = ["external-secrets"]
  token_policies                   = [vault_policy.eso.name]
  token_ttl                        = 3600
}
