# --- k3s Control-Plane ---

resource "openstack_compute_instance_v2" "control_plane" {
  name        = "k8s-control-plane"
  image_name  = "debian-13-x86_64"
  flavor_name = "e1.large" # 4 vCPU, 8 GB RAM
  key_pair    = "jkuzel"

  security_groups = [
    "external",
    "internal"
  ]

  network {
    name = "group-project-network"
  }

  depends_on = [
    openstack_networking_secgroup_v2.external,
    openstack_networking_secgroup_v2.internal
  ]
}

# --- k3s Worker Nodes ---

resource "openstack_compute_instance_v2" "worker" {
  count = 3

  name        = "k8s-worker-${count.index}"
  image_name  = "debian-13-x86_64"
  flavor_name = "e1.4core-16ram" # 4 vCPU, 16 GB RAM
  key_pair    = "jkuzel"

  security_groups = ["internal"]

  network {
    name = "group-project-network"
  }

  depends_on = [openstack_networking_secgroup_v2.internal]
}
