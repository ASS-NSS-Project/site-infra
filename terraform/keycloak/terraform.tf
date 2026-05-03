terraform {
  backend "gcs" {
    bucket = "enc-ass-nss-project"
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

variable "rag_admin_members" {
  description = "Gmail addresses for rag_admin — full Keycloak realm admin, Grafana Admin, Vault admin, RabbitMQ admin, RAG app admin"
  type        = list(string)
  default     = []
}

variable "rag_curator_members" {
  description = "Gmail addresses for rag_curator — source/pipeline/incident management"
  type        = list(string)
  default     = []
}

variable "rag_analyst_members" {
  description = "Gmail addresses for rag_analyst — experiments and queries"
  type        = list(string)
  default     = []
}

variable "rag_user_members" {
  description = "Gmail addresses for rag_user — query only"
  type        = list(string)
  default     = []
}

provider "vault" {
  address = "https://vault.nss.jkzl.eu"
  token   = var.vault_root_token
}
