# External Volumes (Block Storage) for Network Share Instances
resource "openstack_blockstorage_volume_v3" "network_share_0_external" {
  name        = "network-share-0-external-hdd"
  size        = 333
  volume_type = "du-ceph-muni1-hdd"
}

resource "openstack_blockstorage_volume_v3" "network_share_1_external" {
  name        = "network-share-1-external-hdd"
  size        = 333
  volume_type = "du-ceph-muni1-hdd"
}

resource "openstack_blockstorage_volume_v3" "network_share_2_external" {
  name        = "network-share-2-external-hdd"
  size        = 333
  volume_type = "du-ceph-muni1-hdd"
}

# Attachment of External Volumes to Network Share Instances
resource "openstack_compute_volume_attach_v2" "network_share_0_external" {
  instance_id = openstack_compute_instance_v2.network_share_0.id
  volume_id   = openstack_blockstorage_volume_v3.network_share_0_external.id

  depends_on = [
    openstack_compute_instance_v2.network_share_0,
    openstack_blockstorage_volume_v3.network_share_0_external
  ]
}

resource "openstack_compute_volume_attach_v2" "network_share_1_external" {
  instance_id = openstack_compute_instance_v2.network_share_1.id
  volume_id   = openstack_blockstorage_volume_v3.network_share_1_external.id

  depends_on = [
    openstack_compute_instance_v2.network_share_0,
    openstack_blockstorage_volume_v3.network_share_0_external
  ]
}

resource "openstack_compute_volume_attach_v2" "network_share_2_external" {
  instance_id = openstack_compute_instance_v2.network_share_2.id
  volume_id   = openstack_blockstorage_volume_v3.network_share_2_external.id

  depends_on = [
    openstack_compute_instance_v2.network_share_0,
    openstack_blockstorage_volume_v3.network_share_0_external
  ]
}
