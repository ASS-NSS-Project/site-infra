# Floating IP from Public Pool
resource "openstack_networking_floatingip_v2" "fip" {
  pool = "external-ipv4-general-public"
}

# Data Source of Specific Port Created for the Instance `swarm_manager_0`
data "openstack_networking_port_v2" "swarm_manager_0" {
  device_id = openstack_compute_instance_v2.swarm_manager_0.id

  depends_on = [openstack_compute_instance_v2.swarm_manager_0]
}

# Association of the FIP Using Port ID Found by the Data Source
resource "openstack_networking_floatingip_associate_v2" "fip" {
  port_id     = data.openstack_networking_port_v2.swarm_manager_0.id
  floating_ip = openstack_networking_floatingip_v2.fip.address

  depends_on = [
    openstack_compute_instance_v2.swarm_manager_0,
    openstack_networking_floatingip_v2.fip
  ]
}

# Output Data Source of the Public IPv4 Address
output "public_ip" {
  value = openstack_networking_floatingip_v2.fip.address
}
