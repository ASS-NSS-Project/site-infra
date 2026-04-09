# --- Control Plane Volumes (1 × 111 GB per node → /var/lib/rancher/k3s) ---

resource "openstack_blockstorage_volume_v3" "control_plane" {
  count       = 3
  name        = "cp-${count.index}-data"
  size        = 111
  volume_type = "du-ceph-muni1-hdd"
}

resource "openstack_compute_volume_attach_v2" "control_plane" {
  count       = 3
  instance_id = openstack_compute_instance_v2.control_plane[count.index].id
  volume_id   = openstack_blockstorage_volume_v3.control_plane[count.index].id
}

# --- Worker Volumes (3 × 111 GB per node → LVM → /var/lib/longhorn, 333 GB each) ---
# 2 workers × 3 volumes = 6 worker volumes, 9 total with CP volumes.

resource "openstack_blockstorage_volume_v3" "worker" {
  count       = 6
  name        = "worker-${floor(count.index / 3)}-disk-${count.index % 3}"
  size        = 111
  volume_type = "du-ceph-muni1-hdd"
}

resource "openstack_compute_volume_attach_v2" "worker" {
  count       = 6
  instance_id = openstack_compute_instance_v2.worker[floor(count.index / 3)].id
  volume_id   = openstack_blockstorage_volume_v3.worker[count.index].id
}
