# --- Ansible Inventory & Cloudflare tfvars Generation ---
# Writes inventory files directly after `terraform apply`.
# No manual IP copy-paste required.

locals {
  ansible_root    = "${path.module}/../../ansible"
  cloudflare_root = "${path.module}/../cloudflare"
}

# cp-0's ansible_host must be the floating IP — generated here.
resource "local_file" "cp0_host_vars" {
  filename = "${local.ansible_root}/inventory/host_vars/cp-0.yml"
  content = templatefile(
    "${path.module}/templates/cp-0-host-vars.yml.tpl",
    { cp0_fip = openstack_networking_floatingip_v2.cp0_ssh.address }
  )
}

resource "local_file" "ansible_terraform_vars" {
  filename = "${local.ansible_root}/inventory/group_vars/all/terraform.yml"
  content = templatefile(
    "${path.module}/templates/terraform-vars.yml.tpl",
    { openstack_lb_ip = openstack_networking_floatingip_v2.cluster_lb.address }
  )
}

# Writes the ingress IP into terraform/cloudflare/ so the next apply picks it up automatically.
# *.auto.tfvars files are loaded by Terraform without any flags — no manual copy-paste needed.
resource "local_file" "cloudflare_openstack_lb_ip" {
  filename = "${local.cloudflare_root}/openstack-lb-ip.auto.tfvars"
  content  = "openstack_lb_ip = \"${openstack_networking_floatingip_v2.cluster_lb.address}\"\n"
}
