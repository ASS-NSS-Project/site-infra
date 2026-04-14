# --- Vault OIDC auth backend via Keycloak ---
# Configures Vault to accept logins via Keycloak OIDC.
# The "admins" Keycloak group maps to the vault-admin policy (full access).
# Any other authenticated user gets the default policy (no access beyond their own token).

locals {
  keycloak_issuer = "https://keycloak.ass-nss.jkuzel02.online/realms/ass-nss"
}

resource "vault_jwt_auth_backend" "oidc" {
  description        = "Keycloak OIDC"
  path               = "oidc"
  type               = "oidc"
  oidc_discovery_url = local.keycloak_issuer
  oidc_client_id     = keycloak_openid_client.vault.client_id
  oidc_client_secret = keycloak_openid_client.vault.client_secret
  default_role       = "default"

  tune {
    # Show OIDC as an option on the Vault login page for unauthenticated users
    listing_visibility = "unauth"
    default_lease_ttl  = "1h"
    max_lease_ttl      = "24h"
  }
}

resource "vault_jwt_auth_backend_role" "default" {
  backend         = vault_jwt_auth_backend.oidc.path
  role_name       = "default"
  role_type       = "oidc"
  bound_audiences = [keycloak_openid_client.vault.client_id]
  user_claim      = "sub"
  groups_claim    = "groups"
  oidc_scopes     = ["openid", "profile", "email"]

  allowed_redirect_uris = [
    "https://vault.ass-nss.jkuzel02.online/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback",
  ]

  token_policies = ["default"]
  token_ttl      = 3600
  token_max_ttl  = 86400
}

# --- Admin policy ---

resource "vault_policy" "admin" {
  name = "vault-admin"

  policy = <<-EOT
    path "*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
  EOT
}

# --- Group mapping: Keycloak "admins" → vault-admin policy ---
# vault_identity_group creates a Vault external group.
# vault_identity_group_alias links the Keycloak group name to the OIDC backend accessor,
# so when a user logs in with the "admins" group claim, Vault assigns the admin policy.

resource "vault_identity_group" "admins" {
  name     = "admins"
  type     = "external"
  policies = [vault_policy.admin.name]
}

resource "vault_identity_group_alias" "admins" {
  name           = "admins"
  mount_accessor = vault_jwt_auth_backend.oidc.accessor
  canonical_id   = vault_identity_group.admins.id
}
