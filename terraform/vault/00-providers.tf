terraform {
  backend "gcs" {
    bucket = "site-infra"
    prefix = "terraform/vault/state"
  }

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "vault" {
  address = "https://vault.ass-nss.jkuzel02.online"
  token   = var.vault_root_token
}
