# homelab

https://www.tiktok.com/@sheluuvsxavier/video/7523501146523077943?_r=1&_t=ZP-8xqbBct8xMk

https://github.com/azpha/homelab






brew install multipass
multipass launch --name iso-builder --memory 4G --disk 20G debian:bookworm
multipass mount "$(pwd)" iso-builder:/mnt/host

```
multipass exec iso-builder -- sudo -- bash -eux <<'EOF'
  # 1) Add the Proxmox repo (Debian Bookworm repo works)
  echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" \
       > /etc/apt/sources.list.d/pve.list
  wget -qO - http://download.proxmox.com/debian/proxmox-release-bookworm.gpg \
       | apt-key add -
  apt update

  # 2) Install the assistant and xorriso
  apt install -y proxmox-auto-install-assistant xorriso

  # 3) Build a new ISO with your answer.toml embedded
  proxmox-auto-install-assistant prepare-iso \
    /mnt/host/pve-enterprise-8.4.iso \
    --fetch-from iso \
    --answer-file /Users/logan/repos/homelab/unattended-install.toml

  # 4) Copy the generated ISO back to your Mac’s shared folder
  cp /var/tmp/auto-installer-*.iso /mnt/host/proxmox-autoinstall.iso
EOF
```


default username for lxc containers: root


http://10.0.0.47:3000 - Grafana
http://10.0.0.48:3000 - homepage
http://10.0.0.49 - Pihole
- Home assistant
http://10.0.0.50:3001 - Uptime Kuma
- Live Auction

http://10.0.0.51:5678/setup - N8N
http://10.0.0.52 - kafka
http://10.0.0.53:8096/web - Jellyfin
10.0.0.54 - Tailscale


How to set up SSH if going from fresh install ?

# Proxmox

