terraform {
  # Remote Backend for Terraform State - Stored in GCS Bucket 
  backend "gcs" {
    bucket = "k3s-cluster"
    prefix = "terraform/state"
  }

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0.0"
    }
  }
}

provider "openstack" {
  cloud = "openstack" # Reference, where to look for the creds in `clouds.yaml` file
}
