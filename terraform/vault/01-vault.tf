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

resource "vault_kv_secret_v2" "longhorn_s3" {
  mount = vault_mount.secret.path
  name  = "longhorn/s3-backup"

  data_json = jsonencode({
    access_key = var.longhorn_s3_access_key
    secret_key = var.longhorn_s3_secret_key
  })
}

variable "webrag_jwt_secret" {
  description = "RAG system JWT signing secret"
  type        = string
  sensitive   = true
}


variable "webrag_admin_password" {
  description = "RAG system first admin password"
  type        = string
  sensitive   = true
}

variable "webrag_s3_endpoint_url" {
  description = "S3-compatible endpoint URL for RAG evidence/document storage"
  type        = string
  sensitive   = true
}

variable "webrag_s3_access_key" {
  description = "S3 access key for RAG storage"
  type        = string
  sensitive   = true
}

variable "webrag_s3_secret_key" {
  description = "S3 secret key for RAG storage"
  type        = string
  sensitive   = true
}

variable "webrag_query_base_url" {
  description = "LLM API base URL for query (any OpenAI-compatible endpoint)"
  type        = string
  sensitive   = true
}

variable "webrag_query_api_key" {
  description = "LLM API key for query"
  type        = string
  sensitive   = true
}

variable "webrag_query_model" {
  description = "LLM model name for text generation"
  type        = string
}

variable "webrag_vlm_base_url" {
  description = "VLM API base URL for vision extraction (any OpenAI-compatible endpoint)"
  type        = string
  sensitive   = true
}

variable "webrag_vlm_api_key" {
  description = "VLM API key for vision extraction"
  type        = string
  sensitive   = true
}

variable "webrag_vlm_model" {
  description = "VLM model name for vision extraction"
  type        = string
}

resource "vault_kv_secret_v2" "rag" {
  mount = vault_mount.secret.path
  name  = "rag"

  data_json = jsonencode({
    jwt-secret      = var.webrag_jwt_secret
    admin-password  = var.webrag_admin_password
    s3-endpoint-url = var.webrag_s3_endpoint_url
    s3-access-key   = var.webrag_s3_access_key
    s3-secret-key   = var.webrag_s3_secret_key
    query-base-url  = var.webrag_query_base_url
    query-api-key   = var.webrag_query_api_key
    query-model     = var.webrag_query_model
    vlm-base-url    = var.webrag_vlm_base_url
    vlm-api-key     = var.webrag_vlm_api_key
    vlm-model       = var.webrag_vlm_model
  })
}

# ── Alertmanager Telegram ──────────────────────────────────────────────────────

variable "telegram_bot_token" {
  description = "Telegram bot token for CAPTCHA alerting (from @BotFather)"
  type        = string
  sensitive   = true
}

resource "vault_kv_secret_v2" "alertmanager_telegram" {
  mount     = vault_mount.secret.path
  name      = "alertmanager/telegram"
  data_json = jsonencode({ bot_token = var.telegram_bot_token })
}
