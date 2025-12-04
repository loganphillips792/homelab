
To run all services:
```
docker compose -f docker/docker-compose.yml up -d && docker compose --env-file "$PWD/docker/immich/docker-compose.env" -f "$PWD/docker/immich/docker-compose.yml" up -d
```

`cd docker`
`docker compose up --build` or `docker compose up -d --build`
`docker compose -f docker/docker-compose.yml up -d --force-recreate pihole`
`docker compose up --build jellyfin`
`docker compose up -d --build caddy pihole`

- if you only want to start specific containers: `docker compose up -d homepage uptime-kuma pihole caddy`
- Then `docker logs` will only show the logs from the started containers


`docker compose -f docker/docker-compose.yml up -d`

```
docker compose -f docker/docker-compose.yml up -d caddy pihole homepage uptime-kuma \
  && docker compose -f docker/immich/docker-compose.yml \
    --project-directory docker/immich \
    --env-file docker/immich/docker-compose.env \
    up -d
```

- Updating containers:
  - `docker compose -f docker/docker-compose.yml pull && docker compose -f docker/docker-compose.yml up -d` it will down only the affected services and bring up new containers of those affected services.
  - After testing to make sure everything is good, run `docker system prune`

# Services

## Kafka

Create Topics

Topic that orchestrator pushes to:
```
docker exec kafka /opt/kafka/bin/kafka-topics.sh --create \
  --topic scan.commands \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 1
```

Topic that workers push to, and orchestrator reads from
```
docker exec kafka /opt/kafka/bin/kafka-topics.sh --create \
  --topic scan.events \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 1
```


List Topics
```
docker exec kafka /opt/kafka/bin/kafka-topics.sh --list \
  --bootstrap-server localhost:9092
```


Describe Topic
```
docker exec kafka /opt/kafka/bin/kafka-topics.sh --describe \
  --topic scan.commands \
  --bootstrap-server localhost:9092
```


Send Message (producer)
```
docker exec -it kafka /opt/kafka/bin/kafka-console-producer.sh \
  --topic scan.commands \
  --bootstrap-server localhost:9092
```


Consume Messages (consumer)
```
docker exec -it kafka /opt/kafka/bin/kafka-console-consumer.sh \
  --topic scan.commands \
  --bootstrap-server localhost:9092 \
  --from-beginning
```


Check consumer groups
```
docker exec kafka /opt/kafka/bin/kafka-consumer-groups.sh --list \
  --bootstrap-server localhost:9092
```

## Kafka UI

localhost:8080

## Grafana

localhost:3000


## N8N

localhost:5678

- Reset password
  1. `docker exec -it docker-n8n-1 sh`
  2. `n8n user-management:reset`
  3. `docker compose -f docker/docker-compose.yml restart n8n`


## Dozzle

localhost:8083

## PiHole

- Get IP address of Mac Host: `ipconfig getifaddr en0`
- The IP address of the customs.list is of the host machine (Mac)
- DNS of the mac has to point to the MAC itself (10.0.0.227) in my case
- WIFI > Details > DNS set to 10.0.0.337
  - Original DNS servers
    - 75.75.75.75
    - 75.75.76.76


- Run `docker compose up -d --build --force-recreate pihole` if any changes are made (such as changing pihole.toml)



- Purpose split: Pi‑hole handles DNS; Caddy handles HTTP(S) reverse proxy and TLS.
- Ports: Pi‑hole publishes DNS on 53/tcp, 53/udp and does not expose web ports (80/443 are commented). Caddy binds 80/443 on the
host.
- Networking: Both containers share the default Docker network, so Caddy can reach Pi‑hole’s web UI at pihole:80 internally.
- Proxy rule: Caddy routes http://pihole.homelab to pihole:80 and redirects / to /admin/ (see caddy/Caddyfile).
- DNS records: Pi‑hole serves .homelab hostnames and resolves them to your host IP (e.g., 10.0.0.227) via pihole/etc-pihole/hosts/
custom.list and 02-local.conf. Clients using Pi‑hole as DNS will resolve *.homelab to the host.
- End‑to‑end flow: Client requests pihole.homelab → Pi‑hole DNS returns 10.0.0.227 → connection hits Caddy on :80/:443 → Caddy
reverse‑proxies to the Pi‑hole container (pihole:80).


http://pihole.homelab/admin/

- Create a single volumes directory to make it easy to back up all data ??

- Now we have to have all of our devices use Pihole as their DNS server.



docker exec pihole tail -n 100 -f /var/log/pihole/pihole.log 

`docker exec pihole pihole reloaddns`

## Homepage

http://homepage.homela

