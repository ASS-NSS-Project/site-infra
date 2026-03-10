# Floating IP from Public Pool
resource "openstack_networking_floatingip_v2" "fip" {
  pool = "external-ipv4-general-public"
}

# Data Source of Specific Port Created for the Instance `swarm_ingress`
data "openstack_networking_port_v2" "swarm_ingress" {
  device_id = openstack_compute_instance_v2.swarm_ingress.id

  depends_on = [openstack_compute_instance_v2.swarm_ingress]
}

# Association of the FIP Using Port ID Found by the Data Source
resource "openstack_networking_floatingip_associate_v2" "fip" {
  port_id     = data.openstack_networking_port_v2.swarm_ingress.id
  floating_ip = openstack_networking_floatingip_v2.fip.address

  depends_on = [
    openstack_compute_instance_v2.swarm_ingress,
    openstack_networking_floatingip_v2.fip
  ]
}

# Output Data Source of the Public IPv4 Address
output "ingress_public_ip" {
  value = openstack_networking_floatingip_v2.fip.address
}

# Output Data Source of the Private IPv4 Addresses
output "ingress_private_ip" {
  value = openstack_compute_instance_v2.swarm_ingress.network[0].fixed_ip_v4
}

output "node_0_private_ip" {
  value = openstack_compute_instance_v2.swarm_node_0.network[0].fixed_ip_v4
}

output "node_1_private_ip" {
  value = openstack_compute_instance_v2.swarm_node_1.network[0].fixed_ip_v4
}

output "node_2_private_ip" {
  value = openstack_compute_instance_v2.swarm_node_2.network[0].fixed_ip_v4
}
