variable "proxmox_api_url" {
  type    = string
  default = "https://192.168.1.100:8006"
}

variable "proxmox_token_id" {
  type    = string
  // e.g. "terraform@pve!tf-token"
}

variable "proxmox_token_secret" {
  type    = string
  // your token secret
}

variable "node" {
  type    = string
  default = "pve"
}

variable "storage" {
  type    = string
  default = "local-lvm"
}

variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

variable "proxmox_host" {
  type = string
  // e.g. "192.168.1.100"
}
variable "proxmox_user" {
  type    = string
  default = "root"
}
variable "ssh_private_key_path" {
  type    = string
  default = "~/.ssh/id_rsa"
}
variable "iso_storage_path" {
  type    = string
  default = "/var/lib/vz/template/iso"
}
