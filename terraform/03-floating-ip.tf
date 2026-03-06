# Floating IP From the Public Pool
resource "openstack_networking_floatingip_v2" "fip" {
  pool = "external-ipv4-general-public"
}

# Look Up the Specific Port Created for the Instance
data "openstack_networking_port_v2" "proxy_instance" {
  device_id = openstack_compute_instance_v2.proxy.id
}

# Associate The FIP Using the Port ID Found by the Data Source
resource "openstack_networking_floatingip_associate_v2" "fip" {
  floating_ip = openstack_networking_floatingip_v2.fip.address
  port_id     = data.openstack_networking_port_v2.proxy_instance.id
}
