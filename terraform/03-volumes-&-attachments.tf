# External Volumes (Block Storage) Instances
resource "openstack_blockstorage_volume_v3" "swarm_0_external" {
  name        = "swarm-0-external-hdd"
  size        = 200
  volume_type = "du-ceph-muni1-hdd"
}

resource "openstack_blockstorage_volume_v3" "swarm_1_external" {
  name        = "swarm-1-external-hdd"
  size        = 200
  volume_type = "du-ceph-muni1-hdd"
}

resource "openstack_blockstorage_volume_v3" "swarm_2_external" {
  name        = "swarm-2-external-hdd"
  size        = 200
  volume_type = "du-ceph-muni1-hdd"
}

resource "openstack_blockstorage_volume_v3" "backup_external" {
  name        = "backup-external-hdd"
  size        = 400
  volume_type = "du-ceph-muni1-hdd"
}

# Attachment of External Volumes to Network Share Instances
resource "openstack_compute_volume_attach_v2" "swarm_0_external" {
  instance_id = openstack_compute_instance_v2.swarm_0.id
  volume_id   = openstack_blockstorage_volume_v3.swarm_0_external.id

  depends_on = [
    openstack_compute_instance_v2.swarm_0,
    openstack_blockstorage_volume_v3.swarm_0_external
  ]
}

resource "openstack_compute_volume_attach_v2" "swarm_1_external" {
  instance_id = openstack_compute_instance_v2.swarm_1.id
  volume_id   = openstack_blockstorage_volume_v3.swarm_1_external.id

  depends_on = [
    openstack_compute_instance_v2.swarm_1,
    openstack_blockstorage_volume_v3.swarm_1_external
  ]
}

resource "openstack_compute_volume_attach_v2" "swarm_2_external" {
  instance_id = openstack_compute_instance_v2.swarm_2.id
  volume_id   = openstack_blockstorage_volume_v3.swarm_2_external.id

  depends_on = [
    openstack_compute_instance_v2.swarm_2,
    openstack_blockstorage_volume_v3.swarm_2_external
  ]
}

resource "openstack_compute_volume_attach_v2" "backup_external" {
  instance_id = openstack_compute_instance_v2.backup.id
  volume_id   = openstack_blockstorage_volume_v3.backup_external.id

  depends_on = [
    openstack_compute_instance_v2.backup,
    openstack_blockstorage_volume_v3.backup_external
  ]
}
