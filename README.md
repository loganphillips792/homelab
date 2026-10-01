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

## VM sizing (do this when creating the VM)

The host `pve` has **28 GiB** of physical RAM. Never allocate a VM more RAM than the host
can actually back — if the guest's page cache and Docker stack grow past what's left, the
**entire Proxmox host hard-freezes** with nothing written to its logs (no OOM record). This
was the cause of the repeated "VM crashes" on Jun 26, Jul 20, and Aug 11 2026.

Also set `onboot` so the VM comes back on its own after a host reboot — without it the VM
just stays off and it looks like it crashed again.

|command|result|
|-|-|
|`qm set 100 --memory 20480`|`memory: 20480` (20 GiB, leaves ~8.5 GiB for Proxmox)|
|`qm set 100 --onboot 1`|`onboot: 1`|

Memory changes only take effect on the VM's next stop/start. Check the current values with
`qm config 100 | grep -E '^(memory|balloon|onboot)'` and the host's total with `free -m`.

> Note: VM 101 (PopOS, stopped) is also configured for 32 GiB — never run it at the same
> time as VM 100.

pct status 109

pct exec 109 ip a

journalctl -u pve-lxc@109

pveversion --verbose

# Using Terraform and Ansible to provision new VM

Two steps, both run from the Mac:

1. **Terraform** (`terraform/`) creates the Ubuntu VM on Proxmox from the Ubuntu cloud image. Cloud-init sets the `logan` user, your SSH key, a static IP and qemu-guest-agent.
2. **Ansible** (`ansible/`) installs Docker and the base setup on that VM, clones this repo and brings the stack up.

This is separate from the older `proxmox/terraform/` and `proxmox/ansible/` setups above.

## Terraform

`terraform/` creates one VM with the bpg/proxmox provider. The defaults are in `terraform/variables.tf`:

|setting|default|
|-|-|
|VM ID / name|`150` / `docker-vm`|
|IP|`192.168.1.150/24`, gateway `192.168.1.1`|
|CPU / RAM / disk|8 cores (`host` type), 20 GiB, 256 GB on `local-lvm`|
|OS|Ubuntu 24.04 cloud image|
|User|`logan`, key from `~/.ssh/id_ed25519.pub`, passwordless sudo|

