# --- Single Cluster Load Balancer ---
# e-INFRA quota allows only 1 LB per project.
# All traffic (kubectl API on 6443, HTTP on 80, HTTPS on 443) shares one LB.
# FIP is attached in 07-floating-ips.tf — point DNS and kubeconfig there.
#
# IMPORTANT: Octavia puts the LB into PENDING_UPDATE while each listener/pool/member
# is being created. Chains must be serialized — each chain must fully complete
# before the next starts.

resource "openstack_lb_loadbalancer_v2" "cluster" {
  name          = "k8s-cluster-lb"
  vip_subnet_id = openstack_networking_subnet_v2.cluster.id
  vip_address   = "10.8.0.100"

  depends_on = [
    openstack_networking_router_interface_v2.cluster,
    openstack_networking_network_v2.cluster,
  ]
}

# --- API chain (6443) ---

resource "openstack_lb_listener_v2" "api" {
  name            = "k8s-api-listener"
  protocol        = "TCP"
  protocol_port   = 6443
  loadbalancer_id = openstack_lb_loadbalancer_v2.cluster.id
}

resource "openstack_lb_pool_v2" "api" {
  name        = "k8s-api-pool"
  protocol    = "TCP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.api.id
}

resource "openstack_lb_member_v2" "api" {
  count = 3

  pool_id       = openstack_lb_pool_v2.api.id
  address       = local.cp_ips[count.index]
  protocol_port = 6443
  subnet_id     = openstack_networking_subnet_v2.cluster.id

  depends_on = [openstack_compute_instance_v2.control_plane]
}

resource "openstack_lb_monitor_v2" "api" {
  pool_id     = openstack_lb_pool_v2.api.id
  type        = "TCP"
  delay       = 5
  timeout     = 5
  max_retries = 3

  depends_on = [openstack_lb_member_v2.api]
}

# --- RKE2 registration chain (9345) — used by all nodes to join the cluster ---

resource "openstack_lb_listener_v2" "rke2_register" {
  name            = "rke2-register-listener"
  protocol        = "TCP"
  protocol_port   = 9345
  loadbalancer_id = openstack_lb_loadbalancer_v2.cluster.id

  # Only cluster nodes may reach the registration endpoint.
  # 10.8.0.0/27 covers .0–.31 — all CP (.10–.12) and worker (.20–.23) IPs.
  allowed_cidrs = ["10.8.0.0/27"]

  depends_on = [openstack_lb_monitor_v2.api]
}

resource "openstack_lb_pool_v2" "rke2_register" {
  name        = "rke2-register-pool"
  protocol    = "TCP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.rke2_register.id
}

resource "openstack_lb_member_v2" "rke2_register" {
  count = 3

  pool_id       = openstack_lb_pool_v2.rke2_register.id
  address       = local.cp_ips[count.index]
  protocol_port = 9345
  subnet_id     = openstack_networking_subnet_v2.cluster.id

  depends_on = [openstack_compute_instance_v2.control_plane]
}

resource "openstack_lb_monitor_v2" "rke2_register" {
  pool_id     = openstack_lb_pool_v2.rke2_register.id
  type        = "TCP"
  delay       = 5
  timeout     = 5
  max_retries = 3

  depends_on = [openstack_lb_member_v2.rke2_register]
}

# --- HTTP chain (80) — forwards directly to Traefik hostPort 80 on each CP ---

resource "openstack_lb_listener_v2" "ingress_http" {
  name            = "k8s-ingress-http"
  protocol        = "TCP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.cluster.id

  depends_on = [openstack_lb_monitor_v2.rke2_register]
}

resource "openstack_lb_pool_v2" "ingress_http" {
  name        = "k8s-ingress-http-pool"
  protocol    = "TCP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.ingress_http.id
}

resource "openstack_lb_member_v2" "ingress_http" {
  count = 3

  pool_id       = openstack_lb_pool_v2.ingress_http.id
  address       = local.cp_ips[count.index]
  protocol_port = 80
  subnet_id     = openstack_networking_subnet_v2.cluster.id

  depends_on = [openstack_compute_instance_v2.control_plane]
}

resource "openstack_lb_monitor_v2" "ingress_http" {
  pool_id     = openstack_lb_pool_v2.ingress_http.id
  type        = "TCP"
  delay       = 5
  timeout     = 5
  max_retries = 3

  depends_on = [openstack_lb_member_v2.ingress_http]
}

# --- HTTPS chain (443) — forwards directly to Traefik hostPort 443 on each CP ---

resource "openstack_lb_listener_v2" "ingress_https" {
  name            = "k8s-ingress-https"
  protocol        = "TCP"
  protocol_port   = 443
  loadbalancer_id = openstack_lb_loadbalancer_v2.cluster.id

  depends_on = [openstack_lb_monitor_v2.ingress_http]
}

resource "openstack_lb_pool_v2" "ingress_https" {
  name        = "k8s-ingress-https-pool"
  protocol    = "TCP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.ingress_https.id
}

resource "openstack_lb_member_v2" "ingress_https" {
  count = 3

  pool_id       = openstack_lb_pool_v2.ingress_https.id
  address       = local.cp_ips[count.index]
  protocol_port = 443
  subnet_id     = openstack_networking_subnet_v2.cluster.id

  depends_on = [openstack_compute_instance_v2.control_plane]
}

resource "openstack_lb_monitor_v2" "ingress_https" {
  pool_id     = openstack_lb_pool_v2.ingress_https.id
  type        = "TCP"
  delay       = 5
  timeout     = 5
  max_retries = 3

  depends_on = [openstack_lb_member_v2.ingress_https]
}
