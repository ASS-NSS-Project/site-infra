# --- RKE2 Control Plane (3 nodes, HA) ---

resource "openstack_compute_instance_v2" "control_plane" {
  count = 3

  name        = "cp-${count.index}"
  image_name  = "debian-13-x86_64"
  flavor_name = "c2.8core-16ram" # 8 vCPU, 16 GiB RAM
  key_pair    = "jkuzel"

  network {port = openstack_networking_port_v2.cp[count.index].id}
}

# --- RKE2 Worker Nodes (4 nodes) ---

resource "openstack_compute_instance_v2" "worker" {
  count = 4

  name        = "worker-${count.index}"
  image_name  = "debian-13-x86_64"
  flavor_name = "c2.8core-30ram" # 8 vCPU, 30 GiB RAM
  key_pair    = "jkuzel"

  network {port = openstack_networking_port_v2.worker[count.index].id}
}
