# --- Static IP Ports ---
# Ports are created before instances so we can assign fixed IPs.
# Instances reference the port ID instead of the network name.

locals {
  cp_ips = [
    "192.168.0.10",
    "192.168.0.11",
    "192.168.0.12"
  ]
  worker_ips = [
    "192.168.0.20",
    "192.168.0.21"
  ]
}

resource "openstack_networking_port_v2" "cp" {
  count          = 3
  name           = "cp-${count.index}-port"
  network_id     = openstack_networking_network_v2.cluster.id
  admin_state_up = true

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.cluster.id
    ip_address = local.cp_ips[count.index]
  }

  security_group_ids = [
    openstack_networking_secgroup_v2.external.id,
    openstack_networking_secgroup_v2.internal.id,
  ]

  depends_on = [
    openstack_networking_subnet_v2.cluster,
    openstack_networking_secgroup_v2.external,
    openstack_networking_secgroup_v2.internal,
  ]
}

resource "openstack_networking_port_v2" "worker" {
  count          = 2
  name           = "worker-${count.index}-port"
  network_id     = openstack_networking_network_v2.cluster.id
  admin_state_up = true

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.cluster.id
    ip_address = local.worker_ips[count.index]
  }

  security_group_ids = [openstack_networking_secgroup_v2.internal.id]

  depends_on = [
    openstack_networking_subnet_v2.cluster,
    openstack_networking_secgroup_v2.internal,
  ]
}
