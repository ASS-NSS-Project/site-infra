# --- Docker Swarm Manager Instances ---

resource "openstack_compute_instance_v2" "swarm_manager_0" {
  name        = "swarm-manager-0"
  image_name  = "debian-13-x86_64"
  flavor_name = "e1.tiny" # 2 GiB RAM, 2 vCPUs
  key_pair    = "jkuzel"

  security_groups = [
    "external",
    "storage-internal",
    "docker-swarm-mgmt"
  ]

  network {
    name = "internal-ipv4-general-private"
  }

  depends_on = [
    openstack_networking_secgroup_v2.external,
    openstack_networking_secgroup_v2.storage_internal,
    openstack_networking_secgroup_v2.docker_swarm_mgmt
  ]
}

resource "openstack_compute_instance_v2" "swarm_manager_1" {
  name        = "swarm-manager-1"
  image_name  = "debian-13-x86_64"
  flavor_name = "e1.tiny" # 2 GiB RAM, 2 vCPUs
  key_pair    = "jkuzel"

  security_groups = [
    "external",
    "storage-internal",
    "docker-swarm-mgmt"
  ]

  network {
    name = "internal-ipv4-general-private"
  }

  depends_on = [
    openstack_networking_secgroup_v2.external,
    openstack_networking_secgroup_v2.storage_internal,
    openstack_networking_secgroup_v2.docker_swarm_mgmt
  ]
}

resource "openstack_compute_instance_v2" "swarm_manager_2" {
  name        = "swarm-manager-2"
  image_name  = "debian-13-x86_64"
  flavor_name = "e1.tiny" # 2 GiB RAM, 2 vCPUs
  key_pair    = "jkuzel"

  security_groups = [
    "external",
    "storage-internal",
    "docker-swarm-mgmt"
  ]

  network {
    name = "internal-ipv4-general-private"
  }

  depends_on = [
    openstack_networking_secgroup_v2.external,
    openstack_networking_secgroup_v2.storage_internal,
    openstack_networking_secgroup_v2.docker_swarm_mgmt
  ]
}

# --- Docker Swarm Worker Instances ---

resource "openstack_compute_instance_v2" "swarm_worker_0" {
  name        = "swarm-worker-0"
  image_name  = "debian-13-x86_64"
  flavor_name = "e1.4core-16ram" # 16 GiB RAM, 4 vCPUs
  key_pair    = "jkuzel"

  security_groups = [
    "external",
    "storage-internal",
    "docker-swarm-mgmt"
  ]

  network {
    name = "internal-ipv4-general-private"
  }

  depends_on = [
    openstack_networking_secgroup_v2.external,
    openstack_networking_secgroup_v2.storage_internal,
    openstack_networking_secgroup_v2.docker_swarm_mgmt
  ]
}

resource "openstack_compute_instance_v2" "swarm_worker_1" {
  name        = "swarm-worker-1"
  image_name  = "debian-13-x86_64"
  flavor_name = "e1.4core-16ram" # 16 GiB RAM, 4 vCPUs
  key_pair    = "jkuzel"

  security_groups = [
    "external",
    "storage-internal",
    "docker-swarm-mgmt"
  ]

  network {
    name = "internal-ipv4-general-private"
  }

  depends_on = [
    openstack_networking_secgroup_v2.external,
    openstack_networking_secgroup_v2.storage_internal,
    openstack_networking_secgroup_v2.docker_swarm_mgmt
  ]
}

# --- Network Share Instances ---

resource "openstack_compute_instance_v2" "network_share_0" {
  name        = "network-share-0"
  image_name  = "debian-13-x86_64"
  flavor_name = "e1.small" # 4 GiB RAM, 2 vCPUs
  key_pair    = "jkuzel"

  security_groups = [
    "external",
    "storage-internal"
  ]

  network {
    name = "internal-ipv4-general-private"
  }

  depends_on = [
    openstack_networking_secgroup_v2.external,
    openstack_networking_secgroup_v2.storage_internal
  ]
}

resource "openstack_compute_instance_v2" "network_share_1" {
  name        = "network-share-1"
  image_name  = "debian-13-x86_64"
  flavor_name = "e1.small" # 4 GiB RAM, 2 vCPUs
  key_pair    = "jkuzel"

  security_groups = [
    "external",
    "storage-internal"
  ]

  network {
    name = "internal-ipv4-general-private"
  }

  depends_on = [
    openstack_networking_secgroup_v2.external,
    openstack_networking_secgroup_v2.storage_internal
  ]
}

resource "openstack_compute_instance_v2" "network_share_2" {
  name        = "network-share-2"
  image_name  = "debian-13-x86_64"
  flavor_name = "e1.small" # 4 GiB RAM, 2 vCPUs
  key_pair    = "jkuzel"

  security_groups = [
    "external",
    "storage-internal"
  ]

  network {
    name = "internal-ipv4-general-private"
  }

  depends_on = [
    openstack_networking_secgroup_v2.external,
    openstack_networking_secgroup_v2.storage_internal
  ]
}
