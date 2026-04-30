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

# rag_admin — full access to inside the main realm (ASS-NSS-Project)
resource "keycloak_group" "rag_admin" {
  realm_id = keycloak_realm.main.id
  name     = "rag_admin"
}

# rag_curator — source/pipeline/incident management
resource "keycloak_group" "rag_curator" {
  realm_id = keycloak_realm.main.id
  name     = "rag_curator"
}

# rag_analyst — experiments, model testing, index quality evaluation
resource "keycloak_group" "rag_analyst" {
  realm_id = keycloak_realm.main.id
  name     = "rag_analyst"
}

# rag_user — standard end user; submits queries, views answers
resource "keycloak_group" "rag_user" {
  realm_id = keycloak_realm.main.id
  name     = "rag_user"
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

resource "keycloak_user" "rag_admin" {
  for_each         = toset(var.rag_admin_members)
  realm_id         = keycloak_realm.main.id
  username         = each.value
  email            = each.value
  email_verified   = true
  enabled          = true
  required_actions = []
}

resource "keycloak_group_memberships" "rag_admin" {
  realm_id = keycloak_realm.main.id
  group_id = keycloak_group.rag_admin.id
  members  = [for u in keycloak_user.rag_admin : u.username]
}

resource "keycloak_user" "rag_curator" {
  for_each         = toset(var.rag_curator_members)
  realm_id         = keycloak_realm.main.id
  username         = each.value
  email            = each.value
  email_verified   = true
  enabled          = true
  required_actions = []
}

resource "keycloak_group_memberships" "rag_curator" {
  realm_id = keycloak_realm.main.id
  group_id = keycloak_group.rag_curator.id
  members  = [for u in keycloak_user.rag_curator : u.username]
}

resource "keycloak_user" "rag_analyst" {
  for_each         = toset(var.rag_analyst_members)
  realm_id         = keycloak_realm.main.id
  username         = each.value
  email            = each.value
  email_verified   = true
  enabled          = true
  required_actions = []
}

resource "keycloak_group_memberships" "rag_analyst" {
  realm_id = keycloak_realm.main.id
  group_id = keycloak_group.rag_analyst.id
  members  = [for u in keycloak_user.rag_analyst : u.username]
}

resource "keycloak_user" "rag_user" {
  for_each         = toset(var.rag_user_members)
  realm_id         = keycloak_realm.main.id
  username         = each.value
  email            = each.value
  email_verified   = true
  enabled          = true
  required_actions = []
}

resource "keycloak_group_memberships" "rag_user" {
  realm_id = keycloak_realm.main.id
  group_id = keycloak_group.rag_user.id
  members  = [for u in keycloak_user.rag_user : u.username]
}
