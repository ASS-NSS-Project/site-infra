terraform {
  backend "gcs" {
    bucket = "enc-ass-nss-project"
    prefix = "terraform/du-cesnet/state"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  access_key = var.s3_access_key
  secret_key = var.s3_secret_key
  region     = "us-east-1"

  endpoints {
    s3 = "https://s3.cl4.du.cesnet.cz"
  }

  # Metacentrum S3 is not AWS — skip credential/region validation
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true

  s3_use_path_style = true
}

variable "s3_access_key" {
  description = "Metacentrum S3 access key (from https://access.du.cesnet.cz)"
  type        = string
  sensitive   = true
}

variable "s3_secret_key" {
  description = "Metacentrum S3 secret key"
  type        = string
  sensitive   = true
}
