# Floating IP from Public Pool
resource "openstack_networking_floatingip_v2" "fip" {
  pool = "external-ipv4-general-public"
}

# Data Source of Specific Port Created for the Control-Plane Instance
data "openstack_networking_port_v2" "control_plane" {
  device_id = openstack_compute_instance_v2.control_plane.id

  depends_on = [openstack_compute_instance_v2.control_plane]
}

# Associate the FIP with the Control-Plane
resource "openstack_networking_floatingip_associate_v2" "fip" {
  port_id     = data.openstack_networking_port_v2.control_plane.id
  floating_ip = openstack_networking_floatingip_v2.fip.address

  depends_on = [
    openstack_compute_instance_v2.control_plane,
    openstack_networking_floatingip_v2.fip
  ]
}

# --- Outputs ---

output "control_plane_public_ip" {
  value = openstack_networking_floatingip_v2.fip.address
}

output "control_plane_private_ip" {
  value = openstack_compute_instance_v2.control_plane.network[0].fixed_ip_v4
}

output "worker_private_ips" {
  value = [for w in openstack_compute_instance_v2.worker : w.network[0].fixed_ip_v4]
}
