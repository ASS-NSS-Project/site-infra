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

# Traefik keycloakopenid plugin (covers apps without native OIDC — Longhorn, Prometheus, Alertmanager)
resource "keycloak_openid_client" "traefik" {
  realm_id              = keycloak_realm.main.id
  client_id             = "traefik"
  name                  = "Traefik"
  enabled               = true
  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true

  valid_redirect_uris = [
    "https://longhorn.nss.jkzl.eu/*",
    "https://prometheus.nss.jkzl.eu/*",
    "https://alertmanager.nss.jkzl.eu/*"
  ]

  web_origins = ["*"]
}

resource "keycloak_openid_group_membership_protocol_mapper" "traefik_groups" {
  realm_id   = keycloak_realm.main.id
  client_id  = keycloak_openid_client.traefik.id
  name       = "groups"
  claim_name = "groups"
  full_path  = false
}

# RAG System
resource "keycloak_openid_client" "rag_system" {
  realm_id              = keycloak_realm.main.id
  client_id             = "rag-system"
  name                  = "RAG System"
  enabled               = true
  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true
  valid_redirect_uris = [
    "https://rag.nss.jkzl.eu/auth/keycloak/callback",
    "http://localhost:8080/auth/keycloak/callback",
  ]
  web_origins = [
    "https://rag.nss.jkzl.eu",
    "http://localhost:8080",
  ]
}

resource "keycloak_openid_group_membership_protocol_mapper" "rag_system_groups" {
  realm_id   = keycloak_realm.main.id
  client_id  = keycloak_openid_client.rag_system.id
  name       = "groups"
  claim_name = "groups"
  full_path  = false
}

# RAG RBAC Service Account — client-credentials grant used by the API to sync
# role changes made in the WebRAG UI back to Keycloak group membership.
resource "keycloak_openid_client" "rag_rbac_sa" {
  realm_id                 = keycloak_realm.main.id
  client_id                = "rag-rbac-sa"
  name                     = "RAG RBAC Service Account"
  enabled                  = true
  access_type              = "CONFIDENTIAL"
  standard_flow_enabled    = false
  service_accounts_enabled = true
}

data "keycloak_openid_client" "realm_management" {
  realm_id  = keycloak_realm.main.id
  client_id = "realm-management"
}

data "keycloak_role" "manage_users" {
  realm_id  = keycloak_realm.main.id
  client_id = data.keycloak_openid_client.realm_management.id
  name      = "manage-users"
}

# rag-rbac-sa service account: manage-users so the API can sync roles back to Keycloak
resource "keycloak_openid_client_service_account_role" "rag_rbac_sa_manage_users" {
  realm_id                = keycloak_realm.main.id
  service_account_user_id = keycloak_openid_client.rag_rbac_sa.service_account_user_id
  client_id               = data.keycloak_openid_client.realm_management.id
  role                    = data.keycloak_role.manage_users.name
}

# realm-management roles needed for rag_admin to manage RAG group memberships in the admin console
data "keycloak_role" "view_users" {
  realm_id  = keycloak_realm.main.id
  client_id = data.keycloak_openid_client.realm_management.id
  name      = "view-users"
}

data "keycloak_role" "query_users" {
  realm_id  = keycloak_realm.main.id
  client_id = data.keycloak_openid_client.realm_management.id
  name      = "query-users"
}

data "keycloak_role" "query_groups" {
  realm_id  = keycloak_realm.main.id
  client_id = data.keycloak_openid_client.realm_management.id
  name      = "query-groups"
}

# Grant rag_admin group the ability to view users and manage RAG group memberships
resource "keycloak_group_roles" "rag_admin_realm_management" {
  realm_id   = keycloak_realm.main.id
  group_id   = keycloak_group.rag_admin.id
  exhaustive = false
  role_ids = [
    data.keycloak_role.view_users.id,
    data.keycloak_role.query_users.id,
    data.keycloak_role.query_groups.id,
  ]
}

# RabbitMQ
# PUBLIC client — no client secret required.
# Token validation uses Keycloak's JWKS endpoint (public key, no secret).
# All authenticated users receive rabbitmq.tag:administrator via the hardcoded
# scope mapper, granting full management UI access.
resource "keycloak_openid_client" "rabbitmq" {
  realm_id              = keycloak_realm.main.id
  client_id             = "rabbitmq"
  name                  = "RabbitMQ"
  enabled               = true
  access_type           = "PUBLIC"
  standard_flow_enabled = true
  valid_redirect_uris   = ["https://rabbitmq.nss.jkzl.eu/*"]
  web_origins           = ["https://rabbitmq.nss.jkzl.eu"]
}

# Audience mapper — adds "rabbitmq" to the aud claim so RabbitMQ accepts the token
resource "keycloak_openid_audience_protocol_mapper" "rabbitmq_audience" {
  realm_id                 = keycloak_realm.main.id
  client_id                = keycloak_openid_client.rabbitmq.id
  name                     = "rabbitmq-audience"
  included_client_audience = keycloak_openid_client.rabbitmq.client_id
}

# Client role — only users who hold this role get rabbitmq.tag:administrator in their JWT
resource "keycloak_role" "rabbitmq_administrator" {
  realm_id  = keycloak_realm.main.id
  client_id = keycloak_openid_client.rabbitmq.id
  name      = "administrator"
}

# Assign the administrator role to the admin group only
resource "keycloak_group_roles" "admin_rabbitmq" {
  realm_id   = keycloak_realm.main.id
  group_id   = keycloak_group.admin.id
  role_ids   = [keycloak_role.rabbitmq_administrator.id]
  exhaustive = false
}

# Map client roles → rabbitmq_scopes claim with "rabbitmq.tag:" prefix.
# For the admin group this produces: rabbitmq_scopes = ["rabbitmq.tag:administrator"]
# For everyone else the claim is absent → no management tag → access denied.
resource "keycloak_generic_protocol_mapper" "rabbitmq_roles_scope_mapper" {
  realm_id        = keycloak_realm.main.id
  client_id       = keycloak_openid_client.rabbitmq.id
  name            = "rabbitmq-roles-as-scopes"
  protocol        = "openid-connect"
  protocol_mapper = "oidc-usermodel-client-role-mapper"
  config = {
    "access.token.claim"                     = "true"
    "id.token.claim"                         = "true"
    "claim.name"                             = "rabbitmq_scopes"
    "jsonType.label"                         = "String"
    "multivalued"                            = "true"
    "userinfo.token.claim"                   = "false"
    "usermodel.clientRoleMapping.clientId"   = "rabbitmq"
    "usermodel.clientRoleMapping.rolePrefix" = "rabbitmq.tag:"
  }
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
