# --- Vault OIDC auth backend via Keycloak ---
# Configures Vault to accept logins via Keycloak OIDC.
# The "admin" Keycloak group maps to the vault-admin policy (full access).
# Any other authenticated user gets the default policy (no access beyond their own token).

locals {
  keycloak_issuer = "https://keycloak.nss.jkzl.eu/realms/ass-nss"
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

  # The Vault provider re-reads tune as a different internal type on each plan,
  # producing a perpetual diff even when nothing changed. The settings are correct — ignore.
  lifecycle {
    ignore_changes = [tune]
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
    "https://vault.nss.jkzl.eu/ui/vault/auth/oidc/oidc/callback",
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

# --- Group mapping: Keycloak "admin" → vault-admin policy ---
# vault_identity_group creates a Vault external group.
# vault_identity_group_alias links the Keycloak group name to the OIDC backend accessor,
# so when a user logs in with the "admin" group claim, Vault assigns the admin policy.

resource "vault_identity_group" "admin" {
  name     = "admin"
  type     = "external"
  policies = [vault_policy.admin.name]
}

resource "vault_identity_group_alias" "admin" {
  name           = "admin"
  mount_accessor = vault_jwt_auth_backend.oidc.accessor
  canonical_id   = vault_identity_group.admin.id
}
