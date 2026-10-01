variable "proxmox_endpoint" {
  type    = string
  default = "https://192.168.1.98:8006/"
}

variable "proxmox_api_token" {
  type        = string
  sensitive   = true
  description = "Format: user@realm!token-id=secret, e.g. root@pam!terraform=xxxxxxxx-..."
}

variable "node" {
  type    = string
  default = "pve"
}

# Where the VM disk lives
variable "vm_datastore" {
  type    = string
  default = "local-lvm"
}

# Where the cloud image and cloud-init snippet are stored. Needs the "iso" and
# "snippets" content types enabled (see README).
variable "file_datastore" {
  type    = string
  default = "local"
}

variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

variable "ubuntu_image_url" {
  type    = string
  default = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "vm_id" {
  type    = number
  default = 150
}

variable "vm_name" {
  type    = string
  default = "docker-vm"
}

variable "cores" {
  type    = number
  default = 8
}

# The host has 28 GiB. 20 GiB leaves ~8 GiB for Proxmox -- never run two VMs this
# size at once or the host hard-freezes (see "VM sizing" in the README).
variable "memory_mb" {
  type    = number
  default = 20480
}

variable "disk_gb" {
  type    = number
  default = 256
}

variable "ip_cidr" {
  type    = string
  default = "192.168.1.150/24"
}

variable "gateway" {
  type    = string
  default = "192.168.1.1"
}

variable "dns_servers" {
  type    = list(string)
  default = ["1.1.1.1", "9.9.9.9"]
}

variable "username" {
  type    = string
  default = "logan"
}

variable "ssh_public_key_file" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

# --- Home Assistant VM (homeassistant.tf) ---

# Only used for fresh installs; HA updates itself from its UI afterwards.
# Changing this re-downloads the image and recreates the VM.
variable "haos_version" {
  type    = string
  default = "18.3"
}

variable "ha_vm_id" {
  type    = number
  default = 160
}

variable "ha_cores" {
  type    = number
  default = 2
}

variable "ha_memory_mb" {
  type    = number
  default = 4096
}

variable "ha_disk_gb" {
  type    = number
  default = 32
}

# Reserve an IP for this MAC on the router
variable "ha_mac_address" {
  type    = string
  default = "BC:24:11:48:41:01"
}

# Kali and Pop!_OS desktop VMs. Changing an ISO URL re-downloads it.
variable "kali_iso_url" {
  type    = string
  default = "https://cdimage.kali.org/kali-2026.2/kali-linux-2026.2-installer-amd64.iso"
}

variable "kali_vm_id" {
  type    = number
  default = 170
}

variable "kali_cores" {
  type    = number
  default = 4
}

variable "kali_memory_mb" {
  type    = number
  default = 4096
}

variable "kali_disk_gb" {
  type    = number
  default = 64
}

variable "kali_mac_address" {
  type    = string
  default = "BC:24:11:4B:41:01"
}

# Latest build: curl https://api.pop-os.org/builds/24.04/generic
variable "popos_iso_url" {
  type    = string
  default = "https://iso.pop-os.org/24.04/amd64/generic/28/pop-os_24.04_amd64_generic_28.iso"
}

variable "popos_vm_id" {
  type    = number
  default = 180
}

variable "popos_cores" {
  type    = number
  default = 4
}

variable "popos_memory_mb" {
  type    = number
  default = 4096
}

variable "popos_disk_gb" {
  type    = number
  default = 64
}

variable "popos_mac_address" {
  type    = string
  default = "BC:24:11:50:4F:01"
}
