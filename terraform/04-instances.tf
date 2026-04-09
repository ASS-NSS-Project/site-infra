# --- k3s Control Plane (3 nodes, HA) ---

resource "openstack_compute_instance_v2" "control_plane" {
  count       = 3
  name        = "cp-${count.index}"
  image_name  = "debian-13-x86_64"
  flavor_name = "e1.large" # 4 vCPU, 8 GB RAM
  key_pair    = "jkuzel"

  network {
    port = openstack_networking_port_v2.cp[count.index].id
  }

  depends_on = [openstack_networking_port_v2.cp]
}

# --- k3s Worker Nodes (2 nodes) ---

resource "openstack_compute_instance_v2" "worker" {
  count       = 2
  name        = "worker-${count.index}"
  image_name  = "debian-13-x86_64"
  flavor_name = "e1.4core-16ram" # 4 vCPU, 16 GB RAM
  key_pair    = "jkuzel"

  network {
    port = openstack_networking_port_v2.worker[count.index].id
  }

  depends_on = [openstack_networking_port_v2.worker]
}
