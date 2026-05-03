terraform {
  backend "gcs" {
    bucket = "enc-ass-nss-project"
    prefix = "terraform/vault/state"
  }

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

variable "vault_address" {
  default = "https://vault.nss.jkzl.eu"
}

provider "vault" {
  address = var.vault_address
  token   = var.vault_root_token
}
