resource "keycloak_realm" "main" {
  realm        = "ass-nss"
  enabled      = true
  display_name = "ASS-NSS"

  registration_allowed     = false
  reset_password_allowed   = true
  remember_me              = true
  login_with_email_allowed = true

  # Require HTTPS for all requests except localhost
  ssl_required = "external"
}

# Admin group — members get admin access in ArgoCD, Grafana, Harbor
resource "keycloak_group" "admins" {
  realm_id = keycloak_realm.main.id
  name     = "admins"
}
