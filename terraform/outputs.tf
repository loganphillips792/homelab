output "vm_id" {
  value = proxmox_virtual_environment_vm.docker.vm_id
}

output "ip" {
  value = split("/", var.ip_cidr)[0]
}

output "ssh" {
  value = "ssh ${var.username}@${split("/", var.ip_cidr)[0]}"
}

output "ansible" {
  value = "cd ../ansible && ansible-playbook site.yml -e ansible_host=${split("/", var.ip_cidr)[0]}"
}

output "ha_vm_id" {
  value = proxmox_virtual_environment_vm.homeassistant.vm_id
}

output "ha_mac_address" {
  value = var.ha_mac_address
}
