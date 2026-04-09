# --- Ansible Inventory Generation ---
# Writes inventory files directly after `terraform apply`.
# No manual IP copy-paste required.

locals {
  ansible_root = "${path.module}/../ansible"
}

resource "local_file" "ansible_hosts" {
  filename = "${local.ansible_root}/inventory/hosts.yml"
  content = templatefile(
    "${path.module}/templates/hosts.yml.tpl",
    {
      cp0_fip    = openstack_networking_floatingip_v2.cp0_ssh.address
      cp_ips     = local.cp_ips
      worker_ips = local.worker_ips
    }
  )
}

resource "local_file" "ansible_terraform_vars" {
  filename = "${local.ansible_root}/inventory/group_vars/all/terraform.yml"
  content = templatefile(
    "${path.module}/templates/terraform-vars.yml.tpl",
    { api_lb_fip = openstack_networking_floatingip_v2.cluster_lb.address }
  )
}
