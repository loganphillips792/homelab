resource "proxmox_download_file" "ubuntu_image" {
  node_name    = var.node
  datastore_id = var.file_datastore
  content_type = "iso"
  url          = var.ubuntu_image_url
  file_name    = "ubuntu-noble-cloudimg-amd64.img"
}

# Creates the user + SSH key and installs qemu-guest-agent on first boot
resource "proxmox_virtual_environment_file" "cloud_init" {
  node_name    = var.node
  datastore_id = var.file_datastore
  content_type = "snippets"

  source_raw {
    file_name = "${var.vm_name}-user-data.yaml"
    data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
      hostname = var.vm_name
      username = var.username
      ssh_key  = trimspace(file(pathexpand(var.ssh_public_key_file)))
    })
  }
}

resource "proxmox_virtual_environment_vm" "docker" {
  name      = var.vm_name
  node_name = var.node
  vm_id     = var.vm_id
  on_boot   = true
  started   = true

  agent {
    enabled = true
  }

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory_mb
  }

  operating_system {
    type = "l26"
  }

  scsi_hardware = "virtio-scsi-single"

  disk {
    datastore_id = var.vm_datastore
    file_id      = proxmox_download_file.ubuntu_image.id
    interface    = "scsi0"
    size         = var.disk_gb
    discard      = "on"
    iothread     = true
  }

  network_device {
    bridge = var.network_bridge
  }

  # Cloud images expect a serial console
  serial_device {}

  initialization {
    datastore_id = var.vm_datastore

    ip_config {
      ipv4 {
        address = var.ip_cidr
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_data_file_id = proxmox_virtual_environment_file.cloud_init.id
  }
}
