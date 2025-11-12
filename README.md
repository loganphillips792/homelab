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


1. Download ISO image (Proxmox ISO installer): https://www.proxmox.com/en/proxmox-virtual-environment/get-started and use Balena Etcher to flash ISO image to USB Drive
2. Boot from USB
    1. Plug in External Display and Keyboard into mini PC
    1. Turn off mini PC
    2. Insert USB
    3. Turn on mini PC
    4. Press F7 to get into BIOS
    5. Select USB Drive as the boot device
3. Install Process
    1. Install Proxmox VE (Graphical)
    2. Accept User License Agreement
    3. Location and Timezone selection
        1. Country: United States
        2. Time zone: America/Chicago
        3. Keyboard Layout: U.S. English
    4. Administration Password and Email Selection
        1. Set Password
        2. Set Email
    5. Management Network Configuration (Leave all defaults)
        - Management Interface: enp1s0 - (this is the ethernet connection)
        - Hostname (FQDN) - pve.hsd1.il.comcast.net
        - IP Address (CIDR) - 10.0.0.98 / 24
        - Gateway - 10.0.0.1
        - DNS Server - 75.75.75.75
4.  Update repos to not use enterprise (https://pve.proxmox.com/wiki/Package_Repositories)
    1. apt install vim
    2. Comment out each line in `/etc/apt/sources.list.d/pve-enterprise.sources`
    3. Create and Update '/etc/apt/sources.list.d/proxmox.sources'

    ```
    Types: deb
    URIs: http://download.proxmox.com/debian/pve
    Suites: trixie
    Components: pve-no-subscription
    Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
    ```
    
    4. Edit `/etc/apt/sources.list.d/ceph.sources`
    
    ```
    Types: deb
    URIs: http://download.proxmox.com/debian/ceph-squid
    Suites: trixie
    Components: no-subscription
    Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
    ```
    5. apt update
    6. apt upgrade
5. Go to https://10.0.0.98:8006 on another computer (connected to same wifi network)
6. Setup Ubuntu VM for Docker
    1. Download Ubuntu Desktop ISO
    2. Datacenter > pve > local (pve) > ISO Images > Upload Ubuntu ISO file
    3. Create VM
        - General
            - Node: PVE
            - VM ID: 100
            - Name: UbuntuServerForDockerServices
        - OS
            - Storage: Local
            - ISO image: Ubuntu-22.04-4.desktop
            - Guest OS:
                - Type: Linux
                - Version: 6.x - 2.6 Kernel
        - System
            - Leave all defaults
        - Disks
            - Disk
                - Storage: local-lvm
                - Disk size (GiB): 64
        - CPU (https://10.0.0.98:8006/pve-docs/chapter-qm.html#qm_cpu)
            - Sockets - 1
            - Cores - 2
        - Memory (https://10.0.0.98:8006/pve-docs/chapter-qm.html#qm_memory)
            - Memory (MiB) - 2048
            - Minimum Memory (MiB) - 2048
            - Ballooning Device - Enabled
       -  Network (https://10.0.0.98:8006/pve-docs/chapter-qm.html#qm_network_device)
            - Default 
7. Start VM and Install Packages
    1. Go through GUI Install Wizard
    2. Open terminal and run `sudo apt update && sudo apt upgrade`
8. Setup SSH server
    1. Set IP address for VM
        1. Make sure qemu-guest-agent  is installed: `apt install qemu-guest-agent`
        2. Enable guest agent in VM options
        Restart the VM
        3. systemctl status qemu-guest-agent
        4. systemctl start qemu-guest-agent if its not running
        5. Get IP Address from pve > Summary
    2. sudo apt update
    3. sudo apt install openssh-server
    4. sudo systemctl status ssh
9. SSH into server: logan@10.0.0.32
10. Setup Docker
    1. Set Up Docker's apt repository
    4. Install the Docker packages: `sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`
    5. Verify that Docker is running: `sudo systemctl status docker`. If it is not running, you might have to start it manually: `sudo systemctl start docker`
    6. Run docker ps
        - If you get error 'permission denied while trying to connect to the docker API at unix:///var/run/docker.sock, it is because the current user can’t access the docker engine, because the user doesn't have enough permissions to access the UNIX socket to communicate with the engine
            - You can use sudo docker ps but a better solution is here: https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user
                1. sudo groupadd docker
                2. sudo usermod -aG docker $USER
                3. Log out and log back in so that your group membership is re-evaluated




   


    4. Install Ubunu image so that we can use it for LXE containers
        1. Open console in Proxmox host
        2. pveam update
        3. pveam available
        4. pveam update
        5. pveam download local ubuntu-23.10-standard_23.10-1_amd64.tar.zst
    5.  Setup Kali Linux
    6.  Setup PopOS
        1. Download Pop OS image
        2. Datacenter > pve > local (pve) > ISO Images > Upload POP OS ISO file
        3. Create VM
            - General
                - Node: PVE
                - VM ID: 100
            - OS
                - Select PopOS ISO > Next
    7. Set up Home Assistant




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

# TODO

- Install https://github.com/prometheus-pve/prometheus-pve-exporter on proxmox to get prometheus metrics of all services
- Traefik: https://github.com/briandipalma/proxmox-services/blob/main/ansible/roles/traefik/tasks/main.yml
- Install Homeassistant on VM
- Access VMs from outside of network
    - Tailscale
        - install on pop os vm and laptop. Once connected to tailscale, open remote desktop viewer
        - Install remote desktop server on pop os (xrdp)
        - Install microsoft remote desktop on mac (app store)
            - OPen -> Add PC -> Tailscale IP of VM

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

