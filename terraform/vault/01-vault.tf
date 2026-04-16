# --- Vault provisioning ---
# Phase 2 — run after Vault is initialized and unsealed.
# Enables the KV v2 secrets engine and stores service credentials.

variable "vault_root_token" {
  description = "Vault root token (from vault operator init)"
  type        = string
  sensitive   = true
}

variable "grafana_username" {
  description = "Grafana username"
  type        = string
  sensitive   = true
}

variable "grafana_password" {
  description = "Grafana password"
  type        = string
  sensitive   = true
}

variable "keycloak_username" {
  description = "Keycloak username"
  type        = string
  sensitive   = true
}

variable "keycloak_password" {
  description = "Keycloak password"
  type        = string
  sensitive   = true
}

variable "longhorn_htpasswd" {
  description = "Longhorn UI basic auth in htpasswd format (bcrypt). Generate with: htpasswd -nb -B <user> <password>"
  type        = string
  sensitive   = true
}

resource "vault_mount" "secret" {
  path        = "secret"
  type        = "kv-v2"
  description = "KV v2 secrets engine for service credentials"
}

resource "vault_kv_secret_v2" "grafana" {
  mount = vault_mount.secret.path
  name  = "grafana"

  data_json = jsonencode({
    username = var.grafana_username
    password = var.grafana_password
  })
}

resource "vault_kv_secret_v2" "keycloak" {
  mount = vault_mount.secret.path
  name  = "keycloak"

  data_json = jsonencode({
    username = var.keycloak_username
    password = var.keycloak_password
  })
}


resource "vault_kv_secret_v2" "longhorn" {
  mount = vault_mount.secret.path
  name  = "longhorn"

  data_json = jsonencode({
    htpasswd = var.longhorn_htpasswd
  })
}

# oauth2-proxy cookie secret — randomly generated, stored in Vault.
# Must be a printable 32-byte string — binary values break env var injection.
resource "random_password" "oauth2_proxy_cookie" {
  length  = 32
  special = false
}

resource "vault_kv_secret_v2" "oauth2_proxy_cookie" {
  mount = vault_mount.secret.path
  name  = "oidc/oauth2-proxy-cookie"

  data_json = jsonencode({
    cookie_secret = random_password.oauth2_proxy_cookie.result
  })
}
