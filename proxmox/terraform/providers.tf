terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.1-rc9"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "proxmox" {
  # pm_api_url           = "${var.proxmox_host}/api2/json"
  pm_api_url           = "https://10.0.0.98:8006/api2/json"
  pm_api_token_id      = var.proxmox_token_id
  pm_api_token_secret  = var.proxmox_token_secret
  pm_tls_insecure      = true          # ← use this instead of pm_tls_self_signed  [oai_citation:0‡Terraform Registry](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs?utm_source=chatgpt.com)
}

provider "null" {}