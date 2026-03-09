# --- Security Groups ---

resource "openstack_networking_secgroup_v2" "external" {
  name        = "external"
  description = "External Traffic Incoming to OpenStack"
}

resource "openstack_networking_secgroup_v2" "storage_internal" {
  name        = "storage-internal"
  description = "Internal GlusterFS & NFS Traffic"
}

resource "openstack_networking_secgroup_v2" "docker_swarm_mgmt" {
  name        = "docker-swarm-mgmt"
  description = "Docker Swarm Cluster Management and Discovery"
}

# --- Certain Rules for Appropriate Security Groups ---

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.external.id

  depends_on = [openstack_networking_secgroup_v2.external]
}

resource "openstack_networking_secgroup_rule_v2" "icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.external.id

  depends_on = [openstack_networking_secgroup_v2.external]
}

resource "openstack_networking_secgroup_rule_v2" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.external.id

  depends_on = [openstack_networking_secgroup_v2.external]
}

resource "openstack_networking_secgroup_rule_v2" "https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.external.id

  depends_on = [openstack_networking_secgroup_v2.external]
}

# # NFS
# resource "openstack_networking_secgroup_rule_v2" "nfs_tcp" {
#   direction         = "ingress"
#   ethertype         = "IPv4"
#   protocol          = "tcp"
#   port_range_min    = 2049
#   port_range_max    = 2049
#   remote_group_id   = openstack_networking_secgroup_v2.storage_internal.id
#   security_group_id = openstack_networking_secgroup_v2.storage_internal.id

#   depends_on = [openstack_networking_secgroup_v2.storage_internal]
# }

# # Portmapper (Required for NFS Handshake)
# resource "openstack_networking_secgroup_rule_v2" "portmap_tcp" {
#   direction         = "ingress"
#   ethertype         = "IPv4"
#   protocol          = "tcp"
#   port_range_min    = 111
#   port_range_max    = 111
#   remote_group_id   = openstack_networking_secgroup_v2.storage_internal.id
#   security_group_id = openstack_networking_secgroup_v2.storage_internal.id

#   depends_on = [openstack_networking_secgroup_v2.storage_internal]
# }

# Gluster Management (Daemon)
resource "openstack_networking_secgroup_rule_v2" "gluster_mgmt" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 24007
  port_range_max    = 24007
  remote_group_id   = openstack_networking_secgroup_v2.storage_internal.id
  security_group_id = openstack_networking_secgroup_v2.storage_internal.id

  depends_on = [openstack_networking_secgroup_v2.storage_internal]
}

# Gluster Bricks (Data Shards) - Gluster uses a range of ports starting from 49152
resource "openstack_networking_secgroup_rule_v2" "gluster_bricks" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 49152
  port_range_max    = 65535
  remote_group_id   = openstack_networking_secgroup_v2.storage_internal.id
  security_group_id = openstack_networking_secgroup_v2.storage_internal.id

  depends_on = [openstack_networking_secgroup_v2.storage_internal]
}

# Docker Swarm Cluster Management
resource "openstack_networking_secgroup_rule_v2" "docker_swarm_mgmt" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2377
  port_range_max    = 2377
  remote_group_id   = openstack_networking_secgroup_v2.docker_swarm_mgmt.id
  security_group_id = openstack_networking_secgroup_v2.docker_swarm_mgmt.id

  depends_on = [openstack_networking_secgroup_v2.docker_swarm_mgmt]
}

# Docker Swarm Cluster Node Discovery (TCP)
resource "openstack_networking_secgroup_rule_v2" "docker_swarm_discovery_tcp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 7946
  port_range_max    = 7946
  remote_group_id   = openstack_networking_secgroup_v2.docker_swarm_mgmt.id
  security_group_id = openstack_networking_secgroup_v2.docker_swarm_mgmt.id

  depends_on = [openstack_networking_secgroup_v2.docker_swarm_mgmt]
}

# Docker Swarm Cluster Node Discovery (UDP)
resource "openstack_networking_secgroup_rule_v2" "docker_swarm_discovery_udp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 7946
  port_range_max    = 7946
  remote_group_id   = openstack_networking_secgroup_v2.docker_swarm_mgmt.id
  security_group_id = openstack_networking_secgroup_v2.docker_swarm_mgmt.id

  depends_on = [openstack_networking_secgroup_v2.docker_swarm_mgmt]
}

# Docker Swarm Cluster Overlay VXLAN Network
resource "openstack_networking_secgroup_rule_v2" "docker_swarm_vxlan" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 4789
  port_range_max    = 4789
  remote_group_id   = openstack_networking_secgroup_v2.docker_swarm_mgmt.id
  security_group_id = openstack_networking_secgroup_v2.docker_swarm_mgmt.id

  depends_on = [openstack_networking_secgroup_v2.docker_swarm_mgmt]
}
