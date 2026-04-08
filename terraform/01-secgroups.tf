# --- Security Groups ---

resource "openstack_networking_secgroup_v2" "external" {
  name        = "external"
  description = "External Traffic"
}

resource "openstack_networking_secgroup_v2" "internal" {
  name        = "internal"
  description = "Internal Traffic"
}

# --- External Rules (control-plane node only) ---

resource "openstack_networking_secgroup_rule_v2" "ssh_external" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.external.id
}

resource "openstack_networking_secgroup_rule_v2" "icmp_external" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.external.id
}

resource "openstack_networking_secgroup_rule_v2" "http_external" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.external.id
}

resource "openstack_networking_secgroup_rule_v2" "https_external" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.external.id
}

# Kubernetes API server - needed for kubectl from outside the cluster
resource "openstack_networking_secgroup_rule_v2" "k8s_api_external" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.external.id
}

# NodePort range - for services exposed via NodePort/LoadBalancer on the ingress node
resource "openstack_networking_secgroup_rule_v2" "nodeport_external_tcp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 30000
  port_range_max    = 32767
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.external.id
}

resource "openstack_networking_secgroup_rule_v2" "nodeport_external_udp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 30000
  port_range_max    = 32767
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.external.id
}

# --- Internal Rules (all cluster nodes) ---

resource "openstack_networking_secgroup_rule_v2" "ssh_internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.internal.id
  security_group_id = openstack_networking_secgroup_v2.internal.id
}

resource "openstack_networking_secgroup_rule_v2" "icmp_internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_group_id   = openstack_networking_secgroup_v2.internal.id
  security_group_id = openstack_networking_secgroup_v2.internal.id
}

# Kubernetes API server
resource "openstack_networking_secgroup_rule_v2" "k8s_api_internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_group_id   = openstack_networking_secgroup_v2.internal.id
  security_group_id = openstack_networking_secgroup_v2.internal.id
}

# etcd
resource "openstack_networking_secgroup_rule_v2" "etcd_internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2379
  port_range_max    = 2380
  remote_group_id   = openstack_networking_secgroup_v2.internal.id
  security_group_id = openstack_networking_secgroup_v2.internal.id
}

# Kubelet API
resource "openstack_networking_secgroup_rule_v2" "kubelet_internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 10250
  port_range_max    = 10250
  remote_group_id   = openstack_networking_secgroup_v2.internal.id
  security_group_id = openstack_networking_secgroup_v2.internal.id
}

# kube-proxy health check
resource "openstack_networking_secgroup_rule_v2" "kube_proxy_internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 10256
  port_range_max    = 10256
  remote_group_id   = openstack_networking_secgroup_v2.internal.id
  security_group_id = openstack_networking_secgroup_v2.internal.id
}

# k3s Flannel VXLAN overlay network
resource "openstack_networking_secgroup_rule_v2" "flannel_vxlan_internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 8472
  port_range_max    = 8472
  remote_group_id   = openstack_networking_secgroup_v2.internal.id
  security_group_id = openstack_networking_secgroup_v2.internal.id
}

# NodePort range - internal access between nodes
resource "openstack_networking_secgroup_rule_v2" "nodeport_internal_tcp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 30000
  port_range_max    = 32767
  remote_group_id   = openstack_networking_secgroup_v2.internal.id
  security_group_id = openstack_networking_secgroup_v2.internal.id
}
