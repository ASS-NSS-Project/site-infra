# The Instances
resource "openstack_compute_instance_v2" "site_a" {
  name            = "site_a"
  image_name      = "debian-13-x86_64"
  flavor_name     = "e1.4core-16ram"
  key_pair        = "jkuzel"
  security_groups = ["default", "ssh"]
  network {
    name = "internal-ipv4-general-private"
  }
}

resource "openstack_compute_instance_v2" "site_b" {
  name            = "site_b"
  image_name      = "debian-13-x86_64"
  flavor_name     = "e1.4core-16ram"
  key_pair        = "jkuzel"
  security_groups = ["default", "ssh"]
  network {
    name = "internal-ipv4-general-private"
  }
}

resource "openstack_compute_instance_v2" "proxy" {
  name            = "proxy"
  image_name      = "debian-13-x86_64"
  flavor_name     = "e1.small"
  key_pair        = "jkuzel"
  security_groups = ["default", "ssh"]
  network {
    name = "internal-ipv4-general-private"
  }
}
