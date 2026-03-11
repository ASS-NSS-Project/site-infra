# Floating IP from Public Pool
resource "openstack_networking_floatingip_v2" "fip" {
  pool = "external-ipv4-general-public"
}

# Data Source of Specific Port Created for the Instance `swarm_0`
data "openstack_networking_port_v2" "swarm_0" {
  device_id = openstack_compute_instance_v2.swarm_0.id

  depends_on = [openstack_compute_instance_v2.swarm_0]
}

# Association of the FIP Using Port ID Found by the Data Source
resource "openstack_networking_floatingip_associate_v2" "fip" {
  port_id     = data.openstack_networking_port_v2.swarm_0.id
  floating_ip = openstack_networking_floatingip_v2.fip.address

  depends_on = [
    openstack_compute_instance_v2.swarm_0,
    openstack_networking_floatingip_v2.fip
  ]
}

# Output Data Source of the Public IPv4 Address
output "swarm_0_public_ip" {
  value = openstack_networking_floatingip_v2.fip.address
}

# Output Data Source of the Private IPv4 Addresses
output "swarm_0_private_ip" {
  value = openstack_compute_instance_v2.swarm_0.network[0].fixed_ip_v4
}

output "swarm_1_private_ip" {
  value = openstack_compute_instance_v2.swarm_1.network[0].fixed_ip_v4
}

output "swarm_2_private_ip" {
  value = openstack_compute_instance_v2.swarm_2.network[0].fixed_ip_v4
}

output "backup_private_ip" {
  value = openstack_compute_instance_v2.backup.network[0].fixed_ip_v4
}
