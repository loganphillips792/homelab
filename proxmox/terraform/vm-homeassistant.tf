resource "null_resource" "download_haos" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "remote-exec" {
    inline = [
      "if [ ! -d \"${var.iso_storage_path}\" ]; then echo \"Creating storage directory: ${var.iso_storage_path}\"; mkdir -p \"${var.iso_storage_path}\" || exit 1; fi",
      "echo \"Downloading HAOS image...\"; if ! wget https://github.com/home-assistant/operating-system/releases/download/16.0/haos_ova-16.0.qcow2.xz -O \"${var.iso_storage_path}/haos_ova-16.0.qcow2.xz\"; then echo \"Failed to download HAOS image\"; exit 1; fi",
      "echo \"Extracting image...\"; if ! xz -d \"${var.iso_storage_path}/haos_ova-16.0.qcow2.xz\"; then echo \"Failed to extract HAOS image\"; exit 1; fi",
      "echo \"HAOS image downloaded and extracted successfully\""
    ]
    connection {
      type        = "ssh"
      user        = var.proxmox_user
      private_key = file(var.ssh_private_key_path)
      host        = var.proxmox_host
    }
  }
}

resource "proxmox_vm_qemu" "homeassistant" {
  depends_on   = [null_resource.bootstrap_isos, null_resource.download_haos]
  vmid         = 202
  name         = "homeassistant"
  target_node  = var.node
  bios         = "ovmf"  # Required for EFI
  onboot       = true

  # CPU
  cpu {
    cores   = 2
    sockets = 1
    type    = "host"
  }

  # Memory
  memory = 2048

  # EFI Storage
  efidisk {
    storage = var.storage
  }

  # Boot settings
  scsihw   = "virtio-scsi-pci"
  bootdisk = "scsi0"

  # Disk for Home Assistant OS
  disk {
    type    = "disk"
    storage = var.storage
    size    = "32G"
    slot    = "scsi0"
    discard = true
  }

  # Networking
  network {
    id      = 0
    model   = "virtio"
    bridge  = var.network_bridge
  }

}