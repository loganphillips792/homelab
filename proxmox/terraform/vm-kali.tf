resource "proxmox_vm_qemu" "kali" {
  depends_on   = [null_resource.bootstrap_isos]
  vmid         = 200
  name         = "kali-vm"
  target_node  = var.node

  # CPU (must go in its own block now)
  cpu {
    cores   = 2
    sockets = 1
  }

  # RAM remains top-level
  memory = 4096

  # Boot settings stay top-level
  scsihw   = "virtio-scsi-pci"
  bootdisk = "scsi0"

  # Disk #1: CD-ROM ISO installer
  disk {
    type = "cdrom"
    iso  = "local:iso/kali-linux-2025.2-installer-amd64.iso"
    slot = "ide2"
  }

  # Disk #2: actual VM disk
  disk {
    type    = "disk"
    storage = var.storage
    size    = "20G"
    slot    = "scsi0"
  }

  # Networking (id is now required)
  network {
    id      = 0
    model   = "virtio"
    bridge  = var.network_bridge
  }
}
/*
resource "proxmox_vm_qemu" "kali" {
  depends_on = [null_resource.bootstrap_isos]
  vmid     = 200
  name     = "kali-vm"
  target_node = var.node

  # ISO must already be uploaded to your 'local' storage
  iso     = "local:iso/kali-linux-2025.2-installer-amd64.iso"

  cores   = 2
  sockets = 1
  memory  = 4096
  scsihw  = "virtio-scsi-pci"
  bootdisk= "scsi0"

  # Disks
  disk {
    type    = "scsi"
    storage = var.storage
    size    = "20G"
  }

  # Network
  network {
    model  = "virtio"
    bridge = var.network_bridge
  }

  # Cloud-init (optional): would require a cloud-init ISO
  # ciuser = "kali"
  # cipassword = "ChangeMe123!"
}
*/