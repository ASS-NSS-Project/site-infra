terraform {
  backend "gcs" {
    bucket = "site-infra"
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
  url       = "https://keycloak.nss.jkzl.eu"
}

variable "vault_root_token" {
  description = "Vault root token"
  type        = string
  sensitive   = true
}

# Gmail addresses of users to pre-create in Keycloak and assign to each group.
# Users are created before their first login — Keycloak links their Google identity on first sign-in.

variable "admin_members" {
  description = "Gmail addresses to pre-create and add to the admin group"
  type        = list(string)
  default     = []
}

variable "curator_members" {
  description = "Gmail addresses to pre-create and add to the curator group"
  type        = list(string)
  default     = []
}

variable "analytic_members" {
  description = "Gmail addresses to pre-create and add to the analytic group"
  type        = list(string)
  default     = []
}

variable "user_members" {
  description = "Gmail addresses to pre-create and add to the user group"
  type        = list(string)
  default     = []
}

provider "vault" {
  address = "https://vault.nss.jkzl.eu"
  token   = var.vault_root_token
}
