# --- Static IP Ports ---
# Ports are created before instances so we can assign fixed IPs.
# Instances reference the port ID instead of the network name.

locals {
  cp_ips = [
    "10.8.0.10",
    "10.8.0.11",
    "10.8.0.12"
  ]

  worker_ips = [
    "10.8.0.20",
    "10.8.0.21",
    "10.8.0.22",
    "10.8.0.23"
  ]
}

resource "openstack_networking_port_v2" "cp" {
  count = 3

  name           = "cp-${count.index}-port"
  network_id     = openstack_networking_network_v2.cluster.id
  admin_state_up = true

  security_group_ids = [
    openstack_networking_secgroup_v2.external.id,
    openstack_networking_secgroup_v2.internal.id
  ]

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.cluster.id
    ip_address = local.cp_ips[count.index]
  }
}

resource "openstack_networking_port_v2" "worker" {
  count = 4

  name           = "worker-${count.index}-port"
  network_id     = openstack_networking_network_v2.cluster.id
  admin_state_up = true

  security_group_ids = [openstack_networking_secgroup_v2.internal.id]

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.cluster.id
    ip_address = local.worker_ips[count.index]
  }
}
