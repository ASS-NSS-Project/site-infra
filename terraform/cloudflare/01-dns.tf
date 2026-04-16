# DNS records for jkzl.eu
# One A record at the apex pointing to the cluster ingress LB.
# All service subdomains are CNAMEs — updating the A record propagates everywhere.

resource "cloudflare_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = "nss"
  value   = var.openstack_lb_ip
  type    = "A"
  ttl     = 300
  proxied = false
}

locals {
  subdomains = [
    "argocd",
    "longhorn",
    "vault",
    "keycloak",
    "grafana",
    "prometheus",
    "alertmanager",
  ]
}

resource "cloudflare_record" "subdomains" {
  for_each = toset(local.subdomains)

  zone_id = var.cloudflare_zone_id
  name    = "${each.value}.nss"
  value   = "nss.jkzl.eu"
  type    = "CNAME"
  ttl     = 300
  proxied = false
}
