# Output the IP
output "public_ip" {
  value = openstack_networking_floatingip_v2.fip.address
}

output "site_a_private_ip" {
  value = openstack_compute_instance_v2.site_a.network.0.fixed_ip_v4
}

output "site_b_private_ip" {
  value = openstack_compute_instance_v2.site_b.network.0.fixed_ip_v4
}
