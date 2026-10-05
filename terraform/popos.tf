# Pop!_OS desktop VM, installed by hand from the installer ISO.
#
# RAM: all four VMs together (docker 20 + HA 4 + Kali 4 + Pop 4 = 32 GiB) exceed
# the host's 28 GiB. Run one at a time (see "Running one VM at a time" in the README).

resource "proxmox_download_file" "popos_iso" {
  node_name      = var.node
  datastore_id   = var.file_datastore
  content_type   = "iso"
  url            = var.popos_iso_url
  file_name      = basename(var.popos_iso_url)
  upload_timeout = 3600 # ~3.5 GB
}

resource "proxmox_virtual_environment_vm" "popos" {
  name      = "popos"
  node_name = var.node
  vm_id     = var.popos_vm_id
  on_boot   = true
  started   = true

  bios    = "ovmf"
  machine = "q35"

  # Secure Boot keys off so the installer boots without fuss
  efi_disk {
    datastore_id      = var.vm_datastore
    type              = "4m"
    pre_enrolled_keys = false
  }

  # The guest agent doesn't exist until the OS is installed, and with this on the
  # provider waits for it. After install: `sudo apt install qemu-guest-agent`,
  # then set enabled = true.
  agent {
    enabled = false
  }

  cpu {
    cores = var.popos_cores
    type  = "host"
  }

  memory {
    dedicated = var.popos_memory_mb
  }

  operating_system {
    type = "l26"
  }

  scsi_hardware = "virtio-scsi-single"

  # Empty disk; the installer partitions it
  disk {
    datastore_id = var.vm_datastore
    interface    = "scsi0"
    size         = var.popos_disk_gb
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  cdrom {
    file_id   = proxmox_download_file.popos_iso.id
    interface = "ide2"
  }

  # Empty disk falls through to the ISO on first boot; the installed OS boots after
  boot_order = ["scsi0", "ide2"]

  # Fixed MAC so a DHCP reservation on the router keeps the IP stable
  network_device {
    bridge      = var.network_bridge
    mac_address = var.popos_mac_address
  }
}
