# --- Network ---

data "openstack_networking_network_v2" "external" {
  name = "external-ipv4-general-public"
}

resource "openstack_networking_network_v2" "cluster" {
  name           = "group-project-network"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "cluster" {
  name            = "group-project-network-subnet"
  network_id      = openstack_networking_network_v2.cluster.id
  cidr            = "192.168.0.0/24"
  ip_version      = 4
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

resource "openstack_networking_router_v2" "cluster" {
  name                = "group-project-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
}

resource "openstack_networking_router_interface_v2" "cluster" {
  router_id = openstack_networking_router_v2.cluster.id
  subnet_id = openstack_networking_subnet_v2.cluster.id
}