After making any changes: `docker compose up -d --build homepage`

## Uptime Kuma

not natively. Uptime Kuma doesn’t read a static config file on start; it stores monitors
in a SQLite DB under /app/data. You will have to manually import the backup file.

- Reset Password
  1. `docker exec -it uptime-kuma bash`
  2. `npm run reset-password`

- There is a something going on with the DNS, where some services are reported to be up, but others are reported to be down. These down services, are still acccessible by URL, but uptime-kuma reports them as down due to the errror `getaddrinfo ENOTFOUND`. To fix this, run `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder` on the host Mac machine, and uptime-kuma should successfully report that all services are running.

- Backup sql DB: `ssh logan@10.0.0.33 'cd ~/homelab/docker && docker compose exec -T uptime-kuma sqlite3 /app/data/kuma.db ".backup /dev/stdout"' > uptime-kuma-backup_$(date +%F).db`
- Backup Docker Volume: 
```
ssh logan@10.0.0.33 '
  docker run --rm \
    -v uptime_kuma_data:/data \
    alpine \
    sh -c "cd /data && tar cf - ."
' > uptime-kuma-volume_$(date +%F).tar
```

- Restore volume: 

## Tailscale

1. Create account at https://login.tailscale.com/admin
2. Generate auth key and add to env variable
3. `docker compose up --build tailscale`
4. Go to `https://login.tailscale.com/admin/machines` and you should see the machine


To ssh into VM:

1. Connect machine to the tailnet
2. `ssh ssh logan@<ip_of_vm>`



## Test Postgres



if you have to rerun the SQL script: `docker compose -f docker/docker-compose.yml exec -T test-db psql -U testuser -d test_database -f docker-entrypoint-initdb.d/10-test-table.sql`


`docker exec -it postgres_db psql -U testuser -d test_database -c 'SELECT * FROM "test-table";'`

## Live-Auction

1. Make sure live-auction repo has the proper settings so that the image gets pushed properly during deployment:
  - Settings > Repository Secrets
      - DOCKERHUB_USERNAME
      - DOCKERHUB_PASSWORD

2. Copy .env from live-auction to `docker/live-auction`
3. docker login -u dockedupstream
4. `docker info | username` to check
5. Make sure you can pull the image from the private repo: `docker pull docker.io/dockedupstream/live-auction:main`
6. `docker compose up --build live-auction`

Test:
```
curl --request GET \
  --url 'http://localhost:8000/api/auctions/?skip=0&limit=9'
```

## Redis

1. `docker exec -it redis redis-cli`
2. `AUTH <password_here>`
3. `SET foo bar`
4. `GET foo`
5. `KEYS *`
6. `DEL foo`


OR

1. `docker exec redis redis-cli AUTH your_password_here`
2. `docker exec redis redis-cli -a your_password_here SET foo bar`
3. `docker exec redis redis-cli -a your_password_here GET foo`
4. `docker exec redis redis-cli -a your_password_here INFO`
5. `docker exec redis redis-cli -a your_password_here FLUSHALL`


OR

1. `docker exec -it redis sh`
2. `redis-cli`
3. `AUTH your_password_here`


OR
If you ever want to connect from another container in the same compose network, use the service name: `redis-cli -h redis -a your_password_here`

## Umami

Username: admin
Password: umami

## Ollama

- `docker exec -it ollama ollama list`
- `docker exec -it ollama ollama pull deepseek-r1:1.5b`

## Komodo

Username: admin
Password: changeme

- You might see this error in the Mongo logs that will prevent the app from working: _WARNING: MongoDB 5.0+ requires a CPU with AVX support, and your current system does not appear to have that!_
  - To fix this, go to the Hardware settings of the VM, Edit the Processors and select `x86-64-v3` as the `Type`. Restart the VM

