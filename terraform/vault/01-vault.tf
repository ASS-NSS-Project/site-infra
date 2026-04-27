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

variable "rag_jwt_secret" {
  description = "RAG system JWT signing secret"
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
  description = "LLM model name (text generation)"
  type        = string
}

variable "rag_vlm_model" {
  description = "VLM model name (vision extraction)"
  type        = string
}

# Optional external LLM provider keys — leave empty to disable the provider in the UI
variable "rag_openai_api_key" {
  description = "OpenAI API key (enables GPT-4o / GPT-4o Mini in query UI)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "rag_gemini_api_key" {
  description = "Google Gemini API key (enables Gemini 2.5 Pro / Flash in query UI)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "rag_anthropic_api_key" {
  description = "Anthropic API key (enables Claude Opus 4.7 / Sonnet 4.6 directly)"
  type        = string
  sensitive   = true
  default     = ""
}

resource "vault_kv_secret_v2" "rag" {
  mount = vault_mount.secret.path
  name  = "rag"

  data_json = jsonencode({
    jwt-secret        = var.rag_jwt_secret
    admin-password    = var.rag_admin_password
    s3-endpoint-url   = var.rag_s3_endpoint_url
    s3-access-key     = var.rag_s3_access_key
    s3-secret-key     = var.rag_s3_secret_key
    llm-base-url      = var.rag_llm_base_url
    llm-api-key       = var.rag_llm_api_key
    llm-model         = var.rag_llm_model
    vlm-model         = var.rag_vlm_model
    openai-api-key    = var.rag_openai_api_key
    gemini-api-key    = var.rag_gemini_api_key
    anthropic-api-key = var.rag_anthropic_api_key
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
