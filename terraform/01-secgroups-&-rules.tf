# Security Groups
resource "openstack_networking_secgroup_v2" "icmp" {
  name        = "icmp"
  description = "Allow ICMP"
}

resource "openstack_networking_secgroup_v2" "http" {
  name        = "http"
  description = "Allow HTTP"
}

resource "openstack_networking_secgroup_v2" "https" {
  name        = "https"
  description = "Allow HTTPS"
}

resource "openstack_networking_secgroup_v2" "storage_internal" {
  name        = "storage-internal"
  description = "Allow Internal GlusterFS & NFS traffic"
}

# Certain Rules for Appropriate Security Groups
resource "openstack_networking_secgroup_rule_v2" "icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.icmp.id

  depends_on = [openstack_networking_secgroup_v2.icmp]
}

resource "openstack_networking_secgroup_rule_v2" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.http.id

  depends_on = [openstack_networking_secgroup_v2.http]
}

resource "openstack_networking_secgroup_rule_v2" "https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.https.id

  depends_on = [openstack_networking_secgroup_v2.https]
}

# NFS
resource "openstack_networking_secgroup_rule_v2" "nfs_tcp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2049
  port_range_max    = 2049
  remote_group_id   = openstack_networking_secgroup_v2.storage_internal.id
  security_group_id = openstack_networking_secgroup_v2.storage_internal.id

  depends_on = [openstack_networking_secgroup_v2.storage_internal]
}

# Portmapper (Required for NFS Handshake)
resource "openstack_networking_secgroup_rule_v2" "portmap_tcp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 111
  port_range_max    = 111
  remote_group_id   = openstack_networking_secgroup_v2.storage_internal.id
  security_group_id = openstack_networking_secgroup_v2.storage_internal.id

  depends_on = [openstack_networking_secgroup_v2.storage_internal]
}

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
  port_range_max    = 49251
  remote_group_id   = openstack_networking_secgroup_v2.storage_internal.id
  security_group_id = openstack_networking_secgroup_v2.storage_internal.id

  depends_on = [openstack_networking_secgroup_v2.storage_internal]
}
