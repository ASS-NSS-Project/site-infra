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

# --- RAG application groups ---

# webrag_admin — full access to inside the main realm (ASS-NSS-Project)
resource "keycloak_group" "webrag_admin" {
  realm_id = keycloak_realm.main.id
  name     = "webrag_admin"
}

# webrag_curator — source/pipeline/incident management
resource "keycloak_group" "webrag_curator" {
  realm_id = keycloak_realm.main.id
  name     = "webrag_curator"
}

# webrag_analyst — experiments, model testing, index quality evaluation
resource "keycloak_group" "webrag_analyst" {
  realm_id = keycloak_realm.main.id
  name     = "webrag_analyst"
}

# webrag_user — standard end user; submits queries, views answers
resource "keycloak_group" "webrag_user" {
  realm_id = keycloak_realm.main.id
  name     = "webrag_user"
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

resource "keycloak_user" "webrag_admin" {
  for_each         = toset(var.webrag_admin_members)
  realm_id         = keycloak_realm.main.id
  username         = each.value
  email            = each.value
  email_verified   = true
  enabled          = true
  required_actions = []
}

resource "keycloak_group_memberships" "webrag_admin" {
  realm_id = keycloak_realm.main.id
  group_id = keycloak_group.webrag_admin.id
  members  = [for u in keycloak_user.webrag_admin : u.username]
}

resource "keycloak_user" "webrag_curator" {
  for_each         = toset(var.webrag_curator_members)
  realm_id         = keycloak_realm.main.id
  username         = each.value
  email            = each.value
  email_verified   = true
  enabled          = true
  required_actions = []
}

resource "keycloak_group_memberships" "webrag_curator" {
  realm_id = keycloak_realm.main.id
  group_id = keycloak_group.webrag_curator.id
  members  = [for u in keycloak_user.webrag_curator : u.username]
}

resource "keycloak_user" "webrag_analyst" {
  for_each         = toset(var.webrag_analyst_members)
  realm_id         = keycloak_realm.main.id
  username         = each.value
  email            = each.value
  email_verified   = true
  enabled          = true
  required_actions = []
}

resource "keycloak_group_memberships" "webrag_analyst" {
  realm_id = keycloak_realm.main.id
  group_id = keycloak_group.webrag_analyst.id
  members  = [for u in keycloak_user.webrag_analyst : u.username]
}

resource "keycloak_user" "webrag_user" {
  for_each         = toset(var.webrag_user_members)
  realm_id         = keycloak_realm.main.id
  username         = each.value
  email            = each.value
  email_verified   = true
  enabled          = true
  required_actions = []
}

resource "keycloak_group_memberships" "webrag_user" {
  realm_id = keycloak_realm.main.id
  group_id = keycloak_group.webrag_user.id
  members  = [for u in keycloak_user.webrag_user : u.username]
}
