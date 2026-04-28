terraform {
  backend "gcs" {
    bucket = "site-infra"
    prefix = "terraform/grafana/state"
  }

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 3.0"
    }
  }
}

variable "grafana_username" {
  description = "Grafana admin username"
  type        = string
}

variable "grafana_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

provider "grafana" {
  url  = "https://grafana.nss.jkzl.eu"
  auth = "${var.grafana_username}:${var.grafana_password}"
}