[Backup and Restore | Komodo](https://komo.do/docs/setup/backup)

## Karakeep

All of Hoarder's data are in the DATA_DIR. If you can periodically snapshot that folder, that would take a full backup of hoarder. You don't need to backup meillisearch as the data there can be reconstructed.

`ssh logan@10.0.0.33 "docker run --rm -v karakeep-data:/data -v \$HOME:/backup alpine sh -c 'tar czf /backup/karakeep-backup-\$(date +%Y%m%d-%H%M%S).tar.gz -C /data .'"`

- If admin forgets password: https://docs.karakeep.app/FAQ/#if-you-are-an-administrator

## C Advisor

[Failure to get data in Prometheus on latest Docker · Issue #3749 · google/cadvisor](https://github.com/google/cadvisor/issues/3749)

As a workaround, I had to turn off containerd-snapshotter and then restart docker


# DNS Process Explained

1. Set Wifi DNS on mac to IP address of Mac (ipconfig getifaddr en0)
2. Set DNS records in 10-homelab.conf
3. Laptop/phone use pihole as their DNS server (can either do it via router or change each device's DNS settings)
4. In browser you type 'homepage.homelab'.
5. Chrome  calls the system resolver (MacOS's mDNSResponder) to resolve the URL. The resolver looks at the network config and sees the DNS server is set to 10.0.0.227. 
6. The resolver creates a DNS query and sends it to UDP port 53 (10.0.0.227)
7. Since 10.0.0.227 is on your LAN, your Mac ARPs to find the MAC address for 10.0.0.227 and fires the packet on the wire
8. If you’re doing this from the same Mac that’s running Docker, it still works: packets to 10.0.0.227 loop back into the host’s networking stack (because that IP is assigned to your Mac), then hit Docker’s port-forward
9. Docker forwards host :53 -> Pi-hole container :53 (this is because we defined - "53:53/tcp" and "53:53/udp" in the pihole ports config)
10. Pihole checks its local DNS and returns 10.0.0.227 as the IP address for homepage.homelab.
    - For everything else (e.g., example.com), Pi-hole forwards to its upstream resolver(s) (whatever you configured in the Pi-hole admin: Cloudflare, Quad9, your router, etc.), gets the reply, applies blocklists if relevant, and sends the answer back to your Mac
11. Browser connects to 10.0.0.227 on HTTP port 80 (because we typed homepage.homelab)
12. On host machine (Mac), Caddy is listening on ports 80 and 443 (these ports are defined in the caddy definition in docker-compose.yml)
13. Caddy looks at the HTTP Host header(homepage.homelab) and matches it and reverse-proxies the request to the homepage container on port 3000. The hostname is the Docker service name and since Caddy is attached to the same networks that the targets live, it can reach them on their container ports (so, you don't need to publish app ports anymore, as Caddy is the entrance to the services)


_Note:_ if all containers are running but homepage.homelab is not working, run `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder` and then try again

_NOTE_: If running on Mac OS, make sure `Use kernel networking for UDP` is NOT selected in Docker Desktop _settings > Resources > Network_


# TODO

https://docs.kitchenowl.org/latest/self-hosting/

https://github.com/Dispatcharr/Dispatchar

https://github.com/sysadminsmedia/homebox

https://github.com/AnalogJ/scrutiny

https://github.com/nextcloud/all-in-one#how-to-change-the-default-location-of-nextclouds-datadir

https://github.com/ArchiveBox/ArchiveBox

https://openpanel.dev/docs/self-hosting/self-hosting

https://github.com/binwiederhier/ntfy

https://github.com/huginn/huginn/blob/master/doc/docker/install.md

https://crazymax.dev/diun/usage/command-line/

https://github.com/crowdsecurity/crowdsec

- COMPOSE_KOMODO_BACKUPS_PATH=~/docker-volumes/komodo/etc/komodo/backups doesn't seem to be working correctly
- Tailscale
  - [Newbie question - tailscale on proxmox host or on each (needed) container? : r/Proxmox](https://www.reddit.com/r/Proxmox/comments/1ktje1t/newbie_question_tailscale_on_proxmox_host_or_on/)
  - [Best Way to Setup Tailscale? : r/Proxmox](https://www.reddit.com/r/Proxmox/comments/1dmrca4/best_way_to_setup_tailscale/)
- https://ntfy.sh
- Diun and connect it to Ntfy notifications
  - https://crazymax.dev/diun/notif/ntfy/
- [dmunozv04/iSponsorBlockTV: SponsorBlock client for all YouTube TV clients.](https://github.com/dmunozv04/iSponsorBlockTV)
- [Download the Checkmk Raw 2.4.0p15 for Docker](https://checkmk.com/download?platform=docker&edition=cre&version=2.4.0p15)
- [dohsimpson/TaskTrove: TaskTrove is a modern Todo Manager that is fully self-hostable.](https://github.com/dohsimpson/TaskTrove)
- [calibrain/calibre-web-automated-book-downloader](https://github.com/calibrain/calibre-web-automated-book-downloader)
- [rybbit-io/rybbit: 🐸 Rybbit - open-source and privacy-friendly alternative to Google Analytics that is 10x more intuitive.](https://github.com/rybbit-io/rybbit)
- [schlagmichdoch/PairDrop: PairDrop: Transfer Files Cross-Platform. No Setup, No Signup.](https://github.com/schlagmichdoch/PairDrop)
- [Ironmount - Backup automation GUI for your homeserver : r/selfhosted](https://www.reddit.com/r/selfhosted/comments/1ox8da8/ironmount_backup_automation_gui_for_your/)
- https://beszel.dev/guide/common-issues#connecting-hub-and-agent-on-the-same-system-using-docker
- https://docs.anythingllm.com/installation-docker/local-docker
- [lobehub/lobe-chat: 🤯 LobeHub - an open-source, modern design AI Agent Workspace. Supports multiple AI providers, Knowledge Base (file upload / RAG ), one click install MCP Marketplace and Artifacts / Thinking. One-click FREE deployment of your private AI Agent application.](https://github.com/lobehub/lobe-chat)
- Set up tail scale  so I can access proxmox and all containers
- [guide : using the new WebUI of llama.cpp · ggml-org/llama.cpp · Discussion #16938](https://github.com/ggml-org/llama.cpp/discussions/16938)
- [Focus - Self-Hosted Background Removal with Web UI : r/selfhosted](https://www.reddit.com/r/selfhosted/comments/1p0dcut/focus_selfhosted_background_removal_with_web_ui/)
- gitea
- Forejo
- [mayanayza/netvisor: Automatically discover and visually document network infrastructure.](https://github.com/mayanayza/netvisor)
- https://github.com/matomo-org/docker/
- rename `docker-volumes` directory as `docker-bind-mounts`
- Update homepage https://www.reddit.com/r/selfhosted/comments/1p1469e/my_homepage_dashboard_v3/

# Setting Up VM and Docker


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
    2. `docker compose -f docker/docker-compose.yml up -d && docker compose --env-file "$PWD/docker/immich/docker-compose.env" -f "$PWD/docker/immich/docker-compose.yml" up -d && docker compose --env-file docker/.env -f docker/tubearchivist/docker-compose.yml up -d`

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

## TailScale

To access services outside of home network, we will use tailscale


1. Create tag (Access controls)

```
"tagOwners": {
		"tag:container": ["autogroup:admin"],
	},
```

2. Enable Routes (Machines tab)
    1. Click `tailscale` machine
    2. Edit route settings
    3. Approve 10.0.0.0/24 route

3. Tailscale Admin Console > Settings > Keys
4. Generate Auth Key
    - Description: homelab-docker
    - Reusable: Yes
    - Expiration: 90 days
    - Ephemeral: No
    - Tags: `tag:container`
5. Update `docker-compose.yml` with auth key
6. `docker compose up -d tailscale`
7. Configure "Split DNS"
  1. DNS Tab
  2. Scroll down to Nameservers and click `Add nameserver` > `Custom`
  3. Enter the IP address of your VM: 10.0.0.33
  4. Check the box `Restrict to domain`
  5. Enter domain `homelab`
  6. Click save
8. Open Tailscale App on phone
9. Sign into Tailscale account (Same account where you generated the auth key)
10. Ensure it is set to `Active`
11. Type `http://homepage.homelab`

## Useful Commands


- After making DNS changes to the pihole DNS file: `docker compose -f docker/docker-compose.yml restart pihole caddy`

- After making changes to prometheus: `docker compose -f docker/docker-compose.yml restart prometheus`

- docker compose -f docker/docker-compose.yml up caddy pihole cronmaster -d 

- `docker compose -f docker/docker-compose.yml up -d cadvisor pihole caddy prometheus loki alloy grafana homepage`

- Use `docker stats` command to see container usage

pveversion --verbose


# Backup strategy


1. docker compose down first to make sure no data corruption happens

script:

bind mounts (if not committed with the repo) are always located at:

to backup docker volumes:

create a script on host machine

on VM, create a directory /opt/docker-backups


To restore:

1. restoure volumes:

2. restore bind mount paths



cron job to do above ?




Download Proxmox Backup Server: https://www.proxmox.com/en/downloads/proxmox-backup-server/iso

Datacenter > pve > local (pve) > ISO Images > Upload ISO file

Create VM with ISO image

- go through graphical install process
  - management interface - ens18
  - Hostname (FQDN) - pbs.hsd1.il.comcast.net
  - IP Address (CIDR) -  10.0.0.43 / 24
  - Gateway - 10.0.0.1
  - DNS Server - 75.75.75.75

  Access the UI at https://10.0.0.43:8007/

  Username - root
  Password - password

# Tailscale on Proxmox host

[How to install Tailscale on Proxmox, not a CT or VM : r/Proxmox](https://www.reddit.com/r/Proxmox/comments/17rpsgz/how_to_install_tailscale_on_proxmox_not_a_ct_or_vm/)

so we can access proxmox from outside of network