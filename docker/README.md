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

    > **Note:** `10.0.0.98` was the IP set during install. The network has since moved to `192.168.1.x` and the host was re-IP'd to `192.168.1.98`, so the web UI is now **https://192.168.1.98:8006**. See [Changing the Proxmox Host IP](#changing-the-proxmox-host-ip-router--subnet-changed).
6. Setup Ubuntu VM for Docker
    1. Download Ubuntu Desktop ISO
    2. Datacenter > pve > local (pve) > ISO Images > Upload Ubuntu ISO file
    3. Create VM (check Advanced)
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
                - Disk size (GiB): 256
        - CPU (https://10.0.0.98:8006/pve-docs/chapter-qm.html#qm_cpu)
            - Sockets - 1
            - Cores - 8
        - Memory (https://10.0.0.98:8006/pve-docs/chapter-qm.html#qm_memory)
            - Memory (MiB) - 32768
            - Minimum Memory (MiB) - 32768
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
        4. `systemctl status qemu-guest-agent`
        5. `systemctl start qemu-guest-agent` if its not running
        6. Get IP Address from `pve > UbuntuServerForDockerServices > Summary`
    2. `sudo apt update`
    3. `sudo apt install openssh-server`
    4. `sudo systemctl status ssh`
9. SSH into server: `ssh logan@10.0.0.32`
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
    3. Install the Docker packages: `sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`
    4. Verify that Docker is running: `sudo systemctl status docker`. If it is not running, you might have to start it manually: `sudo systemctl start docker`
    5. Run `docker ps`
        - If you get error 'permission denied while trying to connect to the docker API at unix:///var/run/docker.sock, it is because the current user can’t access the docker engine, because the user doesn't have enough permissions to access the UNIX socket to communicate with the engine
            - You can use `sudo docker ps` but a better solution is here: https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user
                1. `sudo groupadd docker`
                2. `sudo usermod -aG docker $USER`
                3. Log out and log back in so that your group membership is re-evaluated
    8. Setup homelab repo
        1. `cd ~`
        2. Create Docker Volumes directory: `mkdir ~/docker-volumes`
        3. `cd homelab`
        4. `git clone https://github.com/loganphillips792/homelab.git`
        5. Update the IP Addresses in the PiHole DNS config to the IP Address of the Ubuntu VM: `sed -i 's/10\.0\.0\.32/10.0.0.214/g' docker/pihole/etc-dnsmasq.d/10-homelab.conf`
            - If these records are updated after the docker containers are already running, run `docker compose restart pihole` to restart pihole and apply the DNS changes
        6. Add .env file for live-auction (optional)

    5. `sudo apt install vim`

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
    8. `sudo netplan apply`

Now make sure /etc/resolv.conf uses what systemd-resolved generates:
    1. `sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf`
    2. `sudo systemctl restart systemd-resolved`

Check that the file has real DNS servers, not 127.0.0.53 or ::1: cat /etc/resolv.conf

Now we tell systemd-resolved to stop listening on 127.0.0.53/[::1], but it will still use the upstream DNS servers from netplan: `sudo sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf`

Restart: `sudo systemctl restart systemd-resolved`

Confirm port 53 is now free: `sudo ss -lunpt | grep :53 || echo "Port 53 is free ✅"`

9. Bring up Docker containers
    1. docker login -u dockedupstream
    2. `docker compose -f docker/compose.all.yml up -d`

10. `sudo ss -lunpt | grep :53` If you see docker-proxy, that means that PiHole has binded to port 53

11. To test that the Docker containers are properly running, go to `http://10.0.0.33:8082`


12. Switch the host to use Pi-Hole
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

## Changing the Proxmox Host IP (router / subnet changed)

> Done on 2026-08-10 when the home network moved from the Xfinity gateway's `10.0.0.x` to a router on `192.168.1.x`. The host went from `10.0.0.98` → `192.168.1.98`, so the web UI is now **https://192.168.1.98:8006**.

Proxmox uses a **static** IP (set during install, step 3.5 above). It does not adapt when the router or subnet changes — the host keeps its old address, ignores ARP requests for the new subnet, and becomes invisible to every device on the network. Scanning will not find it; you need the physical console.

### 1. Confirm the subnet actually changed (from the Mac)

```bash
ipconfig getifaddr en0   # Mac's current IP — if it's not on the same subnet as Proxmox, that's the problem

# Optional: sweep the subnet and list live devices (a misconfigured Proxmox won't appear)
for i in $(seq 1 254); do ping -c 1 -W 300 192.168.1.$i >/dev/null 2>&1 & done; wait
arp -a
```

If `ping <proxmox-ip>` fails and `arp -an | grep <proxmox-ip>` shows `(incomplete)`, the host isn't answering on this network at all — either the static IP is for the wrong subnet, or **the ethernet cable isn't plugged in** (that was half the problem last time).

### 2. Fix the static IP at the console

Plug a display + keyboard into the mini PC and log in as root.

1. Check current state: `ip a` (look for `vmbr0`) and `cat /etc/network/interfaces`
2. `nano /etc/network/interfaces` — in the `iface vmbr0 inet static` block, set the new address and gateway:

    ```
    address 192.168.1.98/24
    gateway 192.168.1.1
    ```

3. `nano /etc/hosts` — change the IP on the `pve` line, keep the hostname parts as-is (the `comcast.net` domain is just what the installer picked up from the ISP; Proxmox only cares that hostname → IP is consistent):

    ```
    192.168.1.98 pve.hsd1.il.comcast.net pve
    ```

4. `cat /etc/resolv.conf` — if `nameserver` points at the old subnet, change it to the new router IP (or keep `75.75.75.75`)
5. Apply: `ifreload -a` (or reboot)

### 3. Verify

On the mini PC:

- `ip a` shows `vmbr0` with the new address
- `ping -c 2 192.168.1.1` gets replies. If not, run `ip link show`: `NO-CARRIER` on the physical NIC (`enp1s0`) means a cable/port problem, not config. Also confirm the NIC line says `master vmbr0`.

On the Mac:

- `ping -c 2 192.168.1.98`
- Open **https://192.168.1.98:8006** (https, colon before the port; accept the self-signed cert warning)

### 4. Follow-ups after a subnet change

Everything else that referenced the old subnet is affected too:

- The Ubuntu VM is DHCP, so it gets a new IP automatically — find it in `pve > UbuntuServerForDockerServices > Summary`, then update whatever references the old one (ssh targets, Pi-hole DNS records in `docker/pihole/etc-dnsmasq.d/10-homelab.conf`, Mac DNS settings)
- Tailscale advertises the old subnet (`--advertise-routes=10.0.0.0/24`) and needs the new one
- Many IPs elsewhere in this README still say `10.0.0.x`

### Moving the network back to `10.0.0.x`

Possible — but only if you change the **router's** subnet too. The subnet isn't something the mini PC chooses; it has to match the network the router runs. Setting Proxmox back to `10.0.0.98` while the router stays on `192.168.1.x` just recreates the exact unreachable situation described above.

There's a real case for doing it, though: the whole homelab config assumes `10.0.0.x` — the Pi-hole DNS records, Tailscale's `--advertise-routes=10.0.0.0/24`, and dozens of IPs in this README. Moving the network back would make all of that correct again in one shot, instead of updating every reference to `192.168.1.x`.

How it would go:

1. **Change the router's LAN subnet.** Log into the router at http://192.168.1.1, find LAN/DHCP settings, and set the router's IP to `10.0.0.1` with subnet mask `255.255.255.0`, DHCP pool something like `10.0.0.10`–`10.0.0.200`. Save — the router reboots its network, and every device (Mac included) picks up a new `10.0.0.x` address when it reconnects. Most routers allow this; some ISP-locked gateways don't, so this is the one thing to verify.
2. **Revert Proxmox at the console** (or via the web UI's Shell *before* flipping the router): put `/etc/network/interfaces` back to `address 10.0.0.98/24`, `gateway 10.0.0.1`, put `10.0.0.98` back in `/etc/hosts`, then `ifreload -a`. Back to https://10.0.0.98:8006.
3. **Optional but worth it:** add DHCP reservations in the router so the Ubuntu VM and the Mac always get the same addresses — a changing DHCP IP is a recurring source of breakage elsewhere in this README (Navidrome section, `known_hosts` mismatches).

The trade-off: brief network disruption while every device re-DHCPs, and if anything else on the network was configured against `192.168.1.x` in the meantime, it moves too. But if the router cooperates, it's the cleaner end state for this repo.

## Allowing Claude to ssh into VM

Claude can run `ssh logan@10.0.0.214` itself once its key is installed on the VM, which lets it inspect containers, read logs, and run commands directly instead of dictating them back to you.

**Key auth is the only option — password auth cannot work.** Claude runs every command non-interactively, with no TTY attached, so SSH has nowhere to display a password prompt. It fails like this:

```
debug1: read_passphrase: can't open /dev/tty: Device not configured
Permission denied, please try again.
```

Those are failed *empty* attempts, not a wrong password. Don't debug the password — the prompt never reached you. This applies to the `!` prefix in Claude Code too: `! ssh-copy-id ...` fails the same way, because that also runs without a TTY.

Also: **don't paste the password into the chat.** It would be stored in the conversation transcript in plaintext and resent to the API on every subsequent turn. Key auth avoids the problem entirely.

### Setup

Do this in a **real terminal** (Terminal.app or iTerm — not Claude Code, which has no TTY).

1. Create a keypair, if you don't already have one:

    ```
    ssh-keygen -t ed25519
    ```

    This writes two files and grants no access by itself:

    - `~/.ssh/id_ed25519` — the **private** key. Stays on the Mac, never leaves it, never gets shared.
    - `~/.ssh/id_ed25519.pub` — the **public** key. Safe to hand out; this is the half that goes on servers.

    > **Skip this step if `~/.ssh/id_ed25519` already exists.** `ssh-keygen` defaults to that exact path. It prompts before overwriting, but accepting destroys the old private key permanently and locks you out of every server trusting it. Check with `ls ~/.ssh/` first.

2. Install the public key on the VM:

    ```
    ssh-copy-id -i ~/.ssh/id_ed25519.pub logan@10.0.0.214
    ```

    This prompts for the account password — the last time you type it. Pass `-i` explicitly: without it, `ssh-copy-id` installs whatever key it finds first (e.g. `id_rsa_terraform.pub`), which probably isn't the one you want.

3. Verify it works without a TTY, the same way Claude will call it:

    ```
    ssh -o BatchMode=yes logan@10.0.0.214 hostname
    ```

    `BatchMode=yes` disables all interactive prompts, so this fails immediately if key auth is broken rather than silently falling back to a password prompt that Claude could never answer.

`ssh logan@10.0.0.214` now works with no password, and Claude can get in too.

To confirm the key actually landed on the VM, compare fingerprints — clearer than eyeballing base64:

```
ssh-keygen -lf ~/.ssh/id_ed25519.pub
ssh logan@10.0.0.214 'ssh-keygen -lf ~/.ssh/authorized_keys'
```

The first prints your key's fingerprint; the second prints one line per installed key. Yours should appear in the list.

### What `authorized_keys` is

`~/.ssh/authorized_keys` **on the VM** is the guest list: a plain text file, one public key per line. Any client that can prove it holds the matching private key gets let in as that user. That's the whole mechanism.

`ssh-copy-id` just appends a line to it. You can do the same by hand — paste the contents of your `.pub` file onto a new line — and that's the fallback if SSH is locked out but you have console access via Proxmox.

The login itself never transmits the private key. The server sends a challenge, the client signs it with the private key, the server verifies the signature against the public keys in `authorized_keys`. Nothing secret crosses the wire, which is why this is safer than a password.

Consequences worth internalizing:

- **The VM's `authorized_keys` is independent of your Mac.** Deleting local keys doesn't revoke anything — the line stays until you edit the file on the VM. Remove stale entries there when you rotate keys.
- **`.pub` files on the Mac are disposable.** A modern OpenSSH private key file has its public key embedded, so SSH derives what it needs and auth works fine without them. Regenerate one anytime with `ssh-keygen -y -f ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.pub`.
- **The private key is the irreplaceable half.** It's not derivable from anything. Lose it with no backup and you're back to password auth to re-enroll — or, on a box with `PasswordAuthentication no`, to the Proxmox console.

### Back up the private key

The file to back up is `~/.ssh/id_ed25519` — the one **without** the `.pub` extension. Permissions tell you which is which:

```
.rw-------  432  id_ed25519       <- secret, 600, owner-only. Back this up.
.rw-r--r--  114  id_ed25519.pub   <- public, 644, world-readable. Disposable.
```

(SSH refuses to use a private key with loose permissions, which doubles as a sanity check.)

To back it up, copy the file somewhere that survives this Mac dying:

```
cat ~/.ssh/id_ed25519
```

Paste the whole block — `-----BEGIN OPENSSH PRIVATE KEY-----` through `-----END OPENSSH PRIVATE KEY-----` — into 1Password/Bitwarden as a secure note. An encrypted USB drive or another machine you control works too. **Not** iCloud Drive or Dropbox in plaintext, not a git repo, not an AI chat window.

To restore: write the file back to `~/.ssh/id_ed25519` and fix the permissions, or SSH will reject it:

```
chmod 600 ~/.ssh/id_ed25519
```

This is cheap insurance now and essential later. Today the VM still accepts `PasswordAuthentication`, so losing the key is a five-minute re-enroll. Turning password auth off is the standard hardening step for an SSH box — and the moment you do, this file is the only way in short of the Proxmox console.

### Troubleshooting

Run `ssh -v logan@10.0.0.214` and read the trace:

- `Authentications that can continue: publickey,password` — the server accepts keys; the key just isn't in `~/.ssh/authorized_keys` on the VM yet.
- `Offering public key: ... ` followed by the same line again — that key was rejected. Re-run `ssh-copy-id` with the right `-i`.
- `read_passphrase: can't open /dev/tty` — no TTY, see above. You're not in a real terminal.
- If the VM's IP changed, `known_hosts` will complain about a host key mismatch. The IP is DHCP; check the current one in `pve > UbuntuServerForDockerServices > Summary`.

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

### Applying Pi-hole config changes

Pi-hole runs as a Docker container on your server, with `./pihole/etc-dnsmasq.d` bind-mounted to `/etc/dnsmasq.d` (docker/docker-compose.yml:197). Since it's a bind mount, the container already sees your edited file — you just need the DNS server inside to re-read it.

On the server, either of these works:

```bash
# restart just the DNS resolver inside the container (fast, no container downtime)
docker exec pihole pihole restartdns

# or restart the whole container
docker restart pihole
```

Or with docker compose (run from the `docker/` directory, or add `-f docker/docker-compose.yml` from repo root):

```bash
# restart just the DNS resolver inside the container
docker compose exec pihole pihole restartdns

# or restart the whole container
docker compose restart pihole
```

One nuance: `docker compose restart` only restarts the container — it does **not** pick up changes to `docker-compose.yml` itself (env vars, ports, volumes). For those you'd need `docker compose up -d pihole`, which recreates the container. For conf file edits, `restart` (or the `exec ... restartdns`) is all you need.

- After making changes to prometheus: `docker compose -f docker/docker-compose.yml restart prometheus`

- docker compose -f docker/docker-compose.yml up caddy pihole cronmaster -d 

- `docker compose -f docker/docker-compose.yml up -d cadvisor pihole caddy prometheus loki alloy grafana homepage`

- Use `docker stats` command to see container usage

pveversion --verbose

`docker system df -v | grep -i "loki"`


`ssh logan@10.0.0.32 "cd /home/logan/homelab/docker && docker compose pull ollama && docker compose up -d ollama"`



# Backup strategy

- Backup: `./docker/backup-remote-volumes.sh`
- Restore: `./restore-docker-backup.sh <tar-file-name>`


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

  - Datastore > Add Datastore
     - Name: backup
     - Datastore Type: local
     - Backing Path: /backups
     - GC Schedule: Daily
     - Prune Schedule: daily

- To run backup job
  - Copy Fingerprint from PBS
  - Go to Proxmox admin
    - Datacenter > Storage > Add Storage > Proxmox Backup Server
      - ID: Backup-storage
      - Server: 10.0.0.43 (IP of PBS)
      - Username: root@pam
      - Password: password
      - Datastore: backup (name of the datastore you created on PBS)
      - Fingerprint: paste the fingerprint from PBS
      - Mark as enabled
      - Save
  - Go to PVE that you want to backup
  - Backup > Backup now
    - Storage: backup-storage
  - `ssh root@10.0.0.43 "ls /backups/vm/"`

# Deploying

1. On the machine you want to access services from, set DNS servers (in this order):
   - `10.0.0.32`
   - `75.75.75.75`
   - `1.1.1.1`

2. SSH into the server: `ssh logan@10.0.0.32`

3. Pull latest changes:
```
git stash
git pull
git stash pop
```

4. Deploy all services:
```
docker compose -f docker/compose.all.yml up -d --pull always
```

or just services that need to be restarted: `docker compose restart alloy prometheus grafana`

5. Flush DNS cache on your local machine (macOS):
```
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
```

6. Access `http://grafana.homelab` to verify services are running

# Commands

- To pull all new versions of images and run all services:
```
docker compose -f docker/compose.all.yml up -d --pull always
```

- Start a single service: `docker compose -f docker/compose.all.yml up gatus -d`

- Start specific services: `docker compose -f docker/compose.all.yml up gatus prometheus -d`

- Restart a service: `docker compose -f docker/compose.all.yml restart gatus`

- Run specific services: `docker compose -f docker/docker-compose.yml up -d --build caddy pihole`

- `docker compose -f docker/docker-compose.yml restart caddy` - restart specific service

- `docker compose -f docker/docker-compose.yml up -d --force-recreate loki grafana alloy n8n`

## Restart vs recreate

`docker compose restart` stops and starts the existing containers without recreating them — fast, but it won't pick up changes to your compose file or a new image.

```bash
# restart just one service
docker compose restart web

# recreate containers so compose-file changes take effect
docker compose up -d --force-recreate

# full teardown (removes containers/network) and rebuild
docker compose down && docker compose up -d --build
```

Backup N8N Database: `ssh logan@10.0.0.33 'cd ~/homelab/docker && docker compose exec -T postgres pg_dump -U changeUser n8n' > n8n-postgres-backup_$(date +%F).sql`
Backup N8N Volume: `ssh logan@10.0.0.33 'docker run --rm -v n8n_storage:/volume alpine sh -c "cd /volume && tar -czf - ."' > n8n-storage-backup.tar.gz`

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
- DNS of the mac has to point to the MAC itself (10.0.0.32) in my case
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
- DNS records: Pi‑hole serves .homelab hostnames and resolves them to your host IP (e.g., 10.0.0.32) via pihole/etc-pihole/hosts/
custom.list and 02-local.conf. Clients using Pi‑hole as DNS will resolve *.homelab to the host.
- End‑to‑end flow: Client requests pihole.homelab → Pi‑hole DNS returns 10.0.0.32 → connection hits Caddy on :80/:443 → Caddy
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

### Backup / Restore

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

#### Full backup (works for MariaDB)

Stop first so MariaDB isn't mid-write — this gives a consistent snapshot:

```
cd ~/repos/homelab/docker
docker compose stop uptime-kuma
docker run --rm \
  -v docker_uptime_kuma_data:/data \
  -v ~/backups:/backup \
  alpine tar czf /backup/uptime-kuma-$(date +%F).tar.gz -C /data .
docker compose start uptime-kuma
```

Restore:

```
docker compose stop uptime-kuma
docker run --rm \
  -v docker_uptime_kuma_data:/data \
  -v ~/backups:/backup \
  alpine sh -c "rm -rf /data/* && tar xzf /backup/uptime-kuma-2026-06-19.tar.gz -C /data"
docker compose start uptime-kuma
```

### Inspecting the volume on the host

```
docker volume ls
docker inspect volume docker_uptime_kuma_data
```

Shows the mountpoint on the host system: `"Mountpoint": "/var/lib/docker/volumes/docker_uptime_kuma_data/_data"`

On the host system: `sudo ls /var/lib/docker/volumes/docker_uptime_kuma_data/_data`

### Full reset (wipe all data)

This setup (`docker/docker-compose.yml`) uses container `uptime-kuma` with named volume `uptime_kuma_data`. A complete reset means wiping that volume — all monitors, history, and settings are gone.

```
cd ~/repos/homelab/docker

# Stop and remove the container
docker compose stop uptime-kuma
docker compose rm -f uptime-kuma

# Delete the data volume (this is the actual "reset" — wipes everything)
docker volume rm docker_uptime_kuma_data

# Recreate fresh
docker compose up -d uptime-kuma
```

Notes:
- The volume is named `docker_uptime_kuma_data` because Compose prefixes it with the project name (the `docker/` directory). Confirm with `docker volume ls | grep uptime_kuma` if `docker volume rm` complains.
- If the volume won't delete ("volume is in use"), the container wasn't removed yet — rerun the `rm -f` step.

One-liner equivalent:

```
cd ~/repos/homelab/docker && docker compose rm -fsv uptime-kuma && docker volume rm docker_uptime_kuma_data && docker compose up -d uptime-kuma
```

`rm -fsv` stops the container and removes its anonymous volumes, but the named volume must still be removed explicitly with `docker volume rm` — that's the step that actually clears Uptime Kuma's state.

## Tailscale

**Note:** When updating the auth token (or any env var), use `docker compose up -d tailscale`, not `docker compose restart tailscale`. `restart` reuses the existing container config and won't pick up the new value. `up -d` recreates the container with the updated config.

1. Create account at https://login.tailscale.com/admin
2. Generate auth key and add to env variable in `docker-compose.yml`
3. `docker compose up --build tailscale`
4. Go to `https://login.tailscale.com/admin/machines` and you should see the machine
5. Download Tailscale onto machines and log in to add them to tail net


To ssh into VM:

1. Connect machine to the tailnet
2. `ssh ssh logan@<ip_of_vm>`

### Flow

- Pre reqs
  - Remote device is logged into Tailscale
  - Remote device uses pi-hole as its DNS server (either via Tailscale's MagicDNS settings or manually configured)
  - Accept routes must be enabled on your remote device to use the advertised 10.0.0.0/24 subnet


1. Request http://grafana.homelab outside of home network
2. Tailscale VPN: Encrypted tunnel to the home network. Your device gets access to 10.0.0.0/24
3. Tailscale Container: Acts as subnet router via --advertise-routes=10.0.0.0/24 . Traffic enters your home LAN   
4. Pi-Hole DNS: Resolves grafana.homelab → 10.0.0.32 (Your home server's IP)
5. Caddy (Reverse Proxy): Listening on 10.0.0.32:80 Matches Host header "grafana.homelab" Routes to `grafana:3000` on `main-network`


- Subnet router that advertises 10.0.0.0/24 to your Tailscale network, allowing remote devices to reach your
  home LAN
- Pihole - DNS server that resolves *.homelab domains to 10.0.0.32 (your Docker host)
- Caddy - Reverse proxy listening on ports 80/443, routes requests based on hostname to the appropriate container
- `main-network` connects most services; Caddy bridges default, main-network, and kafka-network


## Test Postgres

A standalone Postgres instance (`test-db`, container `postgres_db`, image `postgres:16`) defined in `docker/docker-compose.yml`. Nothing else in the stack uses it — it is not on `main-network` and no other service depends on it. It exists purely as a scratch database for experimenting with SQL, clients, and backup tooling.

| Setting | Value |
|-|-|
| Host | `localhost:5432` |
| User | `testuser` |
| Password | `testpassword` |
| Database | `test_database` |

On first start it runs `docker/test-db-init.sql` (mounted at `/docker-entrypoint-initdb.d/10-test-table.sql`), which creates a sample `test-table`. Data lives in the `postgres_test_data` volume.

- `docker compose -f docker/docker-compose.yml up -d test-db` - start it
- `docker compose -f docker/docker-compose.yml exec -T test-db psql -U testuser -d test_database -f docker-entrypoint-initdb.d/10-test-table.sql` - if you have to rerun the SQL script
- `docker exec -it postgres_db psql -U testuser -d test_database -c 'SELECT * FROM "test-table";'`

### Creating a database and importing CSV data

`test-table` has a handful of rows, which is too small for anything interesting — the planner will always pick a sequential scan, and a backup finishes before you can watch it. For a realistic dataset, NYC OpenData publishes [Citywide Payroll Data (Fiscal Year)](https://data.cityofnewyork.us/City-Government/Citywide-Payroll-Data-Fiscal-Year-/k397-673e/about_data): every city employee's salary and overtime, **6.78 million rows**, free and no API key.

#### 1. Create the database

Keep it out of `test_database` so it's easy to throw away:

```
docker exec -it postgres_db createdb -U testuser nyc_payroll
```

`createdb` is a thin wrapper around `CREATE DATABASE`; `dropdb -U testuser nyc_payroll` reverses it.

#### 2. Download the CSV

```
curl -L -o ~/nyc-payroll.csv \
  'https://data.cityofnewyork.us/api/views/k397-673e/rows.csv?accessType=DOWNLOAD'
```

That's the full export — close to a gigabyte, so give it a few minutes. To iterate faster, the SODA API serves a subset instead:

```
curl -L -o ~/nyc-payroll.csv \
  'https://data.cityofnewyork.us/resource/k397-673e.csv?$limit=50000'
```

The two endpoints differ, though both load fine against the table below: the bulk export writes display-name headers (`Fiscal Year,Payroll Number,…`) and US-format dates (`02/04/2013`), while the SODA API writes field-name headers (`fiscal_year,…`) and ISO timestamps (`2013-02-04T00:00:00.000`). `COPY` skips the header row either way, and a `date` column accepts the ISO timestamps and truncates the time.

#### 3. Create the table

Column order here must match the CSV's column order exactly — `COPY` matches by position, not by name, and the header row is skipped rather than read:

```sql
CREATE TABLE payroll (
  fiscal_year                 smallint,
  payroll_number              integer,
  agency_name                 text,
  last_name                   text,
  first_name                  text,
  mid_init                    text,
  agency_start_date           date,
  work_location_borough       text,
  title_description           text,
  leave_status_as_of_june_30  text,
  base_salary                 numeric(12,2),
  pay_basis                   text,
  regular_hours               numeric(10,2),
  regular_gross_paid          numeric(12,2),
  ot_hours                    numeric(10,2),
  total_ot_paid               numeric(12,2),
  total_other_pay             numeric(12,2)
);
```

Pipe it in as a heredoc:

```
docker exec -i postgres_db psql -U testuser -d nyc_payroll <<'EOF'
CREATE TABLE payroll (
  fiscal_year smallint, payroll_number integer, agency_name text,
  last_name text, first_name text, mid_init text, agency_start_date date,
  work_location_borough text, title_description text,
  leave_status_as_of_june_30 text, base_salary numeric(12,2), pay_basis text,
  regular_hours numeric(10,2), regular_gross_paid numeric(12,2),
  ot_hours numeric(10,2), total_ot_paid numeric(12,2), total_other_pay numeric(12,2)
);
EOF
```

The money columns are `numeric`, not `float8` — binary floating point can't represent most decimal amounts exactly, so sums drift. Use `numeric` for anything you'd put in a report.

#### 4. Load it

`COPY … FROM STDIN` reads from the client connection, so the file never has to exist inside the container — `docker exec -i` pipes it straight in:

```
docker exec -i postgres_db psql -U testuser -d nyc_payroll \
  -c "COPY payroll FROM STDIN WITH (FORMAT csv, HEADER true)" < ~/nyc-payroll.csv
```

Expect a couple of minutes for the full file. It prints `COPY 6775830` when it lands.

The `MM/DD/YYYY` dates parse without any extra work because Postgres defaults to `DateStyle = 'ISO, MDY'`. Confirm with `SHOW DateStyle;` if a date column errors — on an `DMY` server you'd need `SET DateStyle = 'ISO, MDY';` first.

Empty fields become `NULL` automatically under `FORMAT csv`. If `COPY` aborts partway, it rolls back the whole load — you never end up with a half-populated table.

#### 5. Analyze, then look around

Run `ANALYZE` first. `COPY` does not update planner statistics, so until it runs the planner thinks the table is empty and will pick bad plans:

```
docker exec -it postgres_db psql -U testuser -d nyc_payroll -c 'ANALYZE payroll;'
```

```
docker exec -it postgres_db psql -U testuser -d nyc_payroll -c \
  'SELECT agency_name, count(*), round(avg(base_salary)) AS avg_base
     FROM payroll WHERE fiscal_year = 2025
     GROUP BY agency_name ORDER BY count(*) DESC LIMIT 10;'
```

```
docker exec -it postgres_db psql -U testuser -d nyc_payroll -c \
  'SELECT title_description, round(sum(total_ot_paid)) AS ot
     FROM payroll WHERE fiscal_year = 2025
     GROUP BY title_description ORDER BY ot DESC LIMIT 10;'
```

Useful `psql` meta-commands once you're inside an interactive session (`docker exec -it postgres_db psql -U testuser -d nyc_payroll`): `\dt` lists tables, `\d payroll` describes one, `\dt+` adds on-disk size, `\timing` reports how long each query took, and `\l` lists databases.

#### Reloading

`COPY` appends. Running it a second time doubles the table rather than replacing it, and the row count is the only thing that tells you — there's no primary key here to reject duplicates. Truncate first:

```
docker exec -it postgres_db psql -U testuser -d nyc_payroll -c 'TRUNCATE payroll;'
```

This is the usual reason for a surprising `count(*)`. The other is the `$limit` in the download URL: if you took the fast-iteration route, `COPY` reports `COPY 50000` because the file genuinely has 50,000 rows. Re-download from the bulk export URL for the full 6.78M, then truncate and reload.

### Queries

Note the quoting throughout: `test-table` has a hyphen, so it needs SQL double quotes, which means the whole statement has to be wrapped in shell single quotes.

`EXPLAIN` prefixes the statement and shows the planner's *estimate* without running the query:

```
docker exec -it postgres_db psql -U testuser -d test_database -c 'EXPLAIN SELECT * FROM "test-table";'
```

To actually execute it and get real timings and row counts:

```
docker exec -it postgres_db psql -U testuser -d test_database -c 'EXPLAIN ANALYZE SELECT * FROM "test-table";'
```

The fuller form, with the options that matter most:

```
docker exec -it postgres_db psql -U testuser -d test_database -c 'EXPLAIN (ANALYZE, BUFFERS, VERBOSE) SELECT * FROM "test-table";'
```

- `ANALYZE` — really runs it; adds `actual time` and `actual rows` next to the estimates. A big gap between estimated and actual rows is usually the thing worth chasing.
- `BUFFERS` — shows blocks read from shared buffers vs disk, so you can tell whether "slow" means cache misses.
- `VERBOSE` — lists output columns and schema-qualified names.

> **`EXPLAIN ANALYZE` executes the statement.** Harmless on a `SELECT`, but on an `INSERT`/`UPDATE`/`DELETE` it really writes. Wrap those in a transaction you throw away:
>
> ```
> docker exec -it postgres_db psql -U testuser -d test_database -c 'BEGIN; EXPLAIN ANALYZE DELETE FROM "test-table"; ROLLBACK;'
> ```

On `test-table` the plan will be a `Seq Scan` no matter what you do — with a handful of rows the planner correctly decides an index isn't worth the indirection, so the output only shows you the mechanics. The `payroll` table loaded above is where this gets interesting. Filter it, then add an index and run the same `EXPLAIN ANALYZE` again:

```
docker exec -it postgres_db psql -U testuser -d nyc_payroll -c \
  "EXPLAIN ANALYZE SELECT * FROM payroll WHERE agency_name = 'POLICE DEPARTMENT' AND fiscal_year = 2025;"

docker exec -it postgres_db psql -U testuser -d nyc_payroll -c \
  'CREATE INDEX idx_payroll_agency_year ON payroll (agency_name, fiscal_year);'
```

The first run is a `Parallel Seq Scan` across all 6.78M rows; after the index it becomes a `Bitmap Index Scan`, usually a couple of orders of magnitude faster. Compare the `actual time` values rather than the estimated `cost` — cost is in arbitrary planner units and only meaningful relative to other plans.

### Backup / Restore with the built-in CLI tools

Before reaching for pgBackRest, note that Postgres ships its own backup tools and they're already inside the `postgres:16` image — no `apt-get`, no config file, no stanza. These are **logical** backups: `pg_dump` produces a stream of SQL (or a compressed archive of it) that recreates the schema and data, rather than copying the data files.

That difference decides which tool you want:

| | `pg_dump` / `pg_restore` | pgBackRest |
|-|-|-|
| What it copies | SQL statements (logical) | data files + WAL (physical) |
| Setup | none, already installed | apt install, config, stanza, WAL archiving |
| Cluster downtime | none, runs against a live DB | restore needs Postgres stopped |
| Point-in-time recovery | no | yes |
| Cross-version / cross-arch restore | yes | no, same major version only |
| Speed on a large DB | slow, rebuilds by replaying SQL | fast, incremental |

For a scratch database this size, `pg_dump` is the right default.

> **Don't use `docker exec -t` when redirecting a dump to a file.** A TTY translates `\n` to `\r\n`, which silently corrupts the output — plain SQL dumps get subtly mangled and custom-format archives become unrestorable. Use `docker exec` with no flags for dumping and `docker exec -i` for restoring, exactly as written below.

#### Dump

Plain SQL, the readable format — you can open it in an editor and see the `CREATE TABLE` / `COPY` statements:

```
docker exec postgres_db pg_dump -U testuser -d test_database > ~/test_database.sql
```

Custom format (`-Fc`) is the better default for anything real. It's compressed, and `pg_restore` can then restore selectively, reorder, or run in parallel:

```
docker exec postgres_db pg_dump -U testuser -d test_database -Fc > ~/test_database.dump
```

A single table — note the doubled quoting, since `test-table` has a hyphen and needs SQL double quotes that must survive the shell:

```
docker exec postgres_db pg_dump -U testuser -d test_database -Fc -t '"test-table"' > ~/test_table.dump
```

Schema only (`-s`) or data only (`-a`) are useful for diffing structure or reloading rows into an existing schema:

```
docker exec postgres_db pg_dump -U testuser -d test_database -s > ~/schema.sql
```

`pg_dump` covers one database and does **not** include roles, passwords or other cluster-wide objects. Those come from `pg_dumpall`:

```
docker exec postgres_db pg_dumpall -U testuser --globals-only > ~/globals.sql
```

#### Restore

Plain SQL dumps are just SQL, so they go back through `psql`:

```
docker exec -i postgres_db psql -U testuser -d test_database < ~/test_database.sql
```

Custom-format dumps go through `pg_restore`. `--clean --if-exists` drops each object before recreating it, which makes the restore repeatable instead of failing on "already exists":

```
docker exec -i postgres_db pg_restore -U testuser -d test_database --clean --if-exists < ~/test_database.dump
```

Useful flags: `-j 4` restores in parallel (custom/directory formats only), `--no-owner` ignores ownership when restoring as a different role, and `-t '"test-table"'` pulls a single table out of a full dump.

To restore into a clean database instead of over the top of the existing one:

```
docker exec -i postgres_db dropdb -U testuser --if-exists restore_test
docker exec -i postgres_db createdb -U testuser restore_test
docker exec -i postgres_db pg_restore -U testuser -d restore_test < ~/test_database.dump
```

#### Round trip

Same proof as the pgBackRest section below — destroy the data and get it back — but with no cluster restart and no downtime:

```
# 1. Dump
docker exec postgres_db pg_dump -U testuser -d test_database -Fc > ~/test_database.dump

# 2. Destroy
docker exec -it postgres_db psql -U testuser -d test_database -c 'DROP TABLE "test-table";'

# 3. Restore
docker exec -i postgres_db pg_restore -U testuser -d test_database --clean --if-exists < ~/test_database.dump

# 4. Confirm
docker exec -it postgres_db psql -U testuser -d test_database -c 'SELECT count(*) FROM "test-table";'
```

Notes:

- The dump is a **consistent snapshot**. `pg_dump` runs in a repeatable-read transaction, so it captures the database as of the moment it started even while writes continue — no need to stop anything.
- It does not block writers, but it does hold a lock that blocks `ALTER`/`DROP` on the tables it's reading for the duration.
- Running the tools inside the container sidesteps client/server version mismatches. If you'd rather use a Homebrew `pg_dump` against `localhost:5432`, the client must be the **same or newer** major version than the server, or it refuses with a version-mismatch error.
- Dumps land on the host via shell redirection, so they're outside the `postgres_test_data` volume — which is the point. A backup inside the volume you're protecting isn't a backup.

### pgBackRest

[pgBackRest](https://pgbackrest.org/) is a backup and restore tool for Postgres — full/differential/incremental backups, WAL archiving, and point-in-time recovery. The test Postgres above is the target used to try it out.

#### macOS

```
brew install pgbackrest
```

This gives you the CLI locally, which is handy for reading docs/help and for inspecting a repo that lives on the Mac. It **cannot** back up `test-db` directly: pgBackRest needs filesystem access to `PGDATA`, and that lives inside the `postgres_test_data` Docker volume (i.e. inside the Docker Desktop VM, not on the Mac filesystem). So the steps below run pgBackRest *inside* the Postgres container.

#### Setup (inside the container)

1. Give the backup repo a home that survives container recreation. In `docker/docker-compose.yml`, add to the `test-db` service and to the top-level `volumes:` block:

```yaml
  test-db:
    volumes:
      - postgres_test_data:/var/lib/postgresql/data
      - ./test-db-init.sql:/docker-entrypoint-initdb.d/10-test-table.sql:ro
      - pgbackrest_repo:/var/lib/pgbackrest   # pgBackRest backup repository

volumes:
  pgbackrest_repo:
```

Then `docker compose -f docker/docker-compose.yml up -d test-db`.

2. Install pgBackRest in the container (the official `postgres:16` image is Debian and already has the PGDG apt repo configured). Note this is lost if the container is recreated — bake it into a small `Dockerfile` if you want it permanent:

```
docker exec -u root -it postgres_db bash -c "apt-get update && apt-get install -y pgbackrest"
```

3. Create the repo directory and config, owned by the `postgres` user:

```
docker exec -u root -it postgres_db bash -c "mkdir -p /var/lib/pgbackrest /etc/pgbackrest /var/log/pgbackrest && chown -R postgres:postgres /var/lib/pgbackrest /etc/pgbackrest /var/log/pgbackrest"

docker exec -u root -it postgres_db bash -c "cat > /etc/pgbackrest/pgbackrest.conf <<'EOF'
[global]
repo1-path=/var/lib/pgbackrest
repo1-retention-full=2
log-level-console=info
start-fast=y

[test]
pg1-path=/var/lib/postgresql/data
EOF
chown postgres:postgres /etc/pgbackrest/pgbackrest.conf"
```

`test` is the *stanza* name — pgBackRest's label for one Postgres cluster and its repo. Every command below takes `--stanza=test`.

4. Turn on WAL archiving so pgBackRest can do point-in-time recovery, then restart Postgres (`archive_mode` requires a restart):

```
docker exec -u postgres -it postgres_db psql -U testuser -d test_database -c "ALTER SYSTEM SET archive_mode = on;"
docker exec -u postgres -it postgres_db psql -U testuser -d test_database -c "ALTER SYSTEM SET archive_command = 'pgbackrest --stanza=test archive-push %p';"
docker exec -u postgres -it postgres_db psql -U testuser -d test_database -c "ALTER SYSTEM SET wal_level = replica;"

docker compose -f docker/docker-compose.yml restart test-db
```

5. Initialize the stanza and verify archiving works end to end:

```
docker exec -u postgres -it postgres_db pgbackrest --stanza=test stanza-create
docker exec -u postgres -it postgres_db pgbackrest --stanza=test check
```

`check` forces a WAL switch and confirms the archive landed in the repo. If it fails here, the backup will fail too.

#### Backup example

Take a full backup:

```
docker exec -u postgres -it postgres_db pgbackrest --stanza=test --type=full backup
```

Then an incremental one (only changed blocks since the last backup — much faster):

```
docker exec -u postgres -it postgres_db pgbackrest --stanza=test --type=incr backup
```

List what's in the repo:

```
docker exec -u postgres -it postgres_db pgbackrest --stanza=test info
```

```
stanza: test
    status: ok
    cipher: none

    db (current)
        wal archive min/max (16): 000000010000000000000002/000000010000000000000004

        full backup: 20260722-120000F
            timestamp start/stop: 2026-07-22 12:00:00 / 2026-07-22 12:00:06
            database size: 29.2MB, database backup size: 29.2MB
            repo1: backup set size: 3.8MB, backup size: 3.8MB

        incr backup: 20260722-120000F_20260722-121500I
            ...
```

#### Restore example

Prove it works by destroying data and getting it back:

```
# 1. Note what's there, then drop it
docker exec -it postgres_db psql -U testuser -d test_database -c 'SELECT count(*) FROM "test-table";'
docker exec -it postgres_db psql -U testuser -d test_database -c 'DROP TABLE "test-table";'

# 2. Stop Postgres — restore needs the cluster shut down
docker compose -f docker/docker-compose.yml stop test-db
docker compose -f docker/docker-compose.yml start test-db
docker exec -u root -it postgres_db bash -c "pg_ctlcluster 16 main stop || true"
```

Since the container's entrypoint *is* Postgres, the practical move is to run the restore from a throwaway container that mounts the same volumes:

```
docker run --rm -it \
  -v homelab_postgres_test_data:/var/lib/postgresql/data \
  -v homelab_pgbackrest_repo:/var/lib/pgbackrest \
  --entrypoint bash postgres:16 -c "
    apt-get update -qq && apt-get install -y -qq pgbackrest &&
    printf '[global]\nrepo1-path=/var/lib/pgbackrest\n\n[test]\npg1-path=/var/lib/postgresql/data\n' > /etc/pgbackrest/pgbackrest.conf &&
    su postgres -c 'pgbackrest --stanza=test --delta restore'"
```

(Check the real volume names with `docker volume ls` — Compose prefixes them with the project name.)

Then bring it back up and confirm the table is there again:

```
docker compose -f docker/docker-compose.yml up -d test-db
docker exec -it postgres_db psql -U testuser -d test_database -c 'SELECT count(*) FROM "test-table";'
```

`--delta` only rewrites files that differ from the backup, so repeat restores are quick. For point-in-time recovery add `--type=time --target="2026-07-22 12:10:00"`.

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

## Redis Pub/Sub

```
cd docker/redis-pubsub && docker compose up -d     # or: docker compose -f docker/compose.all.yml up -d redis-pubsub
```

Two terminals to see pub/sub in action:

```
# terminal 1 — subscriber
docker exec -it redis-pubsub redis-cli -a changeMe SUBSCRIBE news
# terminal 2 — publisher
docker exec -it redis-pubsub redis-cli -a changeMe PUBLISH news "hello"
```

`PSUBSCRIBE "news.*"` works for pattern matching. Same commands are in the compose file header for reference.

One thing to note about pub/sub while you're messing around: if no client is subscribed at publish time, the message is simply dropped — there's no backlog or replay. That's the key difference from streams, and exactly why there's no persistence here.

### Driving pub/sub from RedisInsight

This stack ships its own dedicated RedisInsight (`redis-pubsub-insight`), separate from the main `redisinsight` service and scoped to just this stack. It's a nicer way to watch pub/sub than two `redis-cli` terminals — its **Pub/Sub** panel subscribes live and you can publish from the same screen. The connection to `redis-pubsub` is pre-seeded, so there's nothing to configure.

Standalone it publishes on host port `5541` (the main redisinsight uses `5540`), so reach it at http://localhost:5541. Open the pre-seeded database → **Pub/Sub** tab to subscribe, then run a Workbench `PUBLISH news "hello"` (or the CLI) to see messages arrive.

## Umami

Username: admin
Password: umami

## Ollama

- `docker exec -it ollama ollama list`
- `docker exec -it ollama ollama pull deepseek-r1:1.5b`
- `ssh -t logan@10.0.0.32 docker exec -it ollama ollama pull qwen3.5`

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

## Matomo

Start it: `docker compose -f compose.all.yml up -d matomo` (Compose pulls in `matomo-db` and `matomo-cron` via `depends_on`).

Open the web UI at http://localhost:8080 and walk through the setup wizard. Database details on the install screen:

- Database server: `matomo-db`
- Username: `matomo`
- Password: value of `MATOMO_DB_PASSWORD` in `docker/.env`
- Database name: `matomo`

After install, go to Administration → System → General settings and uncheck _Archive reports when viewed from the browser_ — the `matomo-cron` container runs `core:archive` every 5 minutes.

## Hermes Agent

[Hermes Agent](https://hermes-agent.nousresearch.com/docs/user-guide/docker) (Nous Research) runs as a long-lived gateway plus a web dashboard. A single container hosts the supervised gateway and dashboard via its s6 supervisor.

Start it: `docker compose -f compose.all.yml up -d hermes-agent`. All state lives in `~/docker-volumes/hermes-agent` (mounted at `/opt/data`).

Set these in `docker/.env` before first start:

- `ANTHROPIC_API_KEY` — model provider key (forwarded via the compose `environment:` block)
- `HERMES_DASHBOARD_USER` / `HERMES_DASHBOARD_PASSWORD` — basic-auth login for the dashboard (it exposes API keys, so don't run it unauthenticated)
- `HERMES_DASHBOARD_SECRET` — restart-stable session secret (`openssl rand -hex 32`)

The dashboard is reached at http://hermes.homelab (Caddy → `hermes:9119`). No host ports are published.

First-boot notes:

- The first start seeds `~/docker-volumes/hermes-agent` with a default `config.yaml`, `SOUL.md`, and `.env`. Since we skip the interactive `hermes setup` wizard, edit `config.yaml` so `model.provider`/`model.model` match the forwarded key (Anthropic), and configure any chat platform there.
- The container drops to UID 10000. If logs show "Permission denied" on the data dir, set `PUID`/`PGID` to the host owner or `chmod -R 755 ~/docker-volumes/hermes-agent`.
- Check status: `docker exec hermes hermes status` (reports `Manager: s6 (container supervisor)`).


## ArchiveBox

[ArchiveBox](https://github.com/ArchiveBox/ArchiveBox) is a self-hosted web archive — it snapshots any URL to HTML/PDF/screenshot/WARC so it survives link rot. All state lives in `~/docker-volumes/archivebox` (mounted at `/data`).

Files are saved to `~/docker-volumes/archivebox` on the host (line 25), which is mounted into the container at `/data`.

That `/data` directory is where ArchiveBox keeps everything: the SQLite index DB, config, and the `archive/` subfolder containing per-snapshot output (HTML, PDF, screenshot, WARC, etc.). So concretely:

- Snapshots/captures: `~/docker-volumes/archivebox/archive/<timestamp>/`
- Index DB: `~/docker-volumes/archivebox/index.sqlite3`

Host port `8010` is published (host `8000` is already taken by Tube Archivist); normally you reach it at http://archivebox.homelab (Caddy → `archivebox:8000`).

The admin user is auto-created on first boot from the compose `environment:` block — username `admin`, password from `ARCHIVEBOX_ADMIN_PASSWORD` in `docker/.env` (defaults to `changeme` — change it before exposing this anywhere). Just start it:

```
docker compose -f compose.all.yml up -d archivebox
```

To create or reset a user manually instead: `docker compose -f compose.all.yml run archivebox manage createsuperuser`.

Add URLs from the CLI (or paste them in the Web UI):

```
docker compose -f compose.all.yml run archivebox add 'https://example.com'
docker compose -f compose.all.yml run -T archivebox add < ~/bookmarks.txt
```

Notes:

- `SERVER_SECURITY_MODE=safe-onedomain-nojsreplay` is used because the internal `.homelab` setup has no wildcard DNS — ArchiveBox's default `safe-subdomains` mode serves each snapshot on its own subdomain.
- The upstream compose's optional addons (Cloudflare Tunnel, Traefik, noVNC, WireGuard, ChangeDetection) are intentionally dropped — Caddy + Pi-hole already handle ingress and DNS.


## Penpot

[Penpot](https://penpot.app) is an open-source design & prototyping tool. It runs as a stack of services (`penpot-frontend`, `penpot-backend`, `penpot-exporter`, `penpot-mcp`, plus its own `penpot-postgres`, `penpot-valkey`, and a `penpot-mailcatch` SMTP catcher) defined in `penpot/docker-compose.yml`. The internal services sit on a dedicated `penpot` network; only `penpot-frontend` also joins `main-network` so Caddy can proxy it.

Set `PENPOT_SECRET_KEY` in `docker/.env` before first start (it's the master key sessions and invites derive from — changing it later invalidates them). Generate one with:

```
python3 -c "import secrets; print(secrets.token_urlsafe(64))"
```

Start just the Penpot stack:

```
docker compose -f compose.all.yml up -d penpot-frontend penpot-backend penpot-exporter penpot-mcp penpot-postgres penpot-valkey penpot-mailcatch
```

(Starting `penpot-frontend` alone pulls in most of the stack via `depends_on`, but not `penpot-mailcatch` — list them all to bring up SMTP too.)

Reach the UI at http://localhost:9001. Sent emails (invites, etc.) land in the mailcatcher at http://localhost:1080.

> **TODO — `PENPOT_PUBLIC_URI` is temporarily set to `http://localhost:9001`.** Unlike the other services, the Penpot frontend bakes this absolute URL into every API/asset call, so it only works at the URL it's set to. It's currently `localhost` so direct access works without DNS. To serve it at http://penpot.homelab (Caddy → `penpot-frontend:8080`) like the rest of the stack, add a `penpot.homelab` record to Pi-hole, then change `PENPOT_PUBLIC_URI` in `docker/.env` to `http://penpot.homelab` and recreate the containers. The single `.env` value is shared by both `penpot-frontend` and `penpot-backend`, so it only needs changing in one place.

Notes:

- `PENPOT_FLAGS` ships with `disable-email-verification` and `disable-secure-session-cookies` for easy LAN use. Drop both before exposing Penpot to the internet.
- The upstream compose's optional Traefik service is dropped — Caddy already handles ingress.


## Planka

[Planka](https://planka.app) is an open-source Kanban board (Trello-style project management). It runs as two services — the `planka` app and its own `planka-postgres` — defined in `planka/docker-compose.yml`. The internal services sit on a dedicated `planka` network; only `planka` also joins `main-network` so Caddy can proxy http://planka.homelab → `planka:1337`.

Set `PLANKA_SECRET_KEY` in `docker/planka/.env` before first start (sessions and tokens derive from it — changing it later invalidates them). Generate one with:

```
openssl rand -hex 64
```

Add a `planka.homelab` record to Pi-hole DNS, then start the stack:

```
docker compose -f compose.all.yml up -d planka planka-postgres
```

Create the first admin user (it prints the generated email/password):

```
docker compose -f compose.all.yml run --rm planka npm run db:create-admin-user
```

Reach the UI at http://planka.homelab and log in with those credentials.

> **Note — `BASE_URL` is baked into the frontend.** Like Penpot, Planka bakes its `BASE_URL` into every API/asset call, so it only works at the URL it's set to (unlike drawio, it does **not** tolerate a host mismatch). It defaults to `http://planka.homelab` (served via Caddy). The host port `1337` is published, so to test over localhost without DNS, override the URL to match and recreate:
>
> ```
> PLANKA_BASE_URL=http://localhost:1337 docker compose -f compose.all.yml up -d planka
> ```
>
> While set to localhost, `planka.homelab` won't work — switch `PLANKA_BASE_URL` back (or unset it) to return to Caddy serving.

### Backup / Restore

`planka/backup.sh` and `planka/restore.sh` are Planka's upstream scripts, pre-configured for the `planka` / `planka-postgres` container names. A backup exports the Postgres database and the data volume (avatars, backgrounds, attachments) into a single `.tgz`.

Manual backup (writes the tarball to the current directory, or a directory you pass):

```
cd docker/planka && ./backup.sh
```

> **Danger — restore overwrites the running instance.** Make sure you're restoring the correct backup.

```
cd docker/planka && ./restore.sh 2026-01-17T15-37-22Z-backup.tgz
```

Automate a nightly backup at 2 AM with `crontab -e` (keeps 14 days):

```
0 2 * * * cd /home/logan/repos/homelab/docker/planka && bash backup.sh > /dev/null 2>&1
0 2 * * * find /home/logan/repos/homelab/docker/planka/*.tgz -mtime +14 -delete > /dev/null 2>&1
```

Notes:

- `planka-postgres` uses `POSTGRES_HOST_AUTH_METHOD=trust` (LAN-only, no DB password), matching upstream. Don't expose Postgres outside the `planka` network.
- The upstream compose's optional Traefik/S3/OIDC config is dropped — Caddy handles ingress; enable the others later via env if needed.


## Navidrome

[What am I doing wrong? : r/navidrome](https://www.reddit.com/r/navidrome/comments/1v3mmm1/what_am_i_doing_wrong/)


[Navidrome](https://www.navidrome.org) is a self-hosted music server and streamer that's compatible with the Subsonic API, so any Subsonic client app can play from it. It's a single container defined in `navidrome/docker-compose.yml`, on `main-network`, and Caddy proxies http://navidrome.homelab → `navidrome:4533`.

The music library is set by `NAVIDROME_MUSIC_DIR` in `docker/navidrome/.env`, mounted read-only at `/music`. It currently points at the SSD external drive:

```
NAVIDROME_MUSIC_DIR=/Volumes/SSD/music
```

That's a Mac path and it does **not** exist on the Linux VM. Docker would silently create an empty directory there rather than fail, leaving Navidrome scanning nothing — repoint it before running this on the VM. Unset the var entirely and it falls back to `~/docker-volumes/navidrome/music`.

If Navidrome is already running and you change the library path, update the env variable and then run:

```
docker compose -f compose.all.yml up -d navidrome
```

Compose re-reads the env file, sees the bind mount source changed, and automatically recreates the container with the new mount. On startup Navidrome rescans the new library location.

The key thing to avoid is `docker compose restart navidrome` — restart just stops and starts the existing container with its old mounts, so the env change would be silently ignored. Volume/env changes always require a recreate, which `up -d` handles for you.

The `navidrome.homelab` record is already committed to `pihole/etc-dnsmasq.d/10-homelab.conf`, so it just needs Pi-hole to pick it up. Start the service and reload DNS:

```
docker compose -f compose.all.yml up -d navidrome
docker compose -f compose.all.yml restart pihole caddy
```

Reach the UI at http://localhost:4533, or at http://navidrome.homelab wherever Caddy and Pi-hole are actually serving the stack (see the phone-access section below — the `.homelab` name does not resolve to the Mac today). The first account you create on the sign-up screen becomes the admin.

Notes:

- The library is mounted `:ro` so a scan can never modify the originals. Navidrome's own DB, cache and artwork live in the `navidrome_data` named volume.
- That volume is deliberately **not** a `~/docker-volumes` bind mount like most services here. Navidrome's SQLite DB runs in WAL mode, which needs shared-memory locking via real `mmap`; a Docker Desktop bind mount is VirtioFS (`fakeowner`), which doesn't support it, and the scanner dies partway through with `locking protocol` / `file is not a database`. Named volumes are real ext4 inside the VM. It also means `backup-remote-volumes.sh` picks the DB up, since that script only tars named volumes.
- The initial scan runs on startup — about 3 minutes for the ~5,400-track Elements library. Watch it with `docker compose -f compose.all.yml logs -f navidrome`; it ends with `Scanner: Finished scanning all libraries`. Rescans then run on a schedule (`ND_SCANSCHEDULE`).
- Unlike Planka and Penpot, Navidrome doesn't bake a base URL into the frontend, so there's no `BASE_URL` env var to juggle — it serves correctly on whatever host it's reached by (localhost, LAN IP, or `.homelab`) with no config changes and no one URL breaking another.
- Upstream's `user: 1000:1000` is left commented out in compose — the uid differs between the Linux VM (1000) and a Mac running it locally (501). Uncomment it on the VM if you hit permission errors on `/data`.
- Its `compose.all.yml` include lists both `.env` and `navidrome/.env`: naming an `env_file` replaces the default `.env` lookup, so the shared one has to be listed explicitly or `${TZ}` resolves to empty.

### Access from your phone (or any LAN device)

Port 4533 is published on all interfaces, so anything on the same Wi-Fi can reach Navidrome directly by the host's LAN IP — no Caddy, no DNS, no Pi-hole involved. Get the address of the Mac running it:

```
ipconfig getifaddr en0
```

Then browse to `http://<that-ip>:4533`. At the time of writing that's http://10.0.0.227:4533.

Since Navidrome speaks the Subsonic API, a native client is usually nicer than the web UI on a phone — Amperfy or play:Sub on iOS, Symfonium or DSub on Android. Point any of them at the same `http://<ip>:4533` with the admin login for offline sync and lock-screen controls.

Three things worth knowing:

- **The IP is DHCP and will eventually change.** If the phone stops connecting, re-run `ipconfig getifaddr en0` before assuming anything is broken. A DHCP reservation in the router pinning the Mac to a fixed address is the real fix.
- **`navidrome.homelab` does not work from other devices when the stack runs on the Mac.** Caddy and Pi-hole aren't running there, and the records in `10-homelab.conf` all point at `10.0.0.32` while the Mac currently answers on `10.0.0.227` — so the name resolves to the wrong host. Pinning the Mac to `10.0.0.32` via DHCP reservation would make all the existing records correct at once. Until then, use the IP directly.
- **To confirm it's genuinely reachable rather than just listening**, check the bind address and make a real request over the LAN (not loopback):

```
docker port navidrome                              # want 0.0.0.0:4533, not 127.0.0.1:4533
curl --max-time 5 -o /dev/null -w '%{http_code}\n' http://<ip>:4533/app/   # want 200
```

macOS's firewall can also block this even when the port is bound correctly — check with `/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate`.

### Reinstall / start fresh

Wipes the database and rebuilds from scratch.

> **Danger — don't use `docker compose down navidrome`.** Depending on the Compose version that tears down the whole project, and `compose.all.yml` is every service in the stack. `stop` + `rm` can only touch navidrome.

```
cd ~/repos/homelab/docker

# 1. Stop and remove just the container
docker compose -f compose.all.yml stop navidrome
docker compose -f compose.all.yml rm -f navidrome

# 2. Delete the DB, cache and plugins -- this is the actual "uninstall"
docker volume rm docker_navidrome_data

# 3. Force a fresh image (optional, skip if you just want a clean DB)
docker rmi deluan/navidrome:latest

# 4. Rebuild from scratch
docker compose -f compose.all.yml pull navidrome
docker compose -f compose.all.yml up -d navidrome

# 5. Watch the scan
docker compose -f compose.all.yml logs -f navidrome
```

This throws away the admin account, play counts, ratings and playlists — you'll create a new admin on first load. The music itself is never at risk: the library is mounted `:ro`, so nothing Navidrome does can touch it. It just gets re-scanned from scratch — about 3 minutes for the ~5,400-track Elements library.

> **Note — a reinstall won't fix `locking protocol` or `file is not a database`.** Those aren't corruption, so wiping the DB only buys you a clean one that breaks again on the next scan. They mean `/data` has ended up on a bind mount instead of the `navidrome_data` named volume — see the volume comment in `navidrome/docker-compose.yml`. Check with:
>
> ```
> docker inspect navidrome --format '{{range .Mounts}}{{.Type}} {{.Destination}}{{"\n"}}{{end}}'
> ```
>
> `/data` must say `volume`. If it says `bind`, that's the bug.

## Backrest

[Backrest](https://github.com/garethgeorge/backrest) is a web UI over [restic](https://restic.net). restic does the actual work — deduplicated, encrypted, incremental snapshots — and Backrest adds the parts the CLI doesn't have: cron-scheduled backups, automatic repo maintenance (`prune`, `check`, `forget`), a file browser for restores, and notification hooks. The restic CLI is still there underneath if you need it.

Unlike most of the recent additions here, Backrest is defined in the **root** `docker-compose.yml`, not in its own `backrest/docker-compose.yml` — so there's no `compose.all.yml` include for it. It's on `main-network` and Caddy proxies http://backrest.homelab → `backrest:9898`.

**There is no published port**, which is the difference from Navidrome. The compose block has no `ports:` at all, so `http://localhost:9898` does not exist — Caddy plus Pi-hole DNS are the only way in, and that's why the services table lists `N/A` for the localhost column. The same caveat from the Navidrome section applies: the `.homelab` records all point at `10.0.0.32`, so if you're running the stack on a Mac answering on a different address, the name resolves to the wrong host and nothing reaches Backrest.

### Mounts

Backrest has more mounts than anything else in the stack, and which one is which matters:

| Container path | Host source | What it is |
|-|-|-|
| `/data` | `~/docker-volumes/backrest/data` | `BACKREST_DATA` — the managed restic binary, the oplog SQLite DB, `jwt-secret` |
| `/config` | `./backrest/config` | `config.json` — repos, plans, admin user |
| `/cache` | `./backrest/cache` | `XDG_CACHE_HOME`, passed through to restic; a big speedup, don't skip it |
| `/tmp` | `./backrest/tmp` | `TMPDIR` |
| `/root/.config/rclone` | `./backrest/rclone` | only needed if you back up to an rclone remote |
| `/userdata` | `${BACKREST_USERDATA:-/Users/logan/docker-volumes}` | the backup **sources** — what gets snapshotted |
| `/repos` | `${BACKREST_REPOS:-/Users/logan/repos}` | local restic **repositories** — where snapshots are written |

The last two are the ones to get right, and they're easy to mix up: `/userdata` is what you're backing *up*, `/repos` is what you're backing up *to*.

> **Watch out — `/repos` currently points at your git checkouts.** Upstream's convention is that `/repos` holds local restic repositories, but `BACKREST_REPOS` is commented out in `docker/.env`, so the `:-/Users/logan/repos` fallback applies and `/repos` is really `~/repos`. Creating a local repo at `/repos/homelab` would write restic pack files into `~/repos/homelab`, on top of a git working tree. Before configuring a local repo, point it somewhere dedicated — uncomment the line in `docker/.env` and set it:
>
> ```
> BACKREST_REPOS=/Users/logan/docker-volumes/backrest/repos
> ```
>
> then recreate the container so the new bind takes effect (`stop` + `rm` + `up -d`, see below).

### Running it

```
docker compose -f compose.all.yml up -d backrest
docker compose -f compose.all.yml restart pihole caddy
```

Then open http://backrest.homelab. The first load prompts you to create a username and password — there's no default login.

Once you're in, it takes two objects to actually start backing anything up:

1. **A repo.** Add one with URI `/repos/<name>` for local storage, and give it a passphrase. Backrest runs `restic init` for you.
2. **A plan.** Point it at a path under `/userdata`, give it a cron schedule and a retention policy (e.g. keep 7 daily / 4 weekly / 6 monthly).

Cron schedules are evaluated in the container's timezone, which comes from `TZ` in the shared `docker/.env`.

> **The repo passphrase is not recoverable.** restic has no backdoor, no reset, no escrow — if you lose it, every snapshot in that repo is permanently unreadable. Store it somewhere that isn't only inside the thing you're backing up.

Notes:

- restic is not baked into the image. Backrest downloads a compatible version into `/data` on first run and keeps it updated. Set `BACKREST_RESTIC_COMMAND` if you'd rather pin a specific binary.
- `/userdata` is mounted **read-write**. Nothing in a normal backup flow writes to it, but unlike Navidrome's `:ro` music mount there's nothing enforcing that.
- Backrest's own state lives on bind mounts, and `backup-remote-volumes.sh` only tars **named** volumes — so its config and oplog are not covered by that script. `docker/backrest/config/config.json` is the one file worth keeping if you want your repos and plans back.
- `docker/backrest/config/` and `docker/backrest/data/` are **committed to this repo**, live SQLite files and secrets included. This instance is for testing, so that's deliberate — but it means a fresh clone inherits an existing admin user and JWT secret rather than starting clean. Don't treat this as a template for a real deployment.
- `docker/backrest/data/` is stale. It's left over from November 2025, when `/data` was mapped there; compose now maps `/data` to `~/docker-volumes/backrest/data`, so nothing reads those tracked files anymore.

### Reinstall / start fresh

Wipes the admin account, repo definitions and plans.

> **Danger — don't use `docker compose down backrest`.** Depending on the Compose version that tears down the whole project, and `compose.all.yml` is every service in the stack. `stop` + `rm` can only touch backrest.

```
cd ~/repos/homelab/docker

# 1. Stop and remove just the container
docker compose -f compose.all.yml stop backrest
docker compose -f compose.all.yml rm -f backrest

# 2. Delete the config and data -- this is the actual "uninstall"
rm -rf ~/docker-volumes/backrest/data
rm -f ./backrest/config/config.json

# 3. Rebuild from scratch
docker compose -f compose.all.yml pull backrest
docker compose -f compose.all.yml up -d backrest
```

**This does not delete your snapshots.** Those live in the restic repo under `/repos`, which is a completely separate mount — the reinstall only throws away Backrest's knowledge of them. Re-add the repo with the same passphrase and every existing snapshot reappears, browsable and restorable. That separation is the point: Backrest is a front end over the repo, not the repo itself.


# DNS Process Explained

1. Set Wifi DNS on mac to IP address of Mac (ipconfig getifaddr en0)
2. Set DNS records in 10-homelab.conf
3. Laptop/phone use pihole as their DNS server (can either do it via router or change each device's DNS settings)
4. In browser you type 'homepage.homelab'.
5. Chrome  calls the system resolver (MacOS's mDNSResponder) to resolve the URL. The resolver looks at the network config and sees the DNS server is set to 10.0.0.32. 
6. The resolver creates a DNS query and sends it to UDP port 53 (10.0.0.32)
7. Since 10.0.0.32 is on your LAN, your Mac ARPs to find the MAC address for 10.0.0.32 and fires the packet on the wire
8. If you’re doing this from the same Mac that’s running Docker, it still works: packets to 10.0.0.32 loop back into the host’s networking stack (because that IP is assigned to your Mac), then hit Docker’s port-forward
9. Docker forwards host :53 -> Pi-hole container :53 (this is because we defined - "53:53/tcp" and "53:53/udp" in the pihole ports config)
10. Pihole checks its local DNS and returns 10.0.0.32 as the IP address for homepage.homelab.
    - For everything else (e.g., example.com), Pi-hole forwards to its upstream resolver(s) (whatever you configured in the Pi-hole admin: Cloudflare, Quad9, your router, etc.), gets the reply, applies blocklists if relevant, and sends the answer back to your Mac
11. Browser connects to 10.0.0.32 on HTTP port 80 (because we typed homepage.homelab)
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

open claw

https://www.reddit.com/r/selfhosted/comments/1u4dwms/comment/orcoeac/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button

https://github.com/calcom/cal.diy 

https://github.com/AppFlowy-IO/AppFlowy



[20 apps i actually run on my home server and which ones are worth it : r/selfhosted](https://www.reddit.com/r/selfhosted/comments/1u4dwms/comment/orcoeac/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1)

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
- rename `docker-volumes` directory as `docker-bind-mounts`
- Update homepage https://www.reddit.com/r/selfhosted/comments/1p1469e/my_homepage_dashboard_v3/
- https://signoz.io/docs/install/docker/
- [First steps - Trivy](https://trivy.dev/docs/latest/getting-started/)
- https://github.com/HKUDS/nanobot
- https://github.com/paperclipai/paperclip 
- syncthing
- stirling-PDF
- Documenso
- https://github.com/9001/copyparty
- [OpenHands/OpenHands: 🙌 OpenHands: AI-Driven Development](https://github.com/OpenHands/openhands)



# Grafana Queries

# Loki Queries

- `{container=~".*app.*"} | json | user_email!=""`
- `{container=~".*app.*"} | json | user_email="adminuser@example.com"`
- `{container=~".*app.*"} | json | message="create_item_request"`



# List of Services

The tables below cover the Docker Compose + Caddy stack (`docker/`). Network URLs are served by Caddy at `*.homelab`. Localhost URLs only exist for services that publish a host port; most are reached via Caddy only. Most credentials are committed defaults/placeholders — change them.

## Services requiring URL change between localhost and homelab

These services bake their public URL into the frontend at startup — they only work at the URL they were configured with. Switching between localhost and homelab access requires updating the variable below and recreating the container (`docker compose up -d <service>`, not `restart`).

| Service | Variable | File | Localhost value | Homelab value |
|-|-|-|-|-|
| penpot | `PENPOT_PUBLIC_URI` | `penpot/.env` | `http://localhost:9001` | `http://penpot.homelab` |
| planka | `PLANKA_BASE_URL` | env override at run time | `http://localhost:1337` | `http://planka.homelab` (unset = default) |
| karakeep | `NEXTAUTH_URL` | `karakeep/.env` | `http://localhost:3000` | `http://karakeep.homelab` |
| tubearchivist | `TA_HOST` | `docker/.env` | `http://localhost:8000` | `http://tubearchivist.homelab` |
| archivebox | `BASE_URL` | `archivebox/docker-compose.yml` | `http://archivebox.localhost:8010` | `http://archivebox.homelab` |

## Applications

| Service | Localhost URL | Network URL (Caddy) | Credentials |
|-|-|-|-|
| grafana | N/A | http://grafana.homelab | admin / admin123 |
| cadvisor | http://localhost:8089 | http://cadvisor.homelab | N/A |
| homepage | N/A | http://homepage.homelab | N/A |
| cronmaster | http://localhost:40123 | http://cronmaster.homelab | password: very_strong_password |
| pihole | N/A | http://pihole.homelab | password: changeme |
| kafka-ui | N/A | http://kafka-ui.homelab | N/A |
| akhq | N/A | http://akhq.homelab | N/A |
| gatus | http://localhost:8082 | http://gatus.homelab | N/A |
| excalidraw | N/A | http://excalidraw.homelab | N/A |
| drawio | http://localhost:8080 | http://drawio.homelab | N/A |
| dozzle | N/A | http://dozzle.homelab | N/A |
| glance | N/A | http://glance.homelab | N/A |
| uptime-kuma | N/A | http://uptime-kuma.homelab | set on first run, but set it to admin / password123 |
| jellyfin | N/A | http://jellyfin.homelab | set on first run |
| n8n | N/A | http://n8n.homelab | set on first run (/setup) |
| flame | N/A | http://flame.homelab | password: changeMe |
| redisinsight | N/A | http://redisinsight.homelab | N/A (connection pre-seeded) |
| live-auction | N/A | http://live-auction.homelab | app-managed |
| prometheus | N/A | http://prometheus.homelab | N/A |
| loki | N/A | http://loki.homelab | N/A |
| metabase | N/A | http://metabase.homelab | set on first run |
| umami | N/A | http://umami.homelab | admin / umami |
| ollama | N/A | http://ollama.homelab | N/A |
| ollama-webui | N/A | http://ollama-webui.homelab | N/A (auth disabled) |
| changedetection | N/A | http://changedetection.homelab | N/A |
| komodo | http://localhost:9120 | http://komodo.homelab | admin / changeme |
| netdata | N/A | http://netdata.homelab | N/A |
| karakeep | N/A | http://karakeep.homelab | set on first run (signup) |
| beszel | http://localhost:8090 | http://beszel.homelab | set on first run |
| backrest | N/A | http://backrest.homelab | set on first run |
| paperless-ngx | N/A | http://paperless.homelab | admin / changeMe |
| tubearchivist | http://localhost:8000 | http://tubearchivist.homelab | tubearchivist / changeMe |
| pinchflat | N/A | http://pinchflat.homelab | N/A |
| immich | N/A | http://immich.homelab | set on first run |
| jotty | http://localhost:1122 | http://jotty.homelab | N/A |
| cta-map | N/A | http://cta-map.homelab | N/A |
| hermes | http://localhost:9119 | http://hermes.homelab | admin / changeMe |
| archivebox | http://localhost:8010 | http://archivebox.homelab | admin / changeme |
| navidrome | http://localhost:4533 | http://navidrome.homelab | set on first run (first user is admin) |
| penpot | http://localhost:9001 | http://penpot.homelab | set on first run (registration) |
| planka | http://localhost:1337 | http://planka.homelab | created via `npm run db:create-admin-user` |
| penpot-mailcatch | http://localhost:1080 | N/A (no Caddy block) | N/A |
| matomo | http://localhost:8080 | N/A (no Caddy block) | set on first run; DB pass changeMe |
| alloy | http://localhost:12345 | N/A (no Caddy block) | N/A |

## Backing / infrastructure services

No web UI; listed for completeness.

| Service | Localhost URL | Network URL (Caddy) | Credentials |
|-|-|-|-|
| caddy | http://localhost (:80 / :443) | (the proxy itself) | N/A |
| kafka (broker) | localhost:9092, localhost:29092 | N/A | N/A |
| redis | localhost:6379 | N/A | password: changeMe |
| redis-pubsub | localhost:6380 | N/A | password: changeMe |
| test-db (postgres) | localhost:5432 | N/A | testuser / testpassword |
| n8n postgres | N/A | N/A | changeUser / changePassword |
| metabase-db (postgres) | N/A | N/A | metabase / changeMe |
| umami-db (postgres) | N/A | N/A | umami / umami |
| paperless-ngx-db (postgres) | N/A | N/A | paperless / paperless |
| paperless-ngx-broker (redis) | N/A | N/A | N/A |
| immich postgres | N/A | N/A | postgres / postgres |
| planka-postgres | N/A | N/A | postgres (trust auth, no password) |
| immich-redis | N/A | N/A | N/A |
| immich-machine-learning | N/A | N/A | N/A |
| matomo-db (mariadb) | N/A | N/A | root pass: changeMe |
| matomo-cron | N/A | N/A | N/A |
| karakeep-chrome | N/A | N/A | N/A |
| karakeep-meilisearch | N/A | N/A | N/A |
| komodo-mongo | N/A | N/A | admin / admin |
| komodo-periphery | N/A | N/A | N/A |
| archivist-es (elasticsearch) | N/A | N/A | elastic / changeMe |
| archivist-redis | N/A | N/A | N/A |
| beszel-agent | N/A | N/A | N/A |
| penpot-backend | N/A | N/A | uses PENPOT_SECRET_KEY |
| penpot-exporter | N/A | N/A | N/A |
| penpot-mcp | N/A | N/A | N/A |
| penpot-postgres | N/A | N/A | penpot / penpot |
| penpot-valkey | N/A | N/A | N/A |
| tailscale | N/A | N/A | N/A |



# Install PopOS & Access Proxmox GUI outside of home network (Tailscale on Proxmox host)

1, Download ISO
2. Datacenter > pve > local (pve) > ISO Images > Upload
3. Create VM
	- Name: PopOS
	- OS
		- Storage: local
		- ISO image: PopOS
		- Type: Linux
		- Disk size: 250 GiB
		- CPU: 8 Cores
		- Memory: 32768
4. Click on PopOS VM
5. Start
6. Click Console
7. Go through set up process
8. ctrl+alt+f2
	- `flatpak install flathub org.wezfurlong.wezterm`
9. While you're on your home network, open https://10.0.0.98:8006 in a browser and log in. In the left sidebar, click your node name (probably "pve"), then click the Shell button. You now have a root command line on the Proxmox host. Everything in the next step gets typed here.
10. 
```
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
```

tailscale up prints a login URL. Copy it into a browser, sign in (make an account if you don't have one — Google/GitHub/email all work). This links the Proxmox host to your account.

Then get its Tailscale address: `tailscale ip -4`


On the phone: turn Wi-Fi off, leave cellular data on. This proves you're genuinely "outside" your home network.
Confirm the Tailscale toggle is still on.
Open a browser on the phone and go to:

  https://100.x.y.z:8006
(the Tailscale IP from Step 2, port 8006 — not the 10.0.0.98 address; that only works at home)

You'll get a certificate warning because Proxmox uses a self-signed cert. Tap through it (Advanced → proceed) — it's your own server, it's safe.

If you get errors from mobile

- `apt update`
- `apt full-upgrade`


# Tailscale in LXC on proxmox as a subnet router

https://www.reddit.com/r/Proxmox/comments/1g701ap/comment/lsmze85/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button

[How safe is it to install Tailscale on a Proxmox cluster node? : r/Proxmox](https://www.reddit.com/r/Proxmox/comments/1uw0aek/how_safe_is_it_to_install_tailscale_on_a_proxmox/)
