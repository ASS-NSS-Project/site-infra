terraform {
  backend "gcs" {
    bucket = "enc-ass-nss-project"
    prefix = "terraform/openstack/state"
  }

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "openstack" {
  cloud = "openstack"
}
