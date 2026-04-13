# --- External Identity Providers ---
# Users log in via Google. Keycloak brokers the identity
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
