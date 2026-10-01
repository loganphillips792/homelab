# Home Assistant OS VM.
#
# RAM budget: docker-vm (20 GiB) + this VM (4 GiB) = 24 of the host's 28 GiB,
# leaving ~4 GiB for Proxmox (see "VM sizing" in the README).

locals {
  proxmox_host = regex("//([^:/]+)", var.proxmox_endpoint)[0]
  haos_file    = "haos_ova-${var.haos_version}.img"
}

# HAOS only ships as .qcow2.xz and proxmox_download_file can't decompress xz,
# so fetch and unpack it on the host over SSH. Saved as .img so it can be used
# as a "local:iso/..." disk source (same trick as the Ubuntu cloud image).
resource "terraform_data" "haos_image" {
  triggers_replace = var.haos_version

  connection {
    type  = "ssh"
    host  = local.proxmox_host
    user  = "root"
    agent = true
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "cd /var/lib/vz/template/iso",
      "if [ ! -f ${local.haos_file} ]; then wget -q -O /tmp/haos.qcow2.xz https://github.com/home-assistant/operating-system/releases/download/${var.haos_version}/haos_ova-${var.haos_version}.qcow2.xz && xz -d -f /tmp/haos.qcow2.xz && mv /tmp/haos.qcow2 ${local.haos_file}; fi",
    ]
  }
}

resource "proxmox_virtual_environment_vm" "homeassistant" {
  depends_on = [terraform_data.haos_image]

  name      = "homeassistant"
  node_name = var.node
  vm_id     = var.ha_vm_id
  on_boot   = true
  started   = true

  bios    = "ovmf"
  machine = "q35"

  # HAOS isn't Secure Boot signed, so pre-enrolled keys would block boot
  efi_disk {
    datastore_id      = var.vm_datastore
    type              = "4m"
    pre_enrolled_keys = false
  }

  # HAOS ships qemu-guest-agent, so Proxmox can show the VM's IP
  agent {
    enabled = true
  }

  cpu {
    cores = var.ha_cores
    type  = "host"
  }

  memory {
    dedicated = var.ha_memory_mb
  }

  operating_system {
    type = "l26"
  }

  scsi_hardware = "virtio-scsi-single"

  disk {
    datastore_id = var.vm_datastore
    file_id      = "${var.file_datastore}:iso/${local.haos_file}"
    interface    = "scsi0"
    size         = var.ha_disk_gb
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  # Fixed MAC so a DHCP reservation on the router keeps the IP stable.
  # HAOS ignores cloud-init, so there's no initialization block.
  network_device {
    bridge      = var.network_bridge
    mac_address = var.ha_mac_address
  }
}
