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

variable "longhorn_s3_access_key" {
  description = "Metacentrum S3 access key for Longhorn backups"
  type        = string
  sensitive   = true
}

variable "longhorn_s3_secret_key" {
  description = "Metacentrum S3 secret key for Longhorn backups"
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

resource "vault_kv_secret_v2" "longhorn_s3" {
  mount = vault_mount.secret.path
  name  = "longhorn/s3-backup"

  data_json = jsonencode({
    access_key = var.longhorn_s3_access_key
    secret_key = var.longhorn_s3_secret_key
  })
}

variable "rag_jwt_secret" {
  description = "RAG system JWT signing secret"
  type        = string
  sensitive   = true
}

variable "rag_admin_email" {
  description = "RAG system first admin email"
  type        = string
  sensitive   = true
}

variable "rag_admin_password" {
  description = "RAG system first admin password"
  type        = string
  sensitive   = true
}

variable "rag_s3_endpoint_url" {
  description = "S3-compatible endpoint URL for RAG evidence/document storage"
  type        = string
  sensitive   = true
}

variable "rag_s3_access_key" {
  description = "S3 access key for RAG storage"
  type        = string
  sensitive   = true
}

variable "rag_s3_secret_key" {
  description = "S3 secret key for RAG storage"
  type        = string
  sensitive   = true
}

variable "rag_llm_base_url" {
  description = "LLM API base URL (Ollama or upstream)"
  type        = string
  sensitive   = true
}

variable "rag_llm_api_key" {
  description = "LLM API key (empty string for local Ollama)"
  type        = string
  sensitive   = true
}

variable "rag_llm_model" {
  description = "LLM model name"
  type        = string
}

resource "vault_kv_secret_v2" "rag" {
  mount = vault_mount.secret.path
  name  = "rag"

  data_json = jsonencode({
    jwt-secret      = var.rag_jwt_secret
    admin-email     = var.rag_admin_email
    admin-password  = var.rag_admin_password
    s3-endpoint-url = var.rag_s3_endpoint_url
    s3-access-key   = var.rag_s3_access_key
    s3-secret-key   = var.rag_s3_secret_key
    llm-base-url    = var.rag_llm_base_url
    llm-api-key     = var.rag_llm_api_key
    llm-model       = var.rag_llm_model
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
