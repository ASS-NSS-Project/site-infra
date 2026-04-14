# --- Floating IPs ---

# CP-0: SSH bastion (jump host) — the only node directly reachable from the internet
# (for remote management purposes; use the cp-0 for SSH ProxyJumping)
resource "openstack_networking_floatingip_v2" "cp0_ssh" {
  pool = "external-ipv4-general-public"
}

resource "openstack_networking_floatingip_associate_v2" "cp0_ssh" {
  floating_ip = openstack_networking_floatingip_v2.cp0_ssh.address
  port_id     = openstack_networking_port_v2.cp[0].id
}

# Cluster LB: single FIP for API (6443) + ingress (80/443).
# Point all DNS A records here; use this IP in kubeconfig.
resource "openstack_networking_floatingip_v2" "cluster_lb" {
  pool = "external-ipv4-general-public"
}

resource "openstack_networking_floatingip_associate_v2" "cluster_lb" {
  floating_ip = openstack_networking_floatingip_v2.cluster_lb.address
  port_id     = openstack_lb_loadbalancer_v2.cluster.vip_port_id
}

# --- Outputs ---

output "cp0_public_ip" {
  description = "CP-0 floating IP — SSH bastion (ssh debian@<ip>)"
  value       = openstack_networking_floatingip_v2.cp0_ssh.address
}

output "api_lb_public_ip" {
  description = "Cluster LB floating IP — kubectl API (6443) + ingress (80/443). Written to group_vars/all/terraform.yml as rke2_api_lb_fip."
  value       = openstack_networking_floatingip_v2.cluster_lb.address
}

output "ingress_lb_public_ip" {
  description = "Same as api_lb_public_ip — single LB serves both API and ingress traffic."
  value       = openstack_networking_floatingip_v2.cluster_lb.address
}

output "cp_private_ips" {
  value = local.cp_ips
}

output "worker_private_ips" {
  value = local.worker_ips
}
