# --- Push OIDC client secrets to Vault ---
# ESO syncs these into Kubernetes Secrets so apps can consume them
# without any credentials ever touching the repo or Ansible.

resource "vault_kv_secret_v2" "oidc_argocd" {
  mount = "secret"
  name  = "oidc/argocd"

  data_json = jsonencode({
    client_id     = keycloak_openid_client.argocd.client_id
    client_secret = keycloak_openid_client.argocd.client_secret
    issuer        = "https://keycloak.nss.jkzl.eu/realms/ass-nss-project"
  })
}

resource "vault_kv_secret_v2" "oidc_grafana" {
  mount = "secret"
  name  = "oidc/grafana"

  data_json = jsonencode({
    client_id     = keycloak_openid_client.grafana.client_id
    client_secret = keycloak_openid_client.grafana.client_secret
    issuer        = "https://keycloak.nss.jkzl.eu/realms/ass-nss-project"
  })
}

resource "vault_kv_secret_v2" "oidc_oauth2_proxy" {
  mount = "secret"
  name  = "oidc/oauth2-proxy"

  data_json = jsonencode({
    client_id     = keycloak_openid_client.oauth2_proxy.client_id
    client_secret = keycloak_openid_client.oauth2_proxy.client_secret
    issuer        = "https://keycloak.nss.jkzl.eu/realms/ass-nss-project"
  })
}

resource "vault_kv_secret_v2" "oidc_vault" {
  mount = "secret"
  name  = "oidc/vault"

  data_json = jsonencode({
    client_id     = keycloak_openid_client.vault.client_id
    client_secret = keycloak_openid_client.vault.client_secret
    issuer        = "https://keycloak.nss.jkzl.eu/realms/ass-nss-project"
  })
}
