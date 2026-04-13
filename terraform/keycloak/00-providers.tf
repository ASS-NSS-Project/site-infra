terraform {
  backend "gcs" {
    bucket = "k3s-cluster"
    prefix = "terraform/keycloak/state"
  }
  
  required_providers {
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "~> 4.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

variable "keycloak_username" {
  description = "Keycloak admin username"
  type        = string
}

variable "keycloak_password" {
  description = "Keycloak admin password"
  type        = string
  sensitive   = true
}

provider "keycloak" {
  client_id = "admin-cli"
  username  = var.keycloak_username
  password  = var.keycloak_password
  url       = "https://keycloak.ass-nss.jkuzel02.online"
}

variable "vault_root_token" {
  description = "Vault root token"
  type        = string
  sensitive   = true
}

provider "vault" {
  address = "https://vault.ass-nss.jkuzel02.online"
  token   = var.vault_root_token
}
