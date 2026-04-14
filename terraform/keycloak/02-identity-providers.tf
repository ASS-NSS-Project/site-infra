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

# Custom first-broker-login flow that auto-links a Google account to a pre-created Keycloak
# user matched by email, without asking for a password. Safe because trust_email = true means
# we already trust that Google verified the email address.
resource "keycloak_authentication_flow" "auto_link" {
  realm_id = keycloak_realm.main.id
  alias    = "first broker login - auto link"
}

# Step 1 — if no existing user matches, create a new one
resource "keycloak_authentication_execution" "auto_link_create_if_unique" {
  realm_id          = keycloak_realm.main.id
  parent_flow_alias = keycloak_authentication_flow.auto_link.alias
  authenticator     = "idp-create-user-if-unique"
  requirement       = "ALTERNATIVE"
}

# Step 2 — if a user with the same email already exists, link automatically
resource "keycloak_authentication_execution" "auto_link_set_existing" {
  realm_id          = keycloak_realm.main.id
  parent_flow_alias = keycloak_authentication_flow.auto_link.alias
  authenticator     = "idp-auto-link"
  requirement       = "ALTERNATIVE"
  depends_on        = [keycloak_authentication_execution.auto_link_create_if_unique]
}

# Google — built-in Keycloak provider, OIDC
# Callback URL to register in GCP Console:
# https://keycloak.ass-nss.jkuzel02.online/realms/ass-nss/broker/google/endpoint
resource "keycloak_oidc_google_identity_provider" "google" {
  realm         = keycloak_realm.main.id
  client_id     = var.google_client_id
  client_secret = var.google_client_secret
  sync_mode     = "FORCE"
  trust_email   = true

  first_broker_login_flow_alias = keycloak_authentication_flow.auto_link.alias
}
