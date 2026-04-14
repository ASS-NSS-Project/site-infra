terraform {
  backend "gcs" {
    bucket = "site-infra"
    prefix = "terraform/gcp/state"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "google" {
  project = "enc-ass-nss-project"
  region  = "europe-west1"
}
