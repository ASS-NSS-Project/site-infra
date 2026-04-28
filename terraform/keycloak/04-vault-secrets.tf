# --- Push OIDC client secrets to Vault ---
# ESO syncs these into Kubernetes Secrets so apps can consume them
# without any credentials ever touching the repo or Ansible.

resource "vault_kv_secret_v2" "oidc_argocd" {
  mount = "secret"
  name  = "oidc/argocd"

  data_json = jsonencode({
    client_id     = keycloak_openid_client.argocd.client_id
    client_secret = keycloak_openid_client.argocd.client_secret
    issuer        = "https://keycloak.nss.jkzl.eu/realms/ass-nss-project"
  })
}

resource "vault_kv_secret_v2" "oidc_grafana" {
  mount = "secret"
  name  = "oidc/grafana"

  data_json = jsonencode({
    client_id     = keycloak_openid_client.grafana.client_id
    client_secret = keycloak_openid_client.grafana.client_secret
    issuer        = "https://keycloak.nss.jkzl.eu/realms/ass-nss-project"
  })
}

variable "oauth2_proxy_cookie_secret" {
  description = "oauth2-proxy cookie encryption secret — 32 random bytes, base64-encoded. Generate: openssl rand -base64 32"
  type        = string
  sensitive   = true
}

resource "vault_kv_secret_v2" "oidc_traefik" {
  mount = "secret"
  name  = "oidc/traefik"

  data_json = jsonencode({
    client_id     = keycloak_openid_client.traefik.client_id
    client_secret = keycloak_openid_client.traefik.client_secret
    cookie_secret = var.oauth2_proxy_cookie_secret
    issuer        = "https://keycloak.nss.jkzl.eu/realms/ass-nss-project"
  })
}

resource "vault_kv_secret_v2" "oidc_rag_system" {
  mount = "secret"
  name  = "oidc/rag-system"

  data_json = jsonencode({
    client_id     = keycloak_openid_client.rag_system.client_id
    client_secret = keycloak_openid_client.rag_system.client_secret
    issuer        = "https://keycloak.nss.jkzl.eu/realms/ass-nss-project"
  })
}

resource "vault_kv_secret_v2" "oidc_vault" {
  mount = "secret"
  name  = "oidc/vault"

  data_json = jsonencode({
    client_id     = keycloak_openid_client.vault.client_id
    client_secret = keycloak_openid_client.vault.client_secret
    issuer        = "https://keycloak.nss.jkzl.eu/realms/ass-nss-project"
  })
}