The new VM takes over the current VM's IP (`192.168.1.150`), so everything that points at `.150` keeps working. The VM ID differs (`150` vs the current `100`), so both can exist, but **don't run both at once**: they'd fight over the IP, and two VMs with 20 GiB each exceed the host's 28 GiB and freeze Proxmox (see [VM sizing](#vm-sizing-do-this-when-creating-the-vm)). Stop VM 100 before `terraform apply`.

### One-time setup

1. Create an API token in Proxmox: Datacenter > Permissions > API Tokens > Add, user `root@pam`, token ID `terraform`. Copy the secret; it's only shown once.
   - If **Privilege Separation** is checked, the token has no permissions of its own, and `terraform apply` fails with `403 Permission check failed`. Keep separation and grant the token a role. In the UI, go to Datacenter > Permissions > Add > **API Token Permission**, then set:
     - Path: `/`
     - API Token: `root@pam!terraform`
     - Role: `Administrator`
     - Propagate: checked

     Or run this in the Proxmox host shell:

     ```bash
     pveum acl modify / --tokens 'root@pam!terraform' --roles Administrator
     ```
2. Put it in `terraform/terraform.tfvars` (gitignored):

```bash
cd terraform && cp terraform.tfvars.example terraform.tfvars
```

   Check the token from inside `terraform/`. You should get a JSON list of files; a 401 means a wrong token or secret, and a 403 means missing permissions (see step 1):

```bash
curl -sk -H "Authorization: PVEAPIToken=$(sed -nE 's/.*proxmox_api_token *= *"([^"]*)".*/\1/p' terraform.tfvars)" https://192.168.1.98:8006/api2/json/nodes/pve/storage/local/content
```

3. Enable snippets on the `local` storage. The cloud-init file is uploaded there. First check the current content types on the Proxmox host:

```bash
ssh root@192.168.1.98 "grep -A4 '^dir: local' /etc/pve/storage.cfg"
```

Then set the list it printed plus `snippets`. For example, if it showed `iso,vztmpl,backup`:

```bash
ssh root@192.168.1.98 "pvesm set local --content iso,vztmpl,backup,snippets"
```

4. The snippet is uploaded over SSH as `root`, using your ssh-agent. Make sure your key is loaded and can log in to the host:

```bash
ssh-add ~/.ssh/id_ed25519 && ssh root@192.168.1.98 true
```

   If that fails with `Permission denied (publickey,password)`, the key is loaded in your ssh-agent but root's `authorized_keys` on the Proxmox host doesn't have it. Without that login, Terraform can't upload the cloud-init snippet. Add the key once (it asks for the root password), then re-run the check above:

```bash
ssh-copy-id root@192.168.1.98
```

5. Initialise the provider:

```bash
cd terraform && terraform init
```

### Commands

Run these from inside `terraform/`.

Preview:
```bash
terraform plan
```

Create the VM:
```bash
terraform apply
```

Use a different ID or IP without editing files:
```bash
terraform apply -var vm_id=151 -var ip_cidr=192.168.1.152/24
```

Show the IP, the SSH command and the Ansible command:
```bash
terraform output
```

Delete the VM:
```bash
terraform destroy
```

The first boot takes a minute or two while cloud-init installs qemu-guest-agent. `terraform apply` waits for it.

### Then run Ansible against the new VM

`ansible/inventory.ini` already points at `192.168.1.150`. The new VM has a new SSH host key, so clear the old VM's entry first:

```bash
ssh-keygen -R 192.168.1.150
cd ansible && ansible-playbook site.yml
```

The VM has passwordless sudo, so `-K` isn't needed.

The first run pulls ~80 images (~70 GB) and "Pull images and bring the stack up" prints nothing until it finishes, which can take 20+ minutes. To watch progress while it runs, open a second terminal and run this on the VM:

```bash
watch -n5 'docker images | wc -l; docker system df'
```

### Check it worked

Once Ansible finishes, open Homepage at http://192.168.1.150:3002. If it loads, the VM, Docker, and the stack are up.

## Ansible

`ansible/` sets up and deploys the Docker VM (`logan@192.168.1.150`). Ansible runs from the Mac and SSHes into the VM. Nothing extra is installed on the VM.

- `setup.yml` does the base setup: packages, the Docker apt repo and engine, the docker group, `~/docker-volumes`, a clone of this repo (only if it's missing) and freeing port 53 for Pi-hole. It makes no netplan or firewall changes.
- `deploy.yml` runs `git pull` on the VM (with the same stash/pull/pop flow as by hand), then `docker compose -f compose.all.yml up -d --pull always --remove-orphans`.
- `site.yml` runs both.

The VM pulls from GitHub, so **push before you deploy**. Local uncommitted changes on the Mac are not deployed.

### One-time setup (on the Mac)

```bash
brew install ansible
```

```bash
cd ansible && ansible-galaxy collection install -r requirements.yml
```

```bash
ssh-copy-id logan@192.168.1.150
```

```bash
cd ansible && ansible homelab -m ping
```

### Commands

Run these from inside `ansible/`. `ansible.cfg` points at `inventory.ini`, so `-i` isn't needed. `-K` prompts for the VM's sudo password.

Deploy (pull + compose up):
```bash
ansible-playbook deploy.yml
```

Deploy only some services:
```bash
ansible-playbook deploy.yml -e '{"deploy_services":["gatus","caddy"]}'
```

Force recreate all containers (after editing a bind-mounted config such as the Caddyfile):
```bash
ansible-playbook deploy.yml -e recreate=always
```

Base setup only (a fresh VM, or re-checking an existing one):
```bash
ansible-playbook setup.yml -K
```

Full rebuild (setup + deploy):
```bash
ansible-playbook site.yml -K
```

Deploy a branch other than `main` (e.g. to test a PR before merging). The VM checkout must be on that branch first, or the deploy refuses to run:
```bash
ssh logan@192.168.1.150 'cd ~/homelab && git fetch origin && git checkout ansible'
ansible-playbook site.yml -e repo_branch=ansible
```
Switch the VM back with `git checkout main` after merging.

Dry run (shows what would change):
```bash
ansible-playbook setup.yml -K --check --diff
```

Syntax check:
```bash
ansible-playbook site.yml --syntax-check
```

Ad-hoc commands on the VM:
```bash
ansible homelab -a "docker ps"
```

```bash
ansible homelab -a "df -h /"
```

Still manual: `docker login -u dockedupstream` on the VM, and `.env` files that aren't in git (e.g. `docker/live-auction/.env`). The deploy fails if the VM checkout isn't on `main` or if `git stash pop` conflicts. When that happens, SSH in and fix it by hand.

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

## Running Jellyfin without docker compose

Standalone `docker run` equivalent of the `jellyfin` service in
`docker/docker-compose.yml`, for a brand new VM with nothing else on it -- no
compose stack, no Caddy, no user-defined networks. Jellyfin goes on the default
`bridge` network and is reached directly on port 8096.

```sh
docker pull jellyfin/jellyfin

# 1. Config/cache dirs. Safe to create empty -- Jellyfin populates them.
mkdir -p ~/docker-volumes/jellyfin/config ~/docker-volumes/jellyfin/cache

# 2. Media dirs. These must ALREADY hold the library (and, if they live on a
#    separate disk, that disk must already be mounted). A bind mount resolves
#    its source once, and docker silently creates a missing source as an empty
#    dir rather than failing, so the library would just show up empty.
ls /mnt/ssd/music /mnt/ssd/movies

# 3. Run it. Media is mounted read-only so Jellyfin can never modify the files.
docker run -d \
  --name jellyfin \
  --restart unless-stopped \
  -p 8096:8096/tcp \
  -p 7359:7359/udp \
  -e JELLYFIN_PublishedServerUrl=http://example.com \
  -v ~/docker-volumes/jellyfin/config:/config \
  -v ~/docker-volumes/jellyfin/cache:/cache \
  --mount type=bind,source=/mnt/ssd/music,target=/media/music,readonly \
  --mount type=bind,source=/mnt/ssd/movies,target=/media/movies,readonly \
  jellyfin/jellyfin
```

Then open the setup wizard at `http://<vm-ip>:8096/web/index.html#!/wizardstart.html`
and point the libraries at `/media/music` and `/media/movies`.

Notes:

- Bind Mounts are needed to pass folders from the host OS to the container OS
  whereas volumes are maintained by Docker and can be considered easier to
  backup and control by external programs. For a simple setup, it's considered
  easier to use Bind Mounts instead of volumes. Multiple media libraries can be
  bind mounted if needed:

  ```sh
  --mount type=bind,source=/mnt/ssd/music,target=/media/music,readonly \
  --mount type=bind,source=/mnt/ssd/movies,target=/media/movies,readonly \
  --mount type=bind,source=/mnt/ssd/shows,target=/media/shows,readonly
  ```

- `/mnt/ssd/music` and `/mnt/ssd/movies` are the values of `JELLYFIN_MUSIC_DIR` /
  `JELLYFIN_MOVIES_DIR` in `docker/.env` -- substitute your own paths. Add more
  libraries by repeating `--mount` with a different `target=/media/<name>`.
  Use absolute paths in `--mount`; the shell does not expand `~` there (it does
  for `-v`, which is why the config/cache lines can use it).
- `7359/udp` is client autodiscovery. Drop it if you only ever connect by
  entering the server address manually.
- Set `JELLYFIN_PublishedServerUrl` to the address clients actually use
  (e.g. `http://<vm-ip>:8096`); it is only an autodiscovery hint.
- Check on it with `docker logs -f jellyfin` and `docker ps --filter name=jellyfin`.

# Home Assistant

Reach the VM's console through Proxmox: **Datacenter > pve > console**

Once the community script is done running, go to **VM > Summary > Copy IP** and open that address in your browser to finish the installation.

## Creating the VM with Terraform

`terraform/homeassistant.tf` creates VM **160** running Home Assistant OS with 2 cores, 4 GiB RAM and a 32 GiB disk. It shares state with the docker VM, so set up `terraform/` first (see [Terraform](#terraform-1)).

RAM: docker-vm (20 GiB) + Home Assistant (4 GiB) = 24 of the host's 28 GiB, which leaves ~4 GiB for Proxmox. Don't start anything else big alongside them (see [VM sizing](#vm-sizing-do-this-when-creating-the-vm)).

```bash
cd terraform
terraform init
terraform plan   # should only add terraform_data.haos_image and proxmox_virtual_environment_vm.homeassistant
terraform apply
```

The first apply SSHes into the Proxmox host, then downloads and unpacks the HAOS image into `/var/lib/vz/template/iso/`.

HAOS ignores cloud-init, so it gets its IP from DHCP. The VM has a fixed MAC (`terraform output ha_mac_address`, default `BC:24:11:48:41:01`). Reserve an IP for that MAC on the router, then reboot the VM so it picks up the reserved address. Then open `http://<ip>:8123` to start onboarding.

To find the VM's current IP, ask the guest agent. The `192.168.1.x` address is the one you want; the rest are loopback, HA's internal Docker networks and IPv6. On first boot the agent needs a minute or two before it responds.

```bash
ssh root@192.168.1.98 "qm guest cmd 160 network-get-interfaces" | grep '"ip-address"'
```

Updates: update HA from its own UI (**Settings > System > Updates**). `haos_version` is only for fresh installs. Changing it re-downloads the image and **recreates the VM**, which wipes HA, so don't bump it on a running install.

## Adding a USB dongle (Zigbee / Z-Wave / Bluetooth)

1. Plug the dongle into the Proxmox host and find its `vendor:product` ID:

```bash
ssh root@192.168.1.98 lsusb
# Bus 001 Device 004: ID 10c4:ea60 Silicon Labs CP210x UART Bridge
```

2. Add a `usb` block to `proxmox_virtual_environment_vm.homeassistant` in `terraform/homeassistant.tf`, using your ID:

```hcl
  usb {
    host = "10c4:ea60"
    usb3 = false
  }
```

3. Run `terraform apply`, then restart the VM (`ssh root@192.168.1.98 "qm reboot 160"`). Without Terraform, the one-off equivalent is `qm set 160 -usb0 host=10c4:ea60`, but Terraform will flag that as drift unless the block is added.
4. HA should discover the device under **Settings > Devices & Services**.

## Backup

# Estimating Docker image download size

Figure out how much `docker compose -f docker/compose.all.yml up -d` would download from a clean Docker state, without pulling anything. Registries report the compressed size of every layer in the image manifest, and `docker manifest inspect` works without the daemon running.

```bash
# List every unique image in the stack
docker compose -f docker/compose.all.yml config --images | sort -u > /tmp/images.txt

# Fetch each image's manifest (registry metadata only — nothing is pulled)
mkdir -p /tmp/manifests
xargs -P 8 -I{} sh -c 'docker manifest inspect -v "{}" > "/tmp/manifests/$(echo {} | tr "/:@" "___").json"' < /tmp/images.txt

# Sum compressed layer sizes per platform, deduping layers shared across images
# (Docker only downloads each layer once)
for arch in arm64 amd64; do
  for f in /tmp/manifests/*.json; do
    jq -r --arg arch "$arch" '
      def entries: if type=="array" then . else [.] end;
      def mf: (.SchemaV2Manifest // .OCIManifest);
      [entries[] | select(mf != null)] as $all
      | ([$all[] | select(.Descriptor.platform.architecture==$arch and .Descriptor.platform.os=="linux")]) as $match
      | (if ($match|length)>0 then $match[0]
         elif ($all|length)==1 then $all[0]
         else ([$all[] | select(.Descriptor.platform.architecture=="amd64")] | .[0]) // $all[0]
         end) as $m
      | $m | mf.layers[]? | "\(.digest) \(.size)"
    ' "$f"
  done | sort -u -k1,1 | awk -v a="$arch" '{s+=$2} END {printf "%s: %.2f GB compressed download\n", a, s/1e9}'
done
```

As of Aug 2026 this comes to ~19 GB (arm64) / ~20 GB (amd64) compressed, roughly 48–50 GB on disk after extraction.

> **Note:** The 48–50 GB number only matters for disk space; it never crosses the network, since decompression happens locally after the download.
>
> One caveat on top of that ~20 GB: it's just the images. Anything the apps fetch at runtime — most notably any Ollama models you pull, plus small one-time downloads like Immich's ML models — is extra network traffic after startup.

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
- Add mini io [MinIO is in "maintenance mode" and is no longer accepting new changes or reviewing issues : r/selfhosted](https://www.reddit.com/r/selfhosted/comments/1pd97nq/minio_is_in_maintenance_mode_and_is_no_longer/)
- Add minIO alternative to docker compose: 

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



## Lost IPv4 Address on VM

---

### **Problem statement:**

The Proxmox VM unexpectedly lost its assigned IPv4 address (`10.0.0.32`), causing it to become inaccessible over the local network. Running `ip link show` revealed that the primary network interface (`ens18`) was active and "UP," but lacked an IP. The only visible addresses were a link-local IPv6 address (`fe80::...`) and several internal Docker bridge IPs (starting with `172.19.x.x`), which are used for container communication rather than external access.

### **Solution**

The issue was caused by a **DHCP lease expiration**. The VM’s background networking service failed to automatically renew its "permission" to use the `10.0.0.32` address from the router. By manually invoking the DHCP client, the VM was forced to send a fresh request to the router, which successfully reassigned the original IP address to the `ens18` interface.

---

### **Steps to fix it:**

* **Step 1: Identify the primary interface** Run `ip link show` or `ip addr` to identify which interface is the "real" virtual network card. Look for `ens*` or `eth*` naming — Proxmox VMs typically name hardware-attached NICs `ensXX` (where the number maps to the PCI slot in Proxmox, e.g. `ens18` = PCI slot 18) or `eth0` on older kernels. These represent the virtual NIC that Proxmox "plugged in" to the VM. In this instance, it was identified as `ens18`.
* **Step 2: Check for physical/virtual link** Verify that the interface shows `<BROADCAST,MULTICAST,UP,LOWER_UP>`, which confirms that Proxmox has successfully "plugged in" the virtual network cable to the VM.
* **Step 3: Force a DHCP renewal** Execute the following command to manually request an IP from the router:
```bash
sudo dhclient -v ens18

```

* **Step 4: Verify the restoration** Confirm the IP has returned by checking the interface details:
```bash
ip addr show ens18

```