resource "null_resource" "bootstrap_lxc_templates" {
  provisioner "remote-exec" {
    connection {
      host        = trimsuffix(trimprefix(var.proxmox_host, "https://"), ":8006")
      user        = var.proxmox_user
      # private_key = file(var.ssh_private_key_path) # ssh-agent will be used
    }
    inline = [
      # update the template list…
      "pveam update",
      # …and pull Ubuntu 22.04 LXC
      "pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst",
    ]
  }
}

resource "null_resource" "bootstrap_isos" {
  provisioner "remote-exec" {
    connection {
      host        = trimsuffix(trimprefix(var.proxmox_host, "https://"), ":8006")
      user        = var.proxmox_user
      # private_key = file(var.ssh_private_key_path) # ssh-agent will be used
    }
    inline = [
      # Ubuntu Server ISO
      "wget -N -P ${var.iso_storage_path} https://releases.ubuntu.com/22.04.4/ubuntu-22.04.4-live-server-amd64.iso",
      # Kali Linux ISO
      "wget -N -P ${var.iso_storage_path} https://cdimage.kali.org/kali-images/current/kali-linux-2025.2-installer-amd64.iso",
    ]
  }
}