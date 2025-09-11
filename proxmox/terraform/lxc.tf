resource "proxmox_lxc" "ubuntu01" {
  depends_on = [null_resource.bootstrap_lxc_templates]
  target_node = var.node
  count     = 2                                // spin up 2 containers
  vmid      = 100 + count.index                // 100, 101
  hostname  = "ubuntu-lxc-${count.index + 1}"
  ostemplate= "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  cores     = 2
  memory    = 2048
  rootfs {
    storage = var.storage
    size    = "4G"
  }
  network {
    name = "eth0"
    bridge = var.network_bridge
    ip      = "dhcp"
    gw      = "10.0.0.1"
  }
  features {
    nesting = true
  }
  unprivileged = true
}
resource "proxmox_lxc" "grafana" {
  depends_on = [null_resource.bootstrap_lxc_templates]
  target_node = var.node
  start = true
  password  = "password123"
  ssh_public_keys = file("/Users/logan/.ssh/id_rsa_terraform.pub")
  vmid      = 102
  hostname  = "grafana"
  ostemplate= "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  cores     = 2
  memory    = 2048
  rootfs {
    storage = var.storage
    size    = "8G"
  }
  network {
    name    = "eth0"
    bridge  = var.network_bridge
    ip      = "10.0.0.47/24"
    gw      = "10.0.0.1"
  }
  unprivileged = true

# persistent data directory for Grafana
/* this was causing a context timeout error 
  unprivileged = true
  provisioner "local-exec" {
    command = "mkdir -p /var/lib/grafana-data"
  }

  mountpoint {
    key     = "0"
    slot    = 0
    storage = "local"
    mp      = "/var/lib/grafana-data,mp=/usr/share/grafana/data"
  }
  */
}

resource "proxmox_lxc" "homepage" {
  depends_on = [null_resource.bootstrap_lxc_templates]
  target_node = var.node
  start = true
  password  = "password123"
  ssh_public_keys = file("/Users/logan/.ssh/id_rsa_terraform.pub")
  vmid      = 103
  hostname  = "homepage"
  ostemplate= "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  cores     = 2
  memory    = 2048
  rootfs {
    storage = var.storage
    size    = "8G"
  }
  network {
    name    = "eth0"
    bridge  = var.network_bridge
    ip      = "10.0.0.48/24"
    gw      = "10.0.0.1"
  }
  unprivileged = true

  provisioner "local-exec" {
    command = "while ! nc -w 1 -z 10.0.0.48 22; do sleep 1; done"
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y python3"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/id_rsa_terraform")
      host        = "10.0.0.48"
    }
  }
}

resource "proxmox_lxc" "pihole" {
  depends_on = [null_resource.bootstrap_lxc_templates]
  target_node = var.node
  start = true
  password  = "password123"
  ssh_public_keys = file("/Users/logan/.ssh/id_rsa_terraform.pub")
  vmid      = 104
  hostname  = "pihole"
  ostemplate= "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  cores     = 2
  memory    = 2048
  rootfs {
    storage = var.storage
    size    = "8G"
  }
  network {
    name    = "eth0"
    bridge  = var.network_bridge
    ip      = "10.0.0.49/24"
    gw      = "10.0.0.1"
  }
  unprivileged = true

  provisioner "local-exec" {
    command = "while ! nc -w 1 -z 10.0.0.49 22; do sleep 1; done"
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y python3"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/id_rsa_terraform")
      host        = "10.0.0.49"
    }
  }
}

resource "proxmox_lxc" "uptime_kuma" {
  depends_on = [null_resource.bootstrap_lxc_templates]
  target_node = var.node
  start = true
  unprivileged = true
  # features = "nesting=1" # Removed as it requires privileged container or root@pam
  password  = "password123"
  ssh_public_keys = file("/Users/logan/.ssh/id_rsa_terraform.pub")
  vmid      = 105
  hostname  = "uptime-kuma"
  ostemplate= "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  cores     = 2
  memory    = 2048
  rootfs {
    storage = var.storage
    size    = "8G"
  }
  network {
    name    = "eth0"
    bridge  = var.network_bridge
    ip      = "10.0.0.50/24"
    gw      = "10.0.0.1"
  }

  provisioner "local-exec" {
    command = "while ! nc -w 1 -z 10.0.0.50 22; do sleep 1; done"
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y python3"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/id_rsa_terraform")
      host        = "10.0.0.50"
    }
  }
}

