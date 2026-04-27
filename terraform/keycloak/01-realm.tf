resource "keycloak_realm" "main" {
  realm        = "ass-nss-project"
  enabled      = true
  display_name = "ASS-NSS-Project"

  registration_allowed     = false
  reset_password_allowed   = true
  remember_me              = true
  login_with_email_allowed = true

  # Require HTTPS for all requests except localhost
  ssl_required = "external"
}

# admin — full access to all services and infrastructure
resource "keycloak_group" "admin" {
  realm_id = keycloak_realm.main.id
  name     = "admin"
}

# curator — data source management, collection rules, legal titles
resource "keycloak_group" "curator" {
  realm_id = keycloak_realm.main.id
  name     = "curator"
}

# analytic — experiments, model testing, index quality evaluation; Grafana viewer
resource "keycloak_group" "analytic" {
  realm_id = keycloak_realm.main.id
  name     = "analytic"
}

# user — standard end user; submits queries, views answers with citations
resource "keycloak_group" "user" {
  realm_id = keycloak_realm.main.id
  name     = "user"
}

# unauthorized — explicitly blocked; no access to any service
resource "keycloak_group" "unauthorized" {
  realm_id = keycloak_realm.main.id
  name     = "unauthorized"
}

# --- Group memberships ---
# Users are pre-created by Gmail address. On first Google login, Keycloak's "Detect Existing
# Account" flow matches by email (trust_email = true) and links the Google identity to the
# pre-created account.
# If a user has already logged in before being added to tfvars, import them first:
#   terraform import 'keycloak_user.admin["their@gmail.com"]' {realm-id}/users/{user-id}

/*
required_actions = [] 👈 Without this, Keycloak applies the realm's default UPDATE_PROFILE 
                         action to every newly-created user, which triggers the name/surname
                         prompt on first login. 
*/

resource "keycloak_user" "admin" {
  for_each         = toset(var.admin_members)
  realm_id         = keycloak_realm.main.id
  username         = each.value
  email            = each.value
  email_verified   = true
  enabled          = true
  required_actions = []
}

resource "keycloak_group_memberships" "admin" {
  realm_id = keycloak_realm.main.id
  group_id = keycloak_group.admin.id
  members  = [for u in keycloak_user.admin : u.username]
}

resource "keycloak_user" "curator" {
  for_each         = toset(var.curator_members)
  realm_id         = keycloak_realm.main.id
  username         = each.value
  email            = each.value
  email_verified   = true
  enabled          = true
  required_actions = []
}

resource "keycloak_group_memberships" "curator" {
  realm_id = keycloak_realm.main.id
  group_id = keycloak_group.curator.id
  members  = [for u in keycloak_user.curator : u.username]
}

resource "keycloak_user" "analytic" {
  for_each         = toset(var.analytic_members)
  realm_id         = keycloak_realm.main.id
  username         = each.value
  email            = each.value
  email_verified   = true
  enabled          = true
  required_actions = []
}

resource "keycloak_group_memberships" "analytic" {
  realm_id = keycloak_realm.main.id
  group_id = keycloak_group.analytic.id
  members  = [for u in keycloak_user.analytic : u.username]
}

resource "keycloak_user" "user" {
  for_each         = toset(var.user_members)
  realm_id         = keycloak_realm.main.id
  username         = each.value
  email            = each.value
  email_verified   = true
  enabled          = true
  required_actions = []
}

resource "keycloak_group_memberships" "user" {
  realm_id = keycloak_realm.main.id
  group_id = keycloak_group.user.id
  members  = [for u in keycloak_user.user : u.username]
}
