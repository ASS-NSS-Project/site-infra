# --- Docker Swarm Ingress Instance ---

resource "openstack_compute_instance_v2" "swarm_ingress" {
  name        = "swarm-ingress"
  image_name  = "debian-13-x86_64"
  flavor_name = "e1.tiny" # 2 GiB RAM, 2 vCPUs
  key_pair    = "jkuzel"

  security_groups = [
    "external",
    "internal"
  ]

  network {
    name = "internal-ipv4-general-private"
  }

  depends_on = [
    openstack_networking_secgroup_v2.external,
    openstack_networking_secgroup_v2.internal
  ]
}

# --- Docker Swarm Node Instances ---

resource "openstack_compute_instance_v2" "swarm_node_0" {
  name        = "swarm-node-0"
  image_name  = "debian-13-x86_64"
  flavor_name = "e1.4core-16ram" # 16 GiB RAM, 4 vCPUs
  key_pair    = "jkuzel"

  security_groups = ["internal"]

  network { name = "internal-ipv4-general-private" }
  depends_on = [openstack_networking_secgroup_v2.internal]
}

resource "openstack_compute_instance_v2" "swarm_node_1" {
  name        = "swarm-node-1"
  image_name  = "debian-13-x86_64"
  flavor_name = "e1.4core-16ram" # 16 GiB RAM, 4 vCPUs
  key_pair    = "jkuzel"

  security_groups = ["internal"]

  network { name = "internal-ipv4-general-private" }
  depends_on = [openstack_networking_secgroup_v2.internal]
}

resource "openstack_compute_instance_v2" "swarm_node_2" {
  name        = "swarm-node-2"
  image_name  = "debian-13-x86_64"
  flavor_name = "e1.4core-16ram" # 16 GiB RAM, 4 vCPUs
  key_pair    = "jkuzel"

  security_groups = ["internal"]

  network { name = "internal-ipv4-general-private" }
  depends_on = [openstack_networking_secgroup_v2.internal]
}