Download Proxmox ISO image: https://www.proxmox.com/en/proxmox-virtual-environment/get-started
    1. Boot from USB
        1. Use Balena Etcher to flask ISO image to USB Drive
        2. Turn off computer
        3. Insert USB
        4. Turn on Computer
        5. Press F7 to get into Bios
        6. Select USB Drive as the boot device
    2. Go through install process (Note: Have ethernet cable already plugged in)
        1. Management Interface: enpls0
        2. Hostname (FQDN): pve.frontierlocal.net Not Needed (https://www.reddit.com/r/Proxmox/comments/12rnq6l/a_quick_question_about_hostname_fqdn_during/)
        3. IP Address (CIDR): 192.168.254.177/24
        4. Gateway: 192.168.254.254 (IP of router)
        5. DNS Server: 192.168.254.254 (IP of router)
    3. On another computer go to https://192.168.254.177:8006/
    4. Install Ubunu image so that we can use it for LXE containers
        1. Open console in Proxmox host
        2. pveam update
        3. pveam available
        4. pveam update
        5. pveam download local ubuntu-23.10-standard_23.10-1_amd64.tar.zst
    5. Download Kali Linux image
    6. Download Pop OS image


pct status 109

pct exec 109 ip a

journalctl -u pve-lxc@109


# Terraform

- On host machine (mac os)
  - Install Teraform
      - brew tap hashicorp/tap
      - brew install hashicorp/tap/terraform


> Datacenter > Permissions > API Tokens > Create new api token (Privlege Seperation should be unchecked)


- cd homelab/proxmox/terraform
- terraform init
- terraform plan -out=tfplan
- terraform apply tfplan

- if problems with ssh
    - eval "$(ssh-agent -s)"
    - ssh-add ~/.ssh/id_rsa
    - then run apply again



terraform init -upgrade

terraform destroy

terraform state list

# Ansible

Activate virtual env python

python3 -m pip install ansible

Then you can run: ansible-playbook

brew install sshpass - When using password-based authentication with Ansible over SSH, the sshpass utility must be installed on the machine that is running Ansible (the control node)



ansible-playbook -i proxmox/ansible/grafana/inventory/hosts proxmox/ansible/grafana/linux_setup_grafana.yml -vvv

ansible -i proxmox/ansible/grafana/inventory/hosts grafana -m service -a "name=grafana-server state=started"

ansible -i proxmox/ansible/grafana/inventory/hosts grafana -m shell -a "journalctl -u grafana-server.service -n 50"



ansible-playbook -i proxmox/ansible/homepage/inventory/hosts proxmox/ansible/homepage/linux_setup_homepage.yml -vvv


ansible -i proxmox/ansible/homepage/inventory/hosts homepage -m shell -a 'cat /opt/homepage/package.json'


ansible -i proxmox/ansible/homepage/inventory/hosts homepage -m shell -a 'systemctl status homepage.service'


ansible -i proxmox/ansible/homepage/inventory/hosts homepage -m shell -a 'which pnpm'

ansible-playbook linux_setup_pihole.yml -vvv 



journalctl -u pihole-FTL -n 50

pihole -d


Run all playbooks: ansible-playbook -i proxmox/ansible/inventory.yml proxmox/ansible/run_all.yml


# Pi hole

for other devices in your homenetwork to use pihole DNS

Configure your devices to use the Pi-hole as their DNS server using:
IPv4: 10.0.0.47
IPv6: Not Configured
If you have not done so already, the above IP should be set to static.
View the web interface at http://pi.hole/admin: 80 or http://10.0.0.47:80/admin
Your Admin Webpage login password is XhvwK_95
To allow your user to use all CLI functions without

# Uptime Kuma

ssh -i ~/.ssh/id_rsa_terraform root@10.0.0.50 "python3 --version"

ansible-playbook -i inventory/hosts linux_setup_uptime_kuma.yml

ssh -i ~/.ssh/id_rsa_terraform root@10.0.0.50 "systemctl status uptime-kuma && netstat -tulnp | grep node && ufw status"

 ssh -i ~/.ssh/id_rsa_terraform root@10.0.0.50 "pm2 list && ls -la /opt/uptime-kuma"

ssh -i ~/.ssh/id_rsa_terraform root@10.0.0.50 "pm2 logs uptime-kuma --lines 50 && cd /opt/uptime-kuma && npm ls --depth=0"


ssh -i ~/.ssh/id_rsa_terraform root@10.0.0.50 "netstat -tulnp | grep 3001"

pm2 monit

ssh -i ~/.ssh/id_rsa_terraform root@10.0.0.50 "pm2 logs uptime-kuma --lines 100"

- Uptime kuma could only be configured through the web UI
- Can import JSON file: Settings > Backup > Import

# N8n

ansible-playbook -i inventory/hosts linux_setup_n8n.yml


ssh -i ~/.ssh/id_rsa_terraform root@10.0.0.51 "pm2 logs n8n --lines 100"

# Apache kafka

cd /Users/logan/repos/homelab/proxmox/ansible/kafka && ansible kafka -i inventory/hosts -m shell -a "systemctl status docker && docker --version && docker run hello-world && docker ps"


ssh root@10.0.0.52 -i ~/.ssh/id_rsa_terraform "docker ps --filter 'name=kafka' --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}'"


ssh root@10.0.0.52 -i ~/.ssh/id_rsa_terraform "docker logs kafka"

clean up the existing container: ansible kafka -i inventory/hosts -m shell -a "docker rm -f kafka"

ssh root@10.0.0.52 -i ~/.ssh/id_rsa_terraform "docker ps -a --filter name=kafka && docker logs kafka"


Create topic ssh root@10.0.0.52 -i ~/.ssh/id_rsa_terraform "docker exec kafka /opt/kafka/bin/kafka-topics.sh --create --topic quickstart-events --bootstrap-server localhost:9092"


Show topic - ssh root@10.0.0.52 -i ~/.ssh/id_rsa_terraform "docker exec kafka /opt/kafka/bin/kafka-topics.sh --describe --topic quickstart-events --bootstrap-server localhost:9092"

ssh root@10.0.0.52 -i ~/.ssh/id_rsa_terraform "docker exec kafka /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092"

Write to stream - ssh -t root@10.0.0.52 -i ~/.ssh/id_rsa_terraform "docker exec -it kafka /opt/kafka/bin/kafka-console-producer.sh --topic quickstart-events --bootstrap-server localhost:9092"

Read from stream - ssh -t root@10.0.0.52 -i ~/.ssh/id_rsa_terraform "docker exec -it kafka /opt/kafka/bin/kafka-console-consumer.sh --topic quickstart-events --from-beginning --bootstrap-server localhost:9092"

# Jellyfin

ansible-playbook -i inventory/hosts linux_setup_jellyfin.yml

ssh root@10.0.0.53 -i ~/.ssh/id_rsa_terraform "docker ps -a --filter name=jellyfin && docker logs jellyfin"

ssh root@10.0.0.53 -i ~/.ssh/id_rsa_terraform "mkdir -p /var/lib/jellyfin && chown -R 1000:1000 /var/lib/jellyfin && docker restart jellyfin"

ssh root@10.0.0.53 -i ~/.ssh/id_rsa_terraform "ss -tulnp | grep 8096 || echo 'No process listening on 8096' && which ufw && ufw status || iptables -L -n | grep 8096 || echo 'No firewall rules blocking 8096'"

Go to set up page: `http://localhost:8096/web/index.html#!/wizardstart.html`

# Tailscale

[Download | Tailscale](https://tailscale.com/download/linux)

`ansible-playbook -i proxmox/ansible/inventory.yml proxmox/ansible/tailscale/linux_setup_tailscale.yml`

`ssh root@10.0.0.54 -i ~/.ssh/id_rsa_terraform "sudo systemctl status tailscaled.service"`

# DNS Process Explained

1. Set Wifi DNS on mac to IP address of Mac (ipconfig getifaddr en0)
2. Set DNS records in pihole.toml
3. Laptop/phone use pihole as their DNS server (can either do it via router or change each device's DNS settings)
4. In browser you type 'homepage.homelab'.
5. Chrome  calls the system resolver (MacOS's mDNSResponder) to resolve the URL. The resolver looks at the network config and sees the DNS server is set to 10.0.0.227. 
6. Browser connects to 10.0.0.227 on HTTP port 80 (because we typed homepage.homelab)
7. The resolver creates a DNS query and sends it to UDP port 53
8. Since 10.0.0.227 is on your LAN, your Mac ARPs to find the MAC address for 10.0.0.227 and fires the packet on the wire
9. If you’re doing this from the same Mac that’s running Docker, it still works: packets to 10.0.0.227 loop back into the host’s networking stack (because that IP is assigned to your Mac), then hit Docker’s port-forward
10. Docker forwards host :53 -> Pi-hole container :53 (this is because we defined - "53:53/tcp" and "53:53/udp" in the pihole ports config)
11. Pihole checks its local DNS and returns 10.0.0.227 as the IP address.
    - For everything else (e.g., example.com), Pi-hole forwards to its upstream resolver(s) (whatever you configured in the Pi-hole admin: Cloudflare, Quad9, your router, etc.), gets the reply, applies blocklists if relevant, and sends the answer back to your Mac
12. On host machine (Mac), Caddy is listening on ports 80 and 443 (these ports are defined in teh caddy definition in docker-compose.yml)
13. Caddy looks at the HTTP Host header(homepage.homelab) and matches it and reverse-proxies the rquest to the homepage container on port 3000. The hostname is the Docker service name and since Caddy is attached to the same networks that the targets live, it can reach them on their container ports (so, you don't need to publish app ports anymore, as Caddy is the entrance to the services)


# TODO

- https://github.com/tchiotludo/akhq
- Install https://github.com/prometheus-pve/prometheus-pve-exporter on proxmox to get prometheus metrics of all services
- https://jellyfin.org/docs/general/installation/linux
- [grafana/loki: Like Prometheus, but for logs.](https://github.com/grafana/loki)
- https://github.com/grafana/alloy
- [Automatic OS installation on VM : r/Proxmox](https://www.reddit.com/r/Proxmox/comments/1kcaj2q/automatic_os_installation_on_vm/)
- [Install Grafana Alloy with Ansible | Grafana Alloy documentation](https://grafana.com/docs/alloy/latest/set-up/install/ansible/)
- Install redis
- [Cloud-init not working with Kali image : r/Proxmox](https://www.reddit.com/r/Proxmox/comments/1gnbcaz/cloudinit_not_working_with_kali_image/)
- Traefik: https://github.com/briandipalma/proxmox-services/blob/main/ansible/roles/traefik/tasks/main.yml
- Docker: Configure devices so that I can type in grafana.homelab and be taken to grafana
- Docker: push frontend of live-auction to docker hub

# Trouble Shooting

## REMOTE HOST IDENTIFICATION HAS CHANGED

```
ssh root@10.0.0.54 -i ~/.ssh/id_rsa_terraform "sudo systemctl status tailscaled.service"

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
Someone could be eavesdropping on you right now (man-in-the-middle attack)!
It is also possible that a host key has just been changed.
The fingerprint for the ED25519 key sent by the remote host is
SHA256:A2+CXhc00dM5xalHfesS3yuSkUqEuBP/cs5mdiA5j/Y.
Please contact your system administrator.
Add correct host key in /Users/logan/.ssh/known_hosts to get rid of this message.
Offending RSA key in /Users/logan/.ssh/known_hosts:40
Host key for 10.0.0.54 has changed and you have requested strict checking.
Host key verification failed.
```

1. `ssh-keygen -R 10.0.0.54` -> updates ~/.ssh/known_hosts.old
2. `ssh-keyscan -H 10.0.0.54 >> ~/.ssh/known_hosts` 
3. Runrun command