terraform {
  backend "gcs" {
    bucket = "site-infra"
    prefix = "terraform/cloudflare/state"
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS edit permissions for jkzl.eu"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for jkzl.eu (Dashboard → jkzl.eu → Zone ID)"
  type        = string
}

variable "openstack_lb_ip" {
  description = "Cluster ingress LB floating IP — written automatically by terraform/openstack into ingress.auto.tfvars"
  type        = string
}
