# --- Security Groups ---

resource "openstack_networking_secgroup_v2" "external" {
  name        = "external"
  description = "External Traffic"
}

resource "openstack_networking_secgroup_v2" "internal" {
  name        = "internal"
  description = "Internal Traffic"
}

# --- Certain Rules for Appropriate Security Groups ---

# - External Traffic

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

# - Internal Traffic

resource "openstack_networking_secgroup_rule_v2" "ssh_internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.internal.id
  security_group_id = openstack_networking_secgroup_v2.internal.id

  depends_on = [openstack_networking_secgroup_v2.internal]
}

resource "openstack_networking_secgroup_rule_v2" "icmp_internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_group_id   = openstack_networking_secgroup_v2.internal.id
  security_group_id = openstack_networking_secgroup_v2.internal.id

  depends_on = [openstack_networking_secgroup_v2.internal]
}

# Gluster Management (Daemon)
resource "openstack_networking_secgroup_rule_v2" "gluster_mgmt" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 24007
  port_range_max    = 24007
  remote_group_id   = openstack_networking_secgroup_v2.internal.id
  security_group_id = openstack_networking_secgroup_v2.internal.id

  depends_on = [openstack_networking_secgroup_v2.internal]
}

# Gluster Bricks (Data Shards) - Gluster uses a range of ports starting from 49152
resource "openstack_networking_secgroup_rule_v2" "gluster_bricks" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 49152
  port_range_max    = 65535
  remote_group_id   = openstack_networking_secgroup_v2.internal.id
  security_group_id = openstack_networking_secgroup_v2.internal.id

  depends_on = [openstack_networking_secgroup_v2.internal]
}

# Docker Swarm Cluster Management
resource "openstack_networking_secgroup_rule_v2" "docker_swarm_mgmt" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2377
  port_range_max    = 2377
  remote_group_id   = openstack_networking_secgroup_v2.internal.id
  security_group_id = openstack_networking_secgroup_v2.internal.id

  depends_on = [openstack_networking_secgroup_v2.internal]
}

# Docker Swarm Cluster Node Discovery (TCP)
resource "openstack_networking_secgroup_rule_v2" "docker_swarm_discovery_tcp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 7946
  port_range_max    = 7946
  remote_group_id   = openstack_networking_secgroup_v2.internal.id
  security_group_id = openstack_networking_secgroup_v2.internal.id

  depends_on = [openstack_networking_secgroup_v2.internal]
}

# Docker Swarm Cluster Node Discovery (UDP)
resource "openstack_networking_secgroup_rule_v2" "docker_swarm_discovery_udp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 7946
  port_range_max    = 7946
  remote_group_id   = openstack_networking_secgroup_v2.internal.id
  security_group_id = openstack_networking_secgroup_v2.internal.id

  depends_on = [openstack_networking_secgroup_v2.internal]
}

# Docker Swarm Cluster Overlay VXLAN Network
resource "openstack_networking_secgroup_rule_v2" "docker_swarm_vxlan" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 4789
  port_range_max    = 4789
  remote_group_id   = openstack_networking_secgroup_v2.internal.id
  security_group_id = openstack_networking_secgroup_v2.internal.id

  depends_on = [openstack_networking_secgroup_v2.internal]
}
