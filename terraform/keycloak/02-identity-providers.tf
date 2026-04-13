# --- External Identity Providers ---
# Users log in via Google or GitHub. Keycloak brokers the identity
# and issues its own tokens to applications.

variable "google_client_id" {
  description = "Google OAuth2 Client ID (from GCP Console → APIs & Services → Credentials)"
  type        = string
}

variable "google_client_secret" {
  description = "Google OAuth2 Client Secret"
  type        = string
  sensitive   = true
}

variable "github_client_id" {
  description = "GitHub OAuth App Client ID (from GitHub → Settings → Developer settings → OAuth Apps)"
  type        = string
}

variable "github_client_secret" {
  description = "GitHub OAuth App Client Secret"
  type        = string
  sensitive   = true
}

# Google — built-in Keycloak provider, OIDC
# Callback URL to register in GCP Console:
# https://keycloak.ass-nss.jkuzel02.online/realms/ass-nss/broker/google/endpoint
resource "keycloak_oidc_google_identity_provider" "google" {
  realm         = keycloak_realm.main.id
  client_id     = var.google_client_id
  client_secret = var.google_client_secret
  sync_mode     = "IMPORT"
  trust_email   = true
}

# GitHub — generic OIDC using GitHub's OAuth2 endpoints
# Callback URL to register on GitHub:
# https://keycloak.ass-nss.jkuzel02.online/realms/ass-nss/broker/github/endpoint
resource "keycloak_oidc_identity_provider" "github" {
  realm             = keycloak_realm.main.id
  alias             = "github"
  display_name      = "GitHub"
  authorization_url = "https://github.com/login/oauth/authorize"
  token_url         = "https://github.com/login/oauth/access_token"
  user_info_url     = "https://api.github.com/user"
  client_id         = var.github_client_id
  client_secret     = var.github_client_secret
  default_scopes    = "user:email"
  sync_mode         = "IMPORT"
  trust_email       = true
}
