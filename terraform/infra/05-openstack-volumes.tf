# --- Control Plane Volumes (1 × 32 GB per node → /var/lib/rancher/rke2) ---
# etcd data peaks at a few GB even in large clusters; 32 GB covers etcd +
# RKE2 binaries + static manifests with comfortable headroom.

resource "openstack_blockstorage_volume_v3" "control_plane" {
  count = 3

  name        = "cp-${count.index}-data"
  size        = 32
  volume_type = "du-ceph-muni1-hdd"
}

resource "openstack_compute_volume_attach_v2" "control_plane" {
  count = 3

  instance_id = openstack_compute_instance_v2.control_plane[count.index].id
  volume_id   = openstack_blockstorage_volume_v3.control_plane[count.index].id
}

# --- Worker Volumes (3 × 158 GB per node → LVM → /var/lib/longhorn) ---
# 4 workers × 3 volumes = 12 worker volumes, 15 total with CP volumes.
# Per-worker usable: 3 × 158 GB = 474 GB; cluster total: 1 896 GB.
# Combined with CP volumes: 1 992 GB of 2 000 GB quota.

resource "openstack_blockstorage_volume_v3" "worker" {
  count = 12

  name        = "worker-${floor(count.index / 3)}-disk-${count.index % 3}"
  size        = 158
  volume_type = "du-ceph-muni1-hdd"
}

resource "openstack_compute_volume_attach_v2" "worker" {
  count = 12

  instance_id = openstack_compute_instance_v2.worker[floor(count.index / 3)].id
  volume_id   = openstack_blockstorage_volume_v3.worker[count.index].id
}
