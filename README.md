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
            - Cores - 4
        - Memory (https://10.0.0.98:8006/pve-docs/chapter-qm.html#qm_memory)
            - Memory (MiB) - 8192
            - Minimum Memory (MiB) - 8192
            - Ballooning Device - Enabled
       -  Network (https://10.0.0.98:8006/pve-docs/chapter-qm.html#qm_network_device)
            - Default 
7. Start VM and Install Packages
    1. Go through GUI Install Wizard
    2. Open terminal and run `sudo apt update && sudo apt upgrade`
    3. `sudo apt install net-tools`
    4. `sudo apt install htop`
8. Setup SSH server
    1. Set IP address for VM
        1. Make sure qemu-guest-agent  is installed: `apt install qemu-guest-agent`
        2. Enable guest agent in VM options: pve > UbuntuServerForDockerServices > Options > Enable QEMU Guest Agent
        3. Restart the VM
        4. systemctl status qemu-guest-agent
        5. systemctl start qemu-guest-agent if its not running
        6. Get IP Address from pve > UbuntuServerForDockerServices > Summary
    2. sudo apt update
    3. sudo apt install openssh-server
    4. sudo systemctl status ssh
9. SSH into server: logan@10.0.0.32
10. Setup Docker
    1. [Set Up Docker's apt repository](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository)
    2.
    ```
    sudo apt-get update && \
    sudo apt-get install -y ca-certificates curl && \
    sudo install -m 0755 -d /etc/apt/keyrings && \
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    sudo chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    sudo apt-get update
    ```

    
    4. Install the Docker packages: `sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`
    5. Verify that Docker is running: `sudo systemctl status docker`. If it is not running, you might have to start it manually: `sudo systemctl start docker`
    6. Run `docker ps`
        - If you get error 'permission denied while trying to connect to the docker API at unix:///var/run/docker.sock, it is because the current user can’t access the docker engine, because the user doesn't have enough permissions to access the UNIX socket to communicate with the engine
            - You can use `sudo docker ps` but a better solution is here: https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user
                1. sudo groupadd docker
                2. sudo usermod -aG docker $USER
                3. Log out and log back in so that your group membership is re-evaluated
    8. Setup homelab repo
        1. `cd ~`
        2. Create Docker Volumes directory: `mkdir ~/docker-volumes`
        3. `cd homelab`
        4. `git clone https://github.com/loganphillips792/homelab.git`
        5. Update the IP Addresses in the PiHole DNS config to the IP Address of the Ubuntu VM: `sed -i 's/10\.0\.0\.227/10.0.0.33/g' docker/pihole/etc-dnsmasq.d/10-homelab.conf`
            - If these records are updated after the docker containers are already running, run `docker compose restart pihole` to restart pihole and apply the DNS changes
        6. Add .env file for live-auction (optional)
    7. Set up DNS (free port 53)
       
       `sudo vim /etc/netplan/01-network-manager-all.yaml`
       
       ```
        # Let NetworkManager manage all devices on this system
        network:
        version: 2
        ethernets:
            ens18:
            dhcp4: yes
            nameservers:
                addresses: [1.1.1.1, 9.9.9.9]
       ```

`sudo netplan apply`

Now make sure /etc/resolv.conf uses what systemd-resolved generates:
    1. sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    2. sudo systemctl restart systemd-resolved

Check that the file has real DNS servers, not 127.0.0.53 or ::1: cat /etc/resolv.conf

Nowe we tell systemd-resolved to stop listening on 127.0.0.53/[::1], but it will still use the upstream DNS servers from netplan: `sudo sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf`

Restart: `sudo systemctl restart systemd-resolved`

Confirm port 53 is now free: `sudo ss -lunpt | grep :53 || echo "Port 53 is free ✅"`



8. Bring up Docker containers
    1. docker login -u dockedupstream
    2. `docker compose -f docker/docker-compose.yml up -d && docker compose --env-file "$PWD/docker/immich/docker-compose.env" -f "$PWD/docker/immich/docker-compose.yml" up -d && docker compose -f docker/tubearchivist/docker-compose.yml up -d`

9. `sudo ss -lunpt | grep :53` If you see docker-proxy, that means that PiHole has binded to port 53

10. To test that the Docker containers are properly running, go to `http://10.0.0.33:8082`


11. Switch the host to use Pi-Hole
    1. Once Pi-Hole is up and stable, you can make the Ubuntu host itself use Pi-hole as DNS instead of public resolvers
        `sudo vim /etc/netplan/01-network-manager-all.yaml`

    ```
    # Let NetworkManager manage all devices on this system
    network:
    version: 2
    ethernets:
        ens18:
        dhcp4: yes
        nameservers:
            addresses: [10.0.0.33]
    ```
    2. `sudo netplan apply`
    3. `sudo systemctl restart systemd-resolved`
    4. `cat /etc/resolv.conf`

12. Test DNS
    1. `dig example.com`
    2. `dig homepage.homelab`
    3. `dig homepage.homelab @10.0.0.33`


13. Update MacOS wifi to use Proxmox VM PIhole container as DNS. Set the DNS Server to be the IP of the Ubuntu VM. The request will automatically be sent to port 53



Backup N8N Database: `ssh logan@10.0.0.33 'cd ~/homelab/docker && docker compose exec -T postgres pg_dump -U changeUser n8n' > n8n-postgres-backup_$(date +%F).sql`
Backup N8N Volume: `ssh logan@10.0.0.33 'docker run --rm -v n8n_storage:/volume alpine sh -c "cd /volume && tar -czf - ."' > n8n-storage-backup.tar.gz`


- If you need to increase disk space
    - Increase size of disk of VM through proxmox
    - df -h
    - lsblk
    - sudo su
    - parted
    - print
    - resizepart 3 100%
    - print
    - resize2fs /dev/sda3
    - Exit
    - apt install lvm2
    - If you get not enough storage error, you have to clear space
    - See what is taking up so much space 
        - du -sh /var/* | sort -h 
        - We see that docker takes up most of the space in /var/
        - `docker images --format "{{.Repository}}:{{.Tag}} {{.Size}}" | sort -h -r`
        - `sudo ctr -n moby images prune --all`
    - sudo rm -rf /var/cache/apt/archives/*.deb
    - sudo journalctl --vacuum-size=50M
    - apt install lvm2
    - resize2fs /dev/sda3
- If at anytime there is a permission denied error during git pull process: `sudo chown -R logan:logan .` and then run `git pull` again

- After making DNS changes to the pihole DNS file: `docker compose -f docker/docker-compose.yml restart pihole`

- After making changes to prometheus: `docker compose -f docker/docker-compose.yml restart prometheus`

- docker compose -f docker/docker-compose.yml up caddy pihole cronmaster -d 

- `docker compose -f docker/docker-compose.yml up -d cadvisor pihole caddy prometheus loki alloy grafana homepage`

- Use `docker stats` command to see container usage

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

pveversion --verbose

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
- Fix komodo errors
- Add https://codewithcj.github.io/SparkyFitness/install/docker-compose to docker compose

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