resource "proxmox_lxc" "n8n" {
  depends_on = [null_resource.bootstrap_lxc_templates]
  target_node = var.node
  start = true
  password  = "password123"
  ssh_public_keys = file("/Users/logan/.ssh/id_rsa_terraform.pub")
  vmid      = 106
  hostname  = "n8n"
  ostemplate= "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  cores     = 2
  memory    = 2048
  rootfs {
    storage = var.storage
    size    = "10G"
  }
  network {
    name    = "eth0"
    bridge  = var.network_bridge
    ip      = "10.0.0.51/24"
    gw      = "10.0.0.1"
  }
  unprivileged = true

  provisioner "local-exec" {
    command = "while ! nc -w 1 -z 10.0.0.51 22; do sleep 1; done"
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y python3"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/id_rsa_terraform")
      host        = "10.0.0.51"
    }
  }
}

resource "proxmox_lxc" "kafka" {
  depends_on = [null_resource.bootstrap_lxc_templates]
  target_node = var.node
  start = true
  password  = "password123"
  ssh_public_keys = file("/Users/logan/.ssh/id_rsa_terraform.pub")
  vmid      = 107
  hostname  = "kafka"
  ostemplate= "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  cores     = 2
  memory    = 2048
  rootfs {
    storage = var.storage
    size    = "8G"
  }
  network {
    name    = "eth0"
    bridge  = var.network_bridge
    ip      = "10.0.0.52/24"
    gw      = "10.0.0.1"
  }
  features {
    nesting = true
  }
  unprivileged = true

  provisioner "local-exec" {
    command = "while ! nc -w 1 -z 10.0.0.52 22; do sleep 1; done"
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y python3"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/id_rsa_terraform")
      host        = "10.0.0.52"
    }
  }
}

resource "proxmox_lxc" "jellyfin" {
      depends_on = [null_resource.bootstrap_lxc_templates]
      target_node = var.node
      start = true
      password  = "password123"
      ssh_public_keys = file("/Users/logan/.ssh/id_rsa_terraform.pub")
      vmid      = 108
      hostname  = "jellyfin"
      ostemplate= "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
      cores     = 2
      memory    = 2048
      rootfs {
        storage = var.storage
        size    = "8G"
      }
      network {
        name    = "eth0"
        bridge  = var.network_bridge
        ip      = "10.0.0.53/24"
        gw      = "10.0.0.1"
      }
      
      # https://www.reddit.com/r/Proxmox/comments/128fy9x/docker_in_privileged_vs_unprivileged_lxcs/
      features {
        nesting = true
      }
      unprivileged = true
    
      provisioner "local-exec" {
        command = "while ! nc -w 1 -z 10.0.0.53 22; do sleep 1; done"
      }
    
      provisioner "remote-exec" {
        inline = [
          "apt-get update",
          "apt-get install -y python3"
        ]
    
        connection {
          type        = "ssh"
          user        = "root"
          private_key = file("~/.ssh/id_rsa_terraform")
          host        = "10.0.0.53"
        }
      }
}

resource "proxmox_lxc" "tailscale" {
  depends_on = [null_resource.bootstrap_lxc_templates]
  target_node = var.node
  start = true
  password  = "password123"
  ssh_public_keys = file("/Users/logan/.ssh/id_rsa_terraform.pub")
  vmid      = 109
  hostname  = "tailscale"
  ostemplate= "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  cores     = 2
  memory    = 2048
  rootfs {
    storage = var.storage
    size    = "8G"
  }
  network {
    name    = "eth0"
    bridge  = var.network_bridge
    ip      = "10.0.0.54/24"
    gw      = "10.0.0.1"
  }
  features {
    nesting = true
  }
  unprivileged = true

  provisioner "local-exec" {
    command = "while ! nc -w 1 -z 10.0.0.54 22; do sleep 1; done"
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y python3"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/id_rsa_terraform")
      host        = "10.0.0.54"
    }
  }
}