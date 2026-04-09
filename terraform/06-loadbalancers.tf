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
  vip_address   = "192.168.0.100"
  depends_on    = [openstack_networking_router_interface_v2.cluster]
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
  count         = 3
  pool_id       = openstack_lb_pool_v2.api.id
  address       = local.cp_ips[count.index]
  protocol_port = 6443
  subnet_id     = openstack_networking_subnet_v2.cluster.id
  depends_on    = [openstack_compute_instance_v2.control_plane]
}

resource "openstack_lb_monitor_v2" "api" {
  pool_id     = openstack_lb_pool_v2.api.id
  type        = "TCP"
  delay       = 5
  timeout     = 5
  max_retries = 3
  depends_on  = [openstack_lb_member_v2.api]
}

# --- HTTP chain (80) — starts after API chain is fully complete ---

resource "openstack_lb_listener_v2" "ingress_http" {
  name            = "k8s-ingress-http"
  protocol        = "TCP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.cluster.id
  depends_on      = [openstack_lb_monitor_v2.api]
}

resource "openstack_lb_pool_v2" "ingress_http" {
  name        = "k8s-ingress-http-pool"
  protocol    = "TCP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.ingress_http.id
}

resource "openstack_lb_member_v2" "ingress_http" {
  count         = 3
  pool_id       = openstack_lb_pool_v2.ingress_http.id
  address       = local.cp_ips[count.index]
  protocol_port = 30080
  subnet_id     = openstack_networking_subnet_v2.cluster.id
  depends_on    = [openstack_compute_instance_v2.control_plane]
}

resource "openstack_lb_monitor_v2" "ingress_http" {
  pool_id     = openstack_lb_pool_v2.ingress_http.id
  type        = "TCP"
  delay       = 5
  timeout     = 5
  max_retries = 3
  depends_on  = [openstack_lb_member_v2.ingress_http]
}

# --- HTTPS chain (443) — starts after HTTP chain is fully complete ---

resource "openstack_lb_listener_v2" "ingress_https" {
  name            = "k8s-ingress-https"
  protocol        = "TCP"
  protocol_port   = 443
  loadbalancer_id = openstack_lb_loadbalancer_v2.cluster.id
  depends_on      = [openstack_lb_monitor_v2.ingress_http]
}

resource "openstack_lb_pool_v2" "ingress_https" {
  name        = "k8s-ingress-https-pool"
  protocol    = "TCP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.ingress_https.id
}

resource "openstack_lb_member_v2" "ingress_https" {
  count         = 3
  pool_id       = openstack_lb_pool_v2.ingress_https.id
  address       = local.cp_ips[count.index]
  protocol_port = 30443
  subnet_id     = openstack_networking_subnet_v2.cluster.id
  depends_on    = [openstack_compute_instance_v2.control_plane]
}

resource "openstack_lb_monitor_v2" "ingress_https" {
  pool_id     = openstack_lb_pool_v2.ingress_https.id
  type        = "TCP"
  delay       = 5
  timeout     = 5
  max_retries = 3
  depends_on  = [openstack_lb_member_v2.ingress_https]
}
