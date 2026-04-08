# --- Control Plane Volume ---

resource "openstack_blockstorage_volume_v3" "control_plane" {
  name        = "k8s-control-plane-data"
  size        = 100
  volume_type = "du-ceph-muni1-hdd"
}

resource "openstack_compute_volume_attach_v2" "control_plane" {
  instance_id = openstack_compute_instance_v2.control_plane.id
  volume_id   = openstack_blockstorage_volume_v3.control_plane.id

  depends_on = [
    openstack_compute_instance_v2.control_plane,
    openstack_blockstorage_volume_v3.control_plane
  ]
}

# --- Worker Volumes (3 per worker, combined via LVM in Ansible) ---
# 3 workers × 3 volumes × 100 GB = 900 GB
# LVM pools the 3 disks per node into a single 300 GB LV mounted at /var/lib/longhorn

resource "openstack_blockstorage_volume_v3" "worker" {
  count = 9 # 3 workers × 3 volumes

  name        = "k8s-worker-${floor(count.index / 3)}-disk-${count.index % 3}"
  size        = 100
  volume_type = "du-ceph-muni1-hdd"
}

resource "openstack_compute_volume_attach_v2" "worker" {
  count = 9

  instance_id = openstack_compute_instance_v2.worker[floor(count.index / 3)].id
  volume_id   = openstack_blockstorage_volume_v3.worker[count.index].id

  depends_on = [
    openstack_compute_instance_v2.worker,
    openstack_blockstorage_volume_v3.worker
  ]
}
