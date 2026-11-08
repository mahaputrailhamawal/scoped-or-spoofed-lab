terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Disarankan naik ke v5
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0" # Dibutuhkan oleh data "tls_certificate" di iam.tf
    }
  }
}

provider "aws" {
  region  = var.aws_region
  # Menggunakan profil CLI khusus lab. Tidak ada kredensial statis di file ini.
  profile = var.aws_profile 
}

# ---------------------------------------------------------
# VARIABEL
# ---------------------------------------------------------

variable "aws_region" {
  description = "Region to deploy the lab into"
  type        = string
  default     = "ap-southeast-3"
}

variable "aws_profile" {
  description = "Named AWS CLI profile for the dedicated lab account"
  type        = string
  default     = "default" # Ubah default agar tidak sengaja menembak profil 'default'
}

variable "name_prefix" {
  description = "Prefix applied to all resource names"
  type        = string
  default     = "scoped-or-spoofed"
}

variable "github_org" {
  description = "GitHub org containing both legit-repo and spoof-repo, e.g. Codexus-org"
  type        = string
  default     = "Codexus-org@178847363"
}

variable "github_repo" {
  description = "The GitHub repo name this role is actually meant for (e.g., legit-repo)"
  type        = string
  default     = "legit-repo@1443096881" # Menggantikan variabel legit_repo
}

variable "legit_branch" {
  description = "The branch the legit workflow runs on, e.g. main"
  type        = string
  default     = "main"
}

# ---------------------------------------------------------
# DATA & OUTPUTS
# ---------------------------------------------------------

# Wajib ada karena dipanggil di iam.tf
data "aws_caller_identity" "current" {}

output "aws_region" {
  value = var.aws_region
}
