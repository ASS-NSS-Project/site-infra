terraform {
  backend "gcs" {
    bucket = "k3s-cluster"
    prefix = "terraform/infra/state"
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
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "openstack" { cloud = "openstack" }

provider "google" {
  project = "enc-ass-nss-project"
  region  = "europe-west1"
}
