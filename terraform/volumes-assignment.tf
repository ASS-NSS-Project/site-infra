# Additional Volumes for Site A & Site (B Workers)
resource "openstack_blockstorage_volume_v3" "site_a_extra_drive" {
  name        = "site-a-data"
  size        = 200
  volume_type = "du-ceph-muni1-hdd"
}

resource "openstack_blockstorage_volume_v3" "site_b_extra_drive" {
  name        = "site-b-data"
  size        = 200
  volume_type = "du-ceph-muni1-hdd"
}

resource "openstack_compute_volume_attach_v2" "attach_site_a_extra_drive" {
  instance_id = openstack_compute_instance_v2.site_a.id
  volume_id   = openstack_blockstorage_volume_v3.site_a_extra_drive.id
}

resource "openstack_compute_volume_attach_v2" "attach_site_b_extra_drive" {
  instance_id = openstack_compute_instance_v2.site_b.id
  volume_id   = openstack_blockstorage_volume_v3.site_b_extra_drive.id
}
