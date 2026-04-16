# --- OIDC Clients ---
# One confidential client per application.
# Each client gets a groups mapper so Keycloak group membership
# flows through to the app for RBAC (e.g. "admins" group → admin role).

locals {
  base_url = "https://nss.jkzl.eu"
}

# ArgoCD
resource "keycloak_openid_client" "argocd" {
  realm_id              = keycloak_realm.main.id
  client_id             = "argocd"
  name                  = "ArgoCD"
  enabled               = true
  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true
  valid_redirect_uris   = ["https://argocd.nss.jkzl.eu/*"]
  web_origins           = ["https://argocd.nss.jkzl.eu"]
}

resource "keycloak_openid_group_membership_protocol_mapper" "argocd_groups" {
  realm_id   = keycloak_realm.main.id
  client_id  = keycloak_openid_client.argocd.id
  name       = "groups"
  claim_name = "groups"
  full_path  = false
}

# Grafana
resource "keycloak_openid_client" "grafana" {
  realm_id              = keycloak_realm.main.id
  client_id             = "grafana"
  name                  = "Grafana"
  enabled               = true
  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true
  valid_redirect_uris   = ["https://grafana.nss.jkzl.eu/*"]
  web_origins           = ["https://grafana.nss.jkzl.eu"]
}

resource "keycloak_openid_group_membership_protocol_mapper" "grafana_groups" {
  realm_id   = keycloak_realm.main.id
  client_id  = keycloak_openid_client.grafana.id
  name       = "groups"
  claim_name = "groups"
  full_path  = false
}

# oauth2-proxy (covers apps without native OIDC — e.g. Longhorn, Prometheus, ...)
resource "keycloak_openid_client" "oauth2_proxy" {
  realm_id              = keycloak_realm.main.id
  client_id             = "oauth2-proxy"
  name                  = "oauth2-proxy"
  enabled               = true
  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true

  valid_redirect_uris = [
    "https://longhorn.nss.jkzl.eu/oauth2/callback",
    "https://prometheus.nss.jkzl.eu/oauth2/callback",
    "https://alertmanager.nss.jkzl.eu/oauth2/callback"
  ]

  web_origins = ["*"]
}

resource "keycloak_openid_group_membership_protocol_mapper" "oauth2_proxy_groups" {
  realm_id   = keycloak_realm.main.id
  client_id  = keycloak_openid_client.oauth2_proxy.id
  name       = "groups"
  claim_name = "groups"
  full_path  = false
}

# Vault
resource "keycloak_openid_client" "vault" {
  realm_id              = keycloak_realm.main.id
  client_id             = "vault"
  name                  = "Vault"
  enabled               = true
  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true

  valid_redirect_uris = [
    "https://vault.nss.jkzl.eu/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback",
  ]

  web_origins = ["https://vault.nss.jkzl.eu"]
}

resource "keycloak_openid_group_membership_protocol_mapper" "vault_groups" {
  realm_id   = keycloak_realm.main.id
  client_id  = keycloak_openid_client.vault.id
  name       = "groups"
  claim_name = "groups"
  full_path  = false
}
