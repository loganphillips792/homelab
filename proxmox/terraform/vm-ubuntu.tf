resource "proxmox_vm_qemu" "ubuntu" {
  depends_on   = [null_resource.bootstrap_isos]
  vmid         = 201
  name         = "ubuntu-vm"
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
    iso  = "local:iso/ubuntu-22.04.4-live-server-amd64.iso"
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
resource "proxmox_vm_qemu" "ubuntu" {
  depends_on = [null_resource.bootstrap_isos]
  vmid     = 201
  name     = "ubuntu-vm"
  target_node  = var.node

  iso      = "local:iso/ubuntu-22.04.4-live-server-amd64.iso"

  cores    = 2
  sockets  = 1
  memory   = 4096
  scsihw   = "virtio-scsi-single"
  bootdisk = "scsi0"

  disk {
    type    = "scsi"
    storage = var.storage
    size    = "30G"
  }

  network {
    model  = "virtio"
    bridge = var.network_bridge
  }

  # Uncomment & set up cloud-init if you want unattended install
  # ciuser      = "ubuntu"
  # cipassword  = "ChangeMe123!"
  # searchdomain= "local"
}
*/