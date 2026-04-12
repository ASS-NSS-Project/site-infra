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

variable "harbor_username" {
  description = "Harbor username"
  type        = string
  sensitive   = true
}

variable "harbor_password" {
  description = "Harbor password"
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

resource "vault_kv_secret_v2" "harbor" {
  mount = vault_mount.secret.path
  name  = "harbor"

  data_json = jsonencode({
    username = var.harbor_username
    password = var.harbor_password
  })
}
