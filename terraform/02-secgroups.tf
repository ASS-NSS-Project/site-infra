# --- Security Groups ---

resource "openstack_networking_secgroup_v2" "external" {
  name        = "external"
  description = "External Traffic"
}

resource "openstack_networking_secgroup_v2" "internal" {
  name        = "internal"
  description = "Internal Traffic"
}

# --- External Rules (applied to CP-0 bastion + LB VIP ports) ---

resource "openstack_networking_secgroup_rule_v2" "ssh_external" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.external.id

  depends_on = [openstack_networking_secgroup_v2.external]
}

resource "openstack_networking_secgroup_rule_v2" "icmp_external" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.external.id

  depends_on = [openstack_networking_secgroup_v2.external]
}

resource "openstack_networking_secgroup_rule_v2" "http_external" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.external.id

  depends_on = [openstack_networking_secgroup_v2.external]
}

resource "openstack_networking_secgroup_rule_v2" "https_external" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.external.id

  depends_on = [openstack_networking_secgroup_v2.external]
}

# Kubernetes API server — exposed via API LB FIP
resource "openstack_networking_secgroup_rule_v2" "k8s_api_external" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.external.id

  depends_on = [openstack_networking_secgroup_v2.external]
}

# --- Internal Rules (all cluster nodes) ---

# Allow all inbound from the project subnet — covers intra-cluster traffic,
# Octavia health checks, and LB-to-member forwarded traffic.
resource "openstack_networking_secgroup_rule_v2" "all_internal_subnet" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "10.8.0.0/24"
  security_group_id = openstack_networking_secgroup_v2.internal.id

  depends_on = [openstack_networking_secgroup_v2.internal]
}

# Allow intra-cluster traffic (pods, kubelet, etcd, VXLAN)
resource "openstack_networking_secgroup_rule_v2" "all_internal_group" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = openstack_networking_secgroup_v2.internal.id
  security_group_id = openstack_networking_secgroup_v2.internal.id

  depends_on = [openstack_networking_secgroup_v2.internal]
}
