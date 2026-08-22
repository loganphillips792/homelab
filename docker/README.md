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
        5. Update the IP Addresses in the PiHole DNS config to the IP Address of the Ubuntu VM. `ip route get` asks the kernel which source address it would use to reach an off-link destination, so it returns the address on the default-route interface and never a `br-*` Docker bridge (no packets are sent — it's a pure routing-table lookup):

            ```bash
            VM_IP=$(ip -4 route get 1.1.1.1 | grep -oP 'src \K\S+')
            echo "$VM_IP"   # sanity-check before rewriting
            sed -i "s/10\.0\.0\.32/$VM_IP/g" docker/pihole/etc-dnsmasq.d/10-homelab.conf
            ```

            Note the quotes change from single to double on the `sed` so `$VM_IP` expands.
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
5. Set `TS_AUTHKEY` in `docker/.env` on the server (not in `docker-compose.yml` — that just reads `${TS_AUTHKEY}`)
6. `docker compose -f compose.all.yml up -d tailscale`
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

### Updating everything after a git pull

One command that picks up any kind of change — new images, compose file edits, and bind-mounted config file edits:

```bash
docker compose --progress plain -f docker/compose.all.yml up -d --pull always --force-recreate --remove-orphans
```

What each flag buys you:

- `--progress plain` — prints one log line per event instead of the live-redrawing display, so nothing gets collapsed into "... N more" and pull errors stay visible in scrollback (global flag, so it goes before `-f`)
- `--pull always` — pulls newer images for every service before starting (catches `:latest` updates)
- `--force-recreate` — recreates **every** container, even ones compose thinks are unchanged. This is the piece that solves the bind-mount problem: every process comes up fresh and re-reads its config files, so Caddyfile/gatus/prometheus/pihole edits all take effect without you tracking which ones changed
- `--remove-orphans` — removes containers for services deleted from the compose files

The trade-off is that everything restarts, changed or not — so a brief blip on every service (including DNS via pihole) each time you run it, and it takes a bit longer than a plain `up -d`. Named volumes and bind mounts persist, so no data is at risk. For a homelab pull-and-update routine, that's a fine price for never having to think about what kind of change was in the pull.

One side effect of pulling regularly: old image layers pile up. An occasional `docker image prune -f` cleans those out.

### Restarting a single service

Name the service to limit `up` to just it:

```bash
docker compose -f docker/compose.all.yml up -d gatus
```

None of the extra flags from the full-update command are needed: `up -d` already recreates the container when its compose config changed. If you only edited a bind-mounted config file (nothing in the YAML), add `--force-recreate` so the process comes up fresh and re-reads it. Avoid `docker compose restart <service>` after YAML/env changes — restart reuses the existing container config and silently ignores them.

#### Why `--force-recreate` is only sometimes needed

Compose stores a hash of each service's resolved config on the container, as the `com.docker.compose.config-hash` label. On `up -d` it recomputes that hash and recreates the container when it differs.

So a change **inside the YAML** needs no flag. Editing `BASE_URL` on the archivebox service changes the resolved config, the hash differs, and recreation happens on its own:

```bash
docker compose -f docker/compose.all.yml up -d archivebox
```

Interpolation runs before hashing, so this holds for `${VAR}` values pulled from `.env` too — the resolved value is what gets hashed, not the literal `${VAR}`.

`--force-recreate` exists for the case where the hash *doesn't* change but the running process is still stale: you edited a bind-mounted file like `caddy/Caddyfile` or `observability/prometheus/prometheus.yml`, which compose can't see into. Nothing in the YAML moved, so `up -d` considers the container current and leaves it running with the old config in memory.

```bash
docker compose -f docker/compose.all.yml up -d --force-recreate caddy
```

Adding the flag when it wasn't needed is harmless — it just recreates a container that would have been recreated anyway.

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

### Applying DNS record changes

After adding or editing a `host-record` in `pihole/etc-dnsmasq.d/10-homelab.conf`, the file is
already visible inside the container (it's a bind mount) — dnsmasq just has to re-read it:

```bash
docker compose -f docker/compose.all.yml restart pihole
# or, without a restart:
docker compose -f docker/compose.all.yml exec pihole pihole reloaddns
```

Then verify the new name resolves, e.g. for `navidrome.homelab`:

```bash
dig +short navidrome.homelab @192.168.1.150
```

That should return `192.168.1.150`. An empty result means the record didn't take — check that the
IP in `10-homelab.conf` matches the VM's current IP (the committed records use a `10.0.0.32`
placeholder, so the deployed copy on the VM is what actually matters).

- After making changes to prometheus: `docker compose -f docker/docker-compose.yml restart prometheus`

- docker compose -f docker/docker-compose.yml up caddy pihole cronmaster -d 

- `docker compose -f docker/docker-compose.yml up -d cadvisor pihole caddy prometheus loki alloy grafana homepage`

- Use `docker stats` command to see container usage

pveversion --verbose

`docker system df -v | grep -i "loki"`


`ssh logan@10.0.0.32 "cd /home/logan/homelab/docker && docker compose pull ollama && docker compose up -d ollama"`

### Checking memory pressure on the Proxmox host

Run from the Mac — this is the number that actually matters, not the gauge in the Proxmox UI:

```bash
ssh root@192.168.1.98 "free -m | awk 'NR==2{print \$7\" MiB available\"}'; cat /proc/pressure/memory"
```

Trouble looks like host `available` dropping under ~1500 MiB, or the PSI `some avg60` value climbing off `0.00`. Both healthy means the host has room even if the VM looks full.

**Ignore the VM's memory gauge in the Proxmox UI.** It reports `total - free`, which counts the guest's page cache as "used", so a healthy VM running this Docker stack sits around 90% more or less permanently. Linux fills spare RAM with disk cache on purpose and drops it the instant a process needs the memory. To see real guest usage, look at the `available` column instead:

```bash
free -m
```

For context, a normal reading on the 20 GiB VM: ~12 GiB genuinely in use by processes, ~6 GiB page cache, ~7 GiB available. The Proxmox UI shows that same moment as 90%.

### Recommended settings for VM 100

Run these on the Proxmox host (`ssh root@192.168.1.98`, or the node's Shell in the web UI):

1. **Lower VM 100's memory to something the host can actually back** — 20 GiB is the suggested figure, leaving ~8 GiB for Proxmox itself:

   ```bash
   qm set 100 --memory 20480
   ```

   Takes effect on the VM's next stop/start, not immediately.

2. **Enable autostart** so the VM comes back on its own after a host reboot:

   ```bash
   qm set 100 --onboot 1
   ```

Check what's currently set with:

```bash
ssh root@192.168.1.98 "qm config 100 | grep -E 'memory|onboot|balloon'"
```

### Container memory limits

Set 2026-08-21. Before this, **no container had a limit** — every `memory.max` read `max` — so a
single leaking container could climb through the whole 20 GB and take the VM into swap-thrash
(load 127, swap fully exhausted, kernel reporting all tasks stalled on memory 45% of the time). With
a limit the runaway is OOM-killed instead and `restart: unless-stopped` brings it back: one service
blips rather than the whole box degrading.

| Service | Limit | Observed when set | File |
|-|-|-|-|
| metabase | 2g | 1165M | `docker-compose.yml` |
| alloy | 1600m | 965M–1359M | `observability/docker-compose.yml` |
| kafka | 1600m | 919M | `docker-compose.yml` |
| archivist-es | 1500m | 922M | `tubearchivist/docker-compose.yml` |
| netdata | 1400m | 1077M | `docker-compose.yml` |
| penpot-backend | 1200m | 879M | `penpot/docker-compose.yml` |
| akhq | 1g | 515M | `docker-compose.yml` |
| immich-server | 1000m | 632M | `immich/docker-compose.yml` |
| tubearchivist | 1000m | 674M | `tubearchivist/docker-compose.yml` |
| ollama-webui | 800m | 507M | `docker-compose.yml` |

Limits are deliberately generous (~1.3-1.5× observed). alloy alone swung 965M→1359M inside an hour,
so a limit set at the instantaneous reading would kill healthy services. Sum of limits exceeding
physical RAM is fine — a limit caps a container, it does not reserve memory for it.

#### The JVM trap

**Setting `mem_limit` on a JVM container silently reconfigures its heap.** Java 11+ is container-aware:
with no limit it sizes max heap at 25% of *host* RAM (5 GB here); add a 2g limit and that becomes
~512m — usually far below the working set, so the service starts GC-thrashing or dies.

So any JVM service needs an explicit heap set *alongside* the limit:

- `metabase` → `JAVA_OPTS: -Xmx1200m` (had no heap flags)
- `akhq` → `JAVA_OPTS: -Xmx512m` (had no heap flags)
- `kafka` → already pinned by the image at `-Xmx1G`, limit sized to clear it
- `archivist-es` → already `ES_JAVA_OPTS=-Xms512m -Xmx512m`

Related trap, same family: `-Xmx` does **not** cover JVM overhead — metaspace, thread stacks, direct
buffers, GC structures. `archivist-es` sat at 1.5 GB RSS on a 1g heap for exactly this reason. Budget
roughly 400-600m above the heap when picking a container limit.

#### Checking and tuning

See what is actually set, and how close each container is running to its ceiling:

```bash
ssh logan@192.168.1.150 'for d in /sys/fs/cgroup/system.slice/docker-*.scope; do
  m=$(cat $d/memory.max); [ "$m" = "max" ] && continue
  a=$(awk "\$1==\"anon\"{print \$2}" $d/memory.stat)
  echo "$((a*100/m))% $((a/1048576))M/$((m/1048576))M $(basename $d)"
done | sort -rn | head'
```

Anything sustained above ~85% wants a higher limit. To find services killed for exceeding one:

```bash
docker ps -a --filter "status=exited" --format "{{.Names}}\t{{.Status}}" | grep 137
```

Exit code 137 is SIGKILL, which for a limited container almost always means the OOM killer.

# Backup strategy

- Backup: `./docker/backup-remote-volumes.sh`
- Restore: `./restore-docker-backup.sh <tar-file-name>`
- ArchiveBox volume only: `./docker/archivebox/backup-archivebox.sh` (see below)


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

## ArchiveBox volume backup

`./docker/archivebox/backup-archivebox.sh` backs up only the ArchiveBox data volume — the SQLite index plus the `archive/` snapshot tree — without stopping the rest of the stack. It stops the container so SQLite is quiescent, streams a gzipped tar over ssh, restarts the container, then verifies the archive locally before reporting success.

```bash
# Default: writes ~/archivebox-backup/archivebox-<timestamp>.tar.gz
./docker/archivebox/backup-archivebox.sh

# Somewhere else — positional or env var
./docker/archivebox/backup-archivebox.sh ~/somewhere-else
OUT_DIR=~/somewhere-else ./docker/archivebox/backup-archivebox.sh
```

Other overrides: `REMOTE_HOST` (default `logan@192.168.1.150`), `CONTAINER` (default `archivebox`), `REMOTE_VOLUME_PARENT` (default `~/docker-volumes`, resolved on the remote host).

It exits 0 only when the tarball is readable and non-empty, so it chains safely:

```bash
./docker/archivebox/backup-archivebox.sh && echo "backed up"
```

### Why it verifies instead of trusting the exit code

The remote chain is `docker stop && tar czf -; docker start`. The `;` guarantees the container comes back even if tar fails — but it also means ssh reports the exit status of `docker start`, never of `tar`. Two failures slip past a plain `set -e`:

- **`docker stop` fails** → `tar` never runs, but the local shell already created the redirect target, leaving a zero-byte `.tar.gz`. `tar tzf` exits 0 on an empty file, so the script also requires a non-zero entry count.
- **`tar` dies mid-stream** (full disk, OOM) → a truncated file that looks plausible until restore day. `tar tzf` catches this one.

In both cases the script deletes the bad file and exits 1, so a failed run never leaves behind something that looks like a backup.

### Restoring

```bash
# Inspect before touching anything
tar tzf ~/archivebox-backup/archivebox-<timestamp>.tar.gz | head

# Replace the volume on the server
ssh logan@192.168.1.150 'docker stop archivebox >/dev/null'
ssh logan@192.168.1.150 'rm -rf ~/docker-volumes/archivebox'
ssh logan@192.168.1.150 'tar xzf - -C ~/docker-volumes' < ~/archivebox-backup/archivebox-<timestamp>.tar.gz
ssh logan@192.168.1.150 'docker start archivebox >/dev/null'
```

The tar is rooted at `archivebox/`, so it extracts into `~/docker-volumes/` and recreates that directory.

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

## Repository layout

`compose.all.yml` is the entrypoint — it does nothing but `include:` one file per service or service
group. Run everything with:

```bash
docker compose -f docker/compose.all.yml up -d
```

```
docker/
  compose.all.yml           <- entrypoint: the include list, nothing else
  docker-compose.yml        <- shared file, still ~35 single-container services
  observability/            <- prometheus, loki, alloy, grafana, cadvisor
    docker-compose.yml         + their config: alloy/ grafana/ prometheus/ loki/
  gatus/  glance/  homepage/  <- compose file sits next to its config/ dir
  immich/ penpot/ planka/ navidrome/ linkwarden/ matomo/ tubearchivist/
  hermes-agent/ redis-pubsub/ archivebox/   <- multi-container or own env file
  caddy/ pihole/            <- config only; services defined in docker-compose.yml
```

### The one rule that matters

**Relative paths inside an included file resolve against that file's own directory, not `docker/`.**

So `observability/docker-compose.yml` mounts `./prometheus/prometheus.yml`, which resolves to
`docker/observability/prometheus/prometheus.yml`. This is why a service's config directory should move
with its compose file — do that and the paths need no editing at all.

Verify what any path actually resolved to:

```bash
docker compose -f docker/compose.all.yml config | grep 'source:'
```

### What stays shared across all included files

Everything merges into a single Compose project named `docker`, which has three consequences:

- **Networks** are declared once (`main-network`, `kafka-network` in `docker-compose.yml`) and
  referenced everywhere else without redeclaring.
- **Named volumes** keep the `docker_` project prefix regardless of which file declares them — so
  moving a volume declaration between included files never renames or recreates it.
- **Service names** must be unique project-wide, and each one becomes a DNS alias on its network.
  That is what `caddy/Caddyfile` targets (`reverse_proxy grafana:3000`), so a service can move
  between files without touching Caddy.

### Disabling a stack

Comment out its include. The observability stack is the useful case — it is roughly 3 GB of RSS:

```yaml
  # - observability/docker-compose.yml
```

Note that a commented-out service is no longer in the rendered config, so
`up -d --remove-orphans` will remove its containers. Named volumes and bind mounts survive, but you
need `up -d` rather than `docker start` to bring it back. See
[Stopped / not running](#stopped--not-running) for what is currently disabled and why.

## Adding a new service

Every file a new service touches. Steps 1-4 are required for anything you want reachable at
`<name>.homelab`; skip 3 and 4 for backing services (databases, brokers) with no web UI.

Matomo is the cautionary example — it got step 1 and nothing else, so it collided on a host port,
never started, had no `.homelab` URL, and never showed up in monitoring.

### 1. Compose definition

Give the service its own `docker/<name>/docker-compose.yml` and add an `include:` entry to
`docker/compose.all.yml` — that is the dominant pattern now (see
[Repository layout](#repository-layout)) and it keeps the compose file next to the config it mounts.
Adding to the shared `docker/docker-compose.yml` still works and is fine for a single container with
no config directory of its own.

The rest of the stack depends on these three keys:

```yaml
services:
  <name>:
    container_name: <name>       # Caddy addresses the container by this name
    restart: unless-stopped
    networks:
      - main-network             # Caddy can only reach containers on this network
```

**Check the host port before publishing one.** Caddy reaches the container over `main-network`, so a
`ports:` entry is only needed for direct host access. To see what is already claimed:

```bash
grep -rhoE '^[[:space:]]+- "?[0-9]{2,5}:' --include='*.yml' docker \
  | grep -oE '[0-9]{2,5}' | sort -n | uniq -d
```

Any duplicate is a collision, except `53` (pihole binds tcp+udp) and `443` (caddy binds tcp+udp),
which are one service claiming both protocols. A real collision leaves the container in `created`
with `Bind for 0.0.0.0:<port> failed: port is already allocated` — note that this does **not** appear
as an exited container, so it is easy to miss. See
[Stopped / not running](#stopped--not-running) for the matomo case.

### 2. DNS record

In `docker/pihole/etc-dnsmasq.d/10-homelab.conf`:

```
host-record=<name>.homelab,10.0.0.32
```

Every Caddy host needs one — there is no wildcard covering `*.homelab`. (The `address=` line for
archivebox is a special case, needed for its per-snapshot subdomains.)

### 3. Caddy route

In `docker/caddy/Caddyfile`:

```
http://<name>.homelab {
  reverse_proxy <container_name>:<internal_port>
}
```

That port is the **container's** internal port, not the published host port.

### 4. Gatus monitor

In `docker/gatus/config/config.yaml`, under the group that fits — `infrastructure`, `monitoring`,
`apps`, `data-and-ai`, or `projects`:

```yaml
  - name: <Name>
    group: <group>
    url: http://<name>.homelab
    interval: 60s
    conditions:
      - "[STATUS] == 200"
```

Use a real health endpoint where the service offers one (`/api/health`, `/healthz`,
`/api/heartbeat` are all in use already). Gatus follows redirects, so a plain `GET /` that 302s to a
login page still passes.

### 5. README tables

Add a row to [Applications](#applications) or
[Backing / infrastructure services](#backing--infrastructure-services). If the service bakes its
public URL in at startup, also add it to
[Services requiring URL change](#services-requiring-url-change-between-localhost-and-homelab).

### 6. Secrets

Shared variables live in `docker/.env`. Services with their own use `docker/<name>/.env` (wired up
via `env_file:` in the include) or `<name>/docker-compose.env`. Naming an `env_file` **replaces** the
default `.env` lookup, so a service that also needs `${TZ}` has to list both files — see the
navidrome entry in `compose.all.yml` for the worked example.

### 7. Deploy and verify

Commit and push on the Mac, pull on the server, then:

```bash
docker compose -f docker/compose.all.yml up -d <name>
docker compose -f docker/compose.all.yml exec pihole pihole reloaddns
docker compose -f docker/compose.all.yml restart caddy gatus
```

Verify one layer at a time, so a failure points at the layer that broke:

```bash
dig +short <name>.homelab @192.168.1.150     # DNS resolves
docker ps --filter name=<name>               # container is actually up
curl -sI http://<name>.homelab               # full path: DNS -> Caddy -> container
```

Then confirm the monitor registered and is passing:

```bash
curl -s http://localhost:8082/api/v1/endpoints/statuses \
  | python3 -c "import json,sys; [print(e['name'], e['results'][-1]['success']) for e in json.load(sys.stdin)]"
```

### Not currently required

Neither dashboard needs a per-service edit today: `homepage/config/services.yaml` is still the stock
example config, and `glance/config/home.yml` uses widgets rather than a service list. If either gets
customized, they become step 8.


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


### Upgrading the observability stack

Pull, recreate, then watch Grafana come up — the migration runs on first boot of a new image, so the logs are where a bad upgrade shows itself:

```bash
docker compose -f docker/compose.all.yml pull prometheus grafana alloy
docker compose -f docker/compose.all.yml up -d prometheus grafana alloy
docker compose -f docker/compose.all.yml logs -f grafana
```

### If Grafana crash-loops on the migration

A half-applied schema migration leaves `grafana.db` in a state Grafana can't boot from, so it restarts into the same error forever. Wiping the volume is the whole fix. The compose project name defaults to the directory holding the file (`docker/`), which is why the volume is `docker_grafana_data` and not `grafana_data`:

```bash
docker compose -f docker/compose.all.yml stop grafana
docker volume rm docker_grafana_data
docker compose -f docker/compose.all.yml up -d grafana
```

**This deletes real state.** `grafana_data` is mounted at `/var/lib/grafana` (`docker-compose.yml:287`), so the wipe destroys `grafana.db`: dashboards created in the UI, alert rules added in the UI, annotations, API keys, and any users beyond admin. If there's anything in there you care about, export it before running the `rm` — a crash-looping Grafana can't export, so this is a decision you make once and can't take back.

**What returns on its own.** `./observability/grafana/provisioning` and `grafana.ini` are bind mounts, not part of the volume, so they survive untouched: the datasources and the four provisioned dashboards (`overview.json`, `homelab.json`, `y0neis-dashboard.json`, `observability/logs-dashboard.json`) reload at boot, and the admin login is recreated from `GF_SECURITY_ADMIN_USER` / `GF_SECURITY_ADMIN_PASSWORD` in compose. A stack whose dashboards all live in `provisioning/` loses nothing but the SQLite DB.

## N8N

localhost:5678

- Reset password
  1. `docker exec -it docker-n8n-1 sh`
  2. `n8n user-management:reset`
  3. `docker compose -f docker/docker-compose.yml restart n8n`


## Dozzle

localhost:8083

## PiHole

### Pointing a device at Pi-hole for DNS

On any device that should get ad-blocking and resolve `*.homelab` names, **replace the public
resolvers with the VM's IP**:

|remove|use instead|
|-|-|
|`1.1.1.1`|`192.168.1.150` (the Ubuntu VM)|
|`8.8.8.8`||

Pi-hole runs in Docker on the VM and publishes port 53, so the VM's IP *is* the DNS server.
Leaving `1.1.1.1` or `8.8.8.8` in the list defeats the point — the OS will happily use the
public resolver instead, so ads come back and `*.homelab` hostnames fail to resolve, seemingly
at random. Set it per-device (macOS: WiFi > Details > DNS) or once in the router's DHCP
settings so every device picks it up.

> **One exception — do not do this on the VM itself.** The VM's own upstream resolvers in
> `/etc/netplan/01-network-manager-all.yaml` must stay public (`1.1.1.1`, `9.9.9.9`). Pointing
> the VM at itself creates a resolution loop, and that netplan step is what frees port 53 for
> Pi-hole in the first place. Same applies to Pi-hole's own upstream setting.

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

### Updating the auth key

The full loop, start to finish. Step 1 and step 5 are in the Tailscale admin console, the rest on the server.

**1. Generate a new auth key**

https://login.tailscale.com/admin/settings/keys → *Generate auth key*:

- Description: `homelab-docker`
- Reusable: **yes** (the container re-uses it on every fresh state dir)
- Expiration: 90 days
- Ephemeral: **no** (ephemeral nodes disappear from the tailnet when they go offline)
- Tags: `tag:container`

The tag isn't optional. The container passes `--advertise-tags=tag:container`
(`docker-compose.yml`), and Tailscale rejects a key whose tags don't cover what the node
tries to advertise. `tag:container` also has to exist in `tagOwners` under Access Controls —
see the TailScale setup section above.

Copy the key when it's shown; the console won't display it again.

**2. Put it in `docker/.env` on the server**

`docker/.env` is git-tracked, but only with the placeholder `TS_AUTHKEY=changeMe` — the real
key lives on the server copy and is never committed. So edit it in place there rather than
committing and pulling:

```bash
ssh logan@<server>
cd ~/homelab/docker   # wherever the repo lives on the server
nano .env             # set TS_AUTHKEY=tskey-auth-...
```

Only `.env` needs touching. `docker-compose.yml` already reads `TS_AUTHKEY=${TS_AUTHKEY}`,
so nothing in the YAML changes when the key rotates.

**3. Recreate the container**

`docker compose restart` won't do it — that reuses the existing container with its old
environment. The container has to be recreated so the new `TS_AUTHKEY` gets baked in:

```bash
docker compose -f compose.all.yml up -d tailscale
```

Compose sees the changed env var and recreates just that service. If it ever decides
nothing changed, force it:

```bash
docker compose -f compose.all.yml up -d --force-recreate tailscale
```

**4. Verify**

```bash
docker compose -f compose.all.yml exec tailscale tailscale status
```

The node should show as online. Then confirm it's still in the tailnet at
https://login.tailscale.com/admin/machines, and that the `10.0.0.0/24` subnet route is still
approved — a re-auth can drop route approval, and losing it breaks `*.homelab` access from
outside the house without the container itself looking broken.

**5. Revoke the old key**

Back on the Keys page, once the new key is confirmed working.

#### If the new key seems to do nothing

`TS_AUTHKEY` is only consumed by the container's entrypoint when there's no valid node state
in `~/docker-volumes/tailscale/state` (the volume mount in `docker-compose.yml`). If the node
is still logged in and authorized, the new key is simply ignored — recreating changes nothing,
and that's fine: the node stays connected on its existing credentials. A new key only takes
effect when the node is logged out or its old key expired.

That's also why key expiry doesn't knock the node offline on its own. Auth keys authenticate
the *initial* login; the node key that gets issued is what keeps it connected, and it has its
own expiry (Machines → the node → *Disable key expiry* if you'd rather it never need
re-auth).

To deliberately force a re-auth with the new key:

```bash
docker compose -f compose.all.yml exec tailscale tailscale logout
docker compose -f compose.all.yml up -d --force-recreate tailscale
```

Nuclear option, if the state dir itself is the problem — this makes the node re-register from
scratch and it may come back as a duplicate (`tailscale-1`) in the machines list:

```bash
docker compose -f compose.all.yml rm -fs tailscale
sudo rm -rf ~/docker-volumes/tailscale/state/*
docker compose -f compose.all.yml up -d tailscale
```

### Setup

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

**Currently disabled.** The whole komodo stack is commented out in
`docker/docker-compose.yml` (since 2026-08-13) because the VM's vCPU still has no AVX,
so `komodo-mongo` dies on startup and `komodo-core` follows it down. On 2026-08-20 the
three containers were still running as compose *orphans* — `docker compose up -d` does
not remove containers that have been deleted from the compose file — and had racked up
15,397 (`komodo-core`) and 9,706 (`komodo-mongo`) restarts. They were removed with:

```
docker rm -f komodo-core komodo-mongo komodo-periphery
```

The `docker_komodo-mongo-data` / `docker_komodo-mongo-config` volumes are untouched, so
the database survives. To re-enable, change the vCPU type as above (or pin `mongo:4.4`,
the last non-AVX release) and uncomment the block. Pass `--remove-orphans` when bringing
the stack up after commenting a service out, or leftovers keep running and restarting
invisibly.

[Backup and Restore | Komodo](https://komo.do/docs/setup/backup)

## Karakeep

All of Hoarder's data are in the DATA_DIR. If you can periodically snapshot that folder, that would take a full backup of hoarder. You don't need to backup meillisearch as the data there can be reconstructed.

```bash
mkdir -p ~/backups && ssh logan@192.168.1.150 \
  "docker run --rm -v karakeep-data:/data alpine tar czf - -C /data ." \
  > ~/backups/karakeep-backup-$(date +%Y%m%d-%H%M%S).tar.gz
```

- If admin forgets password: https://docs.karakeep.app/FAQ/#if-you-are-an-administrator

### Reset a lost admin password

The admin panel (Admin Settings -> Users List -> reset password action) covers non-admin users.
If you're locked out of the admin account itself, edit the SQLite DB directly. Karakeep must be
stopped first:

```bash
docker compose -f docker/compose.all.yml stop karakeep-web

docker volume ls | grep karakeep        # confirm the name (likely docker_karakeep-data)
docker run --rm -it -v docker_karakeep-data:/data alpine sh
```

Inside that shell:

```sh
apk add --no-cache sqlite
sqlite3 /data/db.db
```

```sql
.tables                             -- list the tables, if you need to poke around
select id, email, role from user;   -- in case you forgot which email you signed up with
update user set password='$2a$10$5u40XUq/cD/TmLdCOyZ82ePENE6hpkbodJhsp7.e/BgZssUO5DDTa', salt='' where email='<your@email>';
.quit
```

That hash is the documented one for the password `adminadmin`. Then:

```bash
docker compose -f docker/compose.all.yml start karakeep-web
```

Log in at http://karakeep.homelab with your email + `adminadmin` and change it immediately in User
Settings. Use single quotes around the hash (the `$` segments would otherwise get expanded by the
shell) — that's why the interactive shell is easier than a one-liner.

## Linkwarden

Bookmark manager and web archiver at http://linkwarden.homelab (also http://localhost:3000).
Runs alongside Karakeep rather than replacing it — the two overlap in purpose.

Three containers, defined in `linkwarden/docker-compose.yml` and included from `compose.all.yml`:

| Container | Purpose | Named volume |
|-|-|-|
| `linkwarden` | the app (bundles its own headless browser for archiving) | `linkwarden_data` (`/data/data`) |
| `linkwarden-postgres` | its own Postgres 16 | `linkwarden_pgdata` |
| `linkwarden-meilisearch` | full-text search index | `linkwarden_meili` |

Upstream calls the latter two just `postgres` and `meilisearch`; they are prefixed here because
`postgres` already exists as a top-level service in `docker-compose.yml`.

**Deploy** (on the server, after `git pull` — edits on the Mac are inert until pulled):

```
docker compose -f docker/compose.all.yml up -d linkwarden
docker compose -f docker/compose.all.yml up -d --force-recreate pihole caddy gatus homepage
```

The second line picks up the bind-mounted config edits (DNS record, Caddy site block, Gatus
endpoint, Homepage tile). `--force-recreate` is what makes those processes re-read their files.

Register the first account promptly after it comes up — it becomes the admin. To close signups
afterwards, add `NEXT_PUBLIC_DISABLE_REGISTRATION=true` to `linkwarden/.env` and
`docker compose -f docker/compose.all.yml up -d linkwarden` (not `restart`, which ignores env
changes).

Secrets are in `linkwarden/.env`. `NEXTAUTH_SECRET`, `POSTGRES_PASSWORD` and `MEILI_MASTER_KEY`
must be three *different* values; regenerate any with `openssl rand -hex 32`. If you change
`POSTGRES_PASSWORD` on an existing install, `DATABASE_URL` in the same file has to be updated to
match, and the password changed inside the running DB — the env var only sets it on first init.

AI auto-tagging against the local `ollama` service is wired but commented out at the bottom of
`linkwarden/.env`; uncomment both lines and pull the model first (`docker exec ollama ollama pull llama3.1`).

Backup — the app data and the DB; the Meilisearch index is derived and can be rebuilt:

```
ssh logan@10.0.0.32 "docker run --rm -v docker_linkwarden_data:/data -v \$HOME:/backup alpine sh -c 'tar czf /backup/linkwarden-data-\$(date +%Y%m%d-%H%M%S).tar.gz -C /data .'"
ssh logan@10.0.0.32 "cd ~/homelab/docker && docker compose -f compose.all.yml exec -T linkwarden-postgres pg_dump -U postgres postgres" > linkwarden-db_$(date +%F).sql
```

`pg_dump postgres` is the right database — `POSTGRES_DB` isn't set in `linkwarden/docker-compose.yml`,
so it defaults to `postgres`. What it does *not* capture is globals: roles, their passwords, and
tablespaces. That's harmless as long as `postgres` is the only role, because the Postgres entrypoint
recreates that superuser from `POSTGRES_PASSWORD` on a fresh volume. If a second role is ever added,
use `pg_dumpall` instead (`-c` prefixes the dump with DROP statements so it can be replayed over an
existing cluster):

```
ssh logan@10.0.0.32 "cd ~/homelab/docker && docker compose -f compose.all.yml exec -T linkwarden-postgres pg_dumpall -U postgres -c" > linkwarden-all_$(date +%F).sql
```

**Keep the `-T`.** It disables TTY allocation, and a TTY rewrites `LF` as `CRLF` on the way out — so
the otherwise-identical `docker exec -t ... > file` found in most forum posts produces a dump with
mangled line endings that can fail or silently corrupt on restore. Same trap applies to the `tar`
above: never let a TTY sit between a binary stream and a redirect.

Both commands are crash-consistent, not quiesced. That's fine for the SQL dump (`pg_dump` runs in a
single transaction), but the `linkwarden_data` tar can catch a half-written archive file. For backups
that actually matter, add `linkwarden_data` and `linkwarden_pgdata` to a **backrest** plan rather than
relying on these one-liners — you get scheduling, dedup, and retention for free.

Full reset (wipes everything):

```
docker compose -f docker/compose.all.yml rm -fsv linkwarden linkwarden-postgres linkwarden-meilisearch
docker volume rm docker_linkwarden_data docker_linkwarden_pgdata docker_linkwarden_meili
docker compose -f docker/compose.all.yml up -d linkwarden
```

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

### Creating an admin user / resetting a password

Upstream documents these as bare `archivebox` commands, run from inside the data folder:

```
cd data/   # run commands inside your data folder
archivebox manage createsuperuser
archivebox manage changepassword <username>
```

> Careful: the upstream docs show `createsuperuser <username>`, but that is wrong — these are Django management commands, and Django's `createsuperuser` takes the username as the `--username` flag, not a positional. Passing it positionally just prints the usage block. `changepassword` **does** take a positional username.

Here ArchiveBox only exists inside the container, so run them through compose instead. The image's entrypoint is already `archivebox`, and `/data` is already the working directory, so the `cd data/` step and the leading `archivebox` both drop off:

```
docker compose -f compose.all.yml run --rm archivebox manage createsuperuser
docker compose -f compose.all.yml run --rm archivebox manage changepassword <username>

# non-interactive username, still prompts for email + password:
docker compose -f compose.all.yml run --rm archivebox manage createsuperuser --username admin
```

Both prompt interactively, so run them from a real terminal — not with `-T`, which is only for piping stdin (as in the bulk `add` below).

Or shell into the running container and use the upstream commands as written:

```
docker compose -f compose.all.yml exec archivebox bash
# or, without compose (container_name is archivebox):
docker exec -it archivebox bash

# now you're in /data, with archivebox on PATH:
archivebox manage createsuperuser                      # prompts for username, email, password
archivebox manage createsuperuser --username admin     # or name it up front
archivebox manage changepassword admin
archivebox status
```

`exec` attaches to the container that's already running, so it needs `up -d` to have happened first — unlike `run`, which starts a throwaway one. Add `--user root` if you need to fix file ownership under `/data`.

Add URLs from the CLI (or paste them in the Web UI):

```
docker compose -f compose.all.yml run archivebox add 'https://example.com'
docker compose -f compose.all.yml run -T archivebox add < ~/bookmarks.txt
```

### Exporting the index (HTML / JSON / CSV)

`archivebox list` dumps the snapshot index to **stdout**. Upstream documents it as bare commands run from inside the data folder:

```
archivebox list --html --with-headers > index.html
archivebox list --json --with-headers > index.json
archivebox list --csv=timestamp,url,title > index.csv
```

`--with-headers` wraps the output in a full HTML page / adds the JSON metadata envelope (`copyright_info`, `last_run_cmd`, …) instead of emitting a bare fragment or array. It doesn't apply to `--csv`, which takes its column list inline.

Same container caveat as above — `archivebox` only exists inside the container, so it has to run there. The catch is that `>` is interpreted by *whichever shell you typed it into*, so where the file lands depends on where you put the redirect.

**Inside the container** (files land in `/data`, i.e. `~/docker-volumes/archivebox/` on the host):

```
docker exec -it archivebox bash

# now in /data, with archivebox on PATH — upstream commands work verbatim:
archivebox list --html --with-headers > index.html
archivebox list --json --with-headers > index.json
archivebox list --csv=timestamp,url,title > index.csv
```

**From the server shell**, redirect outside the container so the file lands in the current directory on the VM:

```
docker exec archivebox archivebox list --html --with-headers > index.html
```

`docker exec` bypasses the image's entrypoint, so `archivebox` has to be repeated as the command.

### Running it from the MacBook over SSH

Put the redirect on the *local* side of the SSH command and the file is written to your Mac, not the server — SSH just pipes the container's stdout back over the connection:

```
ssh logan@192.168.1.150 'docker exec archivebox archivebox list --html --with-headers' > index.html
ssh logan@192.168.1.150 'docker exec archivebox archivebox list --json --with-headers' > index.json
ssh logan@192.168.1.150 'docker exec archivebox archivebox list --csv=timestamp,url,title' > index.csv
```

Single quotes matter: they keep the remote command intact so the local shell doesn't try to expand anything in it, and they keep `>` local. Moving the `>` inside the quotes (`ssh host 'archivebox list ... > index.html'`) writes the file on the server instead.

The compose form works the same way, it just needs a `cd` first since `-f compose.all.yml` is a relative path — and `-T` to suppress TTY allocation, otherwise the stream comes back with CRLF line endings baked in:

```
ssh logan@192.168.1.150 'cd ~/homelab/docker && docker compose -f compose.all.yml run --rm -T archivebox list --json --with-headers' > index.json
```

`docker exec` is the cheaper option here — it reuses the already-running container, while `run --rm` spins up a throwaway one for each invocation.

One cosmetic thing: `archivebox list` prints a `Listed N snapshots` progress line to **stderr**, so it shows up in your terminal but never contaminates the redirected file. Append `2>/dev/null` inside the quotes if you want it silenced.

### Backing up the data folder to the MacBook

Same idea as above — the redirect stays local, so the tarball lands on the Mac and nothing is written on the server:

```
mkdir -p ~/backups && \
ssh logan@192.168.1.150 'docker stop archivebox >/dev/null && tar czf - -C ~/docker-volumes archivebox; docker start archivebox >/dev/null' \
  > ~/backups/archivebox-$(date +%Y%m%d-%H%M%S).tar.gz
```

Stops the container, streams a gzipped tar of the whole `/data` folder straight to the Mac, then restarts it — the `;` before `docker start` means the restart runs even if the transfer fails. Downtime is a few seconds at the current ~19M.

The container is stopped because the index is SQLite: a hot copy can catch `index.sqlite3` mid-write with unmerged `-wal`/`-shm` files. Drop the `docker stop`/`docker start` parts for a zero-downtime copy — the `archive/` snapshots are immutable so they copy fine hot, but the index may be inconsistent. `sudo` isn't needed; the files are owned by UID 911 but world-readable.

Verify and restore:

```
# check the archive
tar tzf ~/backups/archivebox-*.tar.gz | head

# restore (wipes the current data dir)
ssh logan@192.168.1.150 'docker stop archivebox && rm -rf ~/docker-volumes/archivebox'
ssh logan@192.168.1.150 'tar xzf - -C ~/docker-volumes' < ~/backups/archivebox-20260816-XXXXXX.tar.gz
ssh logan@192.168.1.150 'docker start archivebox'
```

Note that `backup-remote-volumes.sh` doesn't cover this — it only walks named Docker volumes, and `/data` here is a bind mount.

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

### Changing the mount path (external drive on the VM)

Two separate things have to be true: the host path has to be **mounted before the container is created**, and `NAVIDROME_MUSIC_DIR` has to point at it. Miss either one and Navidrome shows **"not a valid path"** — Docker silently creates the missing bind source as an empty directory rather than failing, so `/music` inside the container is an empty dir.

**1. Make the mount permanent (do this first)**

Add the SSD to the VM: `VM > Hardweare > Add > USB Device > Use USB Vendor/Device ID > Select the SSD`

A bind mount resolves its source once, at container-create time. If the container already existed when you ran `mount /dev/sdb1 /mnt/ssd`, it is still bound to the empty pre-mount directory — mounting afterwards does not propagate into a running container. The same trap fires on every reboot if the mount isn't in `/etc/fstab`.

```
sudo mkdir -p /mnt/ssd
```

First find the device — `/dev/sdb1` below is the typical answer, not a given:

```
sudo dmesg | tail -20       # right after the USB passthrough: "[sdb] Attached SCSI disk"
lsblk -o NAME,SIZE,TYPE,TRAN,MODEL,FSTYPE,LABEL,MOUNTPOINTS
```

`sda` is the VM's virtual boot disk (blank or `sata` under `TRAN`, model `QEMU HARDDISK`) — leave it alone. The SSD is the row with `TRAN=usb` and a size matching the physical drive; the indented rows under it are its partitions. Whatever disk name that row shows in the `NAME` column — `sdb`, `sdc`, whatever it happens to be — is what goes in the next command:

```
lsblk -f /dev/<disk-from-NAME-above>   # e.g. lsblk -f /dev/sdb
                                       # whole disk: note FSTYPE + UUID per partition
```

Add a line to `/etc/fstab` (`sudo vim /etc/fstab`), keyed by **UUID** — the `sdb` letter is assigned in detection order and can shift between boots:

```
# ext4:
UUID=<uuid>  /mnt/ssd  ext4     defaults,nofail                          0 2
# exFAT/NTFS (typical for an external drive):
UUID=<uuid>  /mnt/ssd  exfat    defaults,nofail,uid=1000,gid=1000,umask=022  0 0
# hfsplus (what the SSD external drive actually is — Mac-formatted):
UUID=<uuid>  /mnt/ssd  hfsplus  ro,nofail                                0 0
```

Or skip the editor and append:

```
# substitute the partition you identified above for /dev/sdb1
echo "UUID=$(sudo blkid -s UUID -o value /dev/sdb1)  /mnt/ssd  ext4  defaults,nofail  0 2" | sudo tee -a /etc/fstab
```

`nofail` matters — without it the VM drops to emergency mode at boot if the SSD is ever unplugged. Then verify before trusting it to a reboot:

```
sudo findmnt --verify                 # syntax-checks the whole fstab
sudo umount /mnt/ssd && sudo mount -a && ls /mnt/ssd
findmnt /mnt/ssd                      # prints a row = actually mounted
```

`findmnt` printing a row is the confirmation you want — `ls` succeeding proves nothing, since an unmounted mountpoint is just an empty directory that lists fine. A syntax error in `fstab` is one of the few ways to make a VM unbootable, hence the `--verify` pass first. `findmnt -S /dev/sdb1` goes the other way and lists every mountpoint the device is currently attached at, which is how you catch it already being mounted somewhere else (`mount` will refuse with `already mounted on ...`).

**2. Point the env var at it**

In `docker/navidrome/.env`:

```
NAVIDROME_MUSIC_DIR=/mnt/ssd/music   # or just /mnt/ssd if the files are at the drive root
```

**3. Recreate, don't restart**

```
docker compose -f compose.all.yml up -d --force-recreate navidrome
docker exec navidrome ls /music | head
```

If that `ls` shows your music, the UI picks it up on the next scan.

Two caveats:

- `navidrome/.env` is git-tracked and shared with the Mac, so setting `/mnt/ssd` there breaks the Mac side. If you run Navidrome in both places, that file wants to be gitignored with a `.env.example` committed instead.
- If the drive is ext4 owned by root with restrictive permissions you'll need `chown`/`chmod` on it, or leave the container running as root (the `user: "1000:1000"` line stays commented).

**Unmounting and remounting the SSD while the container runs**

If you `umount /mnt/ssd` and mount it again — swapping the drive, a `mount -a` after an fstab edit, the SSD dropping off and coming back — the running container does **not** follow. Its bind mount is attached to the filesystem that was there when the container started, and Docker mounts it `rprivate`, so a new mount landing on `/mnt/ssd` afterwards doesn't propagate into the container's mount namespace. Navidrome keeps looking at the old, now-detached filesystem and `/music` goes empty or stale mid-scan.

Restart to re-resolve it:

```
docker compose -f compose.all.yml restart navidrome
docker exec navidrome ls /music | head    # confirm it's back
```

This is the one case where `restart` is the right tool. Everywhere else in this section it isn't — restart reuses the existing container config, so it silently ignores `.env` and compose changes, which is why step 3 needs `up -d --force-recreate`. Here the config hasn't changed at all; the container just has to redo the mount against whatever is on `/mnt/ssd` now. Verify the host side is actually mounted first (`findmnt /mnt/ssd` prints a row), or the restart just re-binds the empty mountpoint.

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

### Running it standalone (outside the homelab stack)

Navidrome doesn't depend on anything else in the stack — no Caddy, no Pi-hole, no `main-network`. If the repo isn't checked out, or you just want it on some other machine, one `docker run` is the whole install:

```
docker run -d --name navidrome --restart unless-stopped \
  -p 4533:4533 -e TZ=America/Chicago \
  -v navidrome_data:/data \
  -v /Volumes/Elements/Music:/music:ro \
  deluan/navidrome:latest

docker exec navidrome ls /music | head
```

Swap `/Volumes/Elements/Music` for wherever the library actually is on that host. The same rules from the rest of this section still apply: `/data` has to be the named volume (not a bind mount) or the SQLite DB breaks mid-scan, the music mount stays `:ro`, and the drive has to be mounted *before* the container is created or Docker silently binds an empty directory. Reach it at http://localhost:4533 and create the admin account on first load.

Note the volume is plain `navidrome_data` here, not the `docker_navidrome_data` that Compose creates — the project prefix only comes from `compose.all.yml`. So a standalone run gets its own separate database, and the reinstall commands above won't touch it.

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

### Backup process

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

## Immich

### Server commands (`immich-admin`)

The `immich-server` image ships an administrative CLI. Run it inside the running container — either directly by container name, or through compose (paths below are relative to the repo root):

```
docker exec -it immich-server immich-admin help
docker compose -f docker/compose.all.yml exec immich-server immich-admin help
```

```
docker exec -it immich-server immich-admin list-users
docker exec -it immich-server immich-admin reset-admin-password
docker exec -it immich-server immich-admin disable-password-login
docker exec -it immich-server immich-admin enable-password-login
docker exec -it immich-server immich-admin change-media-location
```

`-it` matters for `reset-admin-password` — it prompts for the new password interactively.


## Tube Archivist

Tube Archivist is `tubearchivist` + `archivist-es` (Elasticsearch 8) + `archivist-redis`.
If the web UI is down or search returns nothing, check `archivist-es` first — the app
container depends on it and will crash-loop on its own if ES never comes up.

### `archivist-es` crash-loop: "failed to obtain node locks"

Symptom: `docker ps` shows `archivist-es` Restarting, `tubearchivist` Restarting behind
it, and the restart counter is in the thousands:

```
docker inspect archivist-es --format 'Status={{.State.Status}} Restarts={{.RestartCount}}'
```

The logs end with a fatal boot exception every ~20s:

```
fatal exception while booting Elasticsearch
java.lang.IllegalStateException: failed to obtain node locks, tried
  [/usr/share/elasticsearch/data]; maybe these locations are not writable or
  multiple nodes were started on the same data path?
Caused by: java.nio.file.NoSuchFileException: /usr/share/elasticsearch/data/node.lock
  Suppressed: java.nio.file.AccessDeniedException: /usr/share/elasticsearch/data/node.lock
```

The message is misleading — it is **not** two nodes sharing a data path. Read the
*suppressed* `AccessDeniedException`: ES could not create `node.lock` at all. The
Elasticsearch image runs as uid **1000**, gid **0**, and the bind-mount source on the
host was owned `root:root 0755`, so uid 1000 had no write permission:

```
$ ls -ld ~/docker-volumes/tubearchivist/es
drwxr-xr-x 2 root root 4096 Jun 18 23:50 /home/logan/docker-volumes/tubearchivist/es
```

Fix — chown the bind-mount source to the uid/gid the container runs as, then restart:

```
sudo chown -R 1000:0 ~/docker-volumes/tubearchivist/es
docker compose -f docker/compose.all.yml restart archivist-es tubearchivist
```

Verify it actually came up — ES writes `node.lock` and its data dirs on first
successful boot, and cluster health should reach GREEN:

```
$ ls ~/docker-volumes/tubearchivist/es
_state  indices  node.lock  nodes  snapshot  snapshot_cache

docker logs --tail 20 archivist-es | grep -i 'health status changed'
# ... Cluster health status changed from [YELLOW] to [GREEN]
```

Confirm the restart counter has stopped climbing (run it twice, a minute apart).

### Why this is worth catching early

The ES JVM is started with `-Xms1g -XX:+AlwaysPreTouch`, so **every** failed boot
allocates and physically touches a full 1 GB of heap before dying. A container looping
every ~20s therefore burns ~1.2 GB of RSS continuously and hammers the disk re-reading
the image, while never once serving a request. This went unnoticed from 2026-06-18 to
2026-08-20 and reached **29,000+ restarts** — it was a large share of the host sitting
at 97% memory with a load average near 100.

When a service looks "up" in `docker ps` but is useless, check restart counts across the
whole stack, not just memory:

```
for c in $(docker ps --format '{{.Names}}'); do
  r=$(docker inspect "$c" --format '{{.RestartCount}}')
  [ "$r" -gt 0 ] && echo "$r  $c"
done | sort -rn
```


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

https://github.com/morpheus65535/bazarr && https://github.com/sonarr/sonarr && https://github.com/Radarr/Radarr

https://github.com/rcourtman/pulse

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
| linkwarden | `NEXTAUTH_URL` | `linkwarden/.env` | `http://localhost:3000/api/v1/auth` | `http://linkwarden.homelab/api/v1/auth` |
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
| linkwarden | http://localhost:3000 | http://linkwarden.homelab | set on first run (first user is admin) |
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



## Stopped / not running

Snapshot taken 2026-08-21: 68 of 73 containers running. Everything below is either deliberately
disabled or broken, so check here before assuming a service went missing. Re-list current state with:

```bash
docker ps -a --filter status=exited --filter status=created --filter status=restarting \
  --format "{{.Names}}\t{{.Status}}"
```

| Service | State | Reason |
|-|-|-|
| archivebox | Exited (0) | deliberately disabled — memory |
| paperless-ngx-webserver | Restarting (1) | crash loop — `PAPERLESS_SECRET_KEY` unset |
| docker-tailscale-1 | Exited (1) | expired auth key |
| docker-live-auction-1 | Exited (255) | SQLite schema drift |
| matomo-app / matomo-cron | Created | host port 8080 already taken by drawio |
| komodo | commented out | MongoDB 5+ needs AVX; VM 100's vCPU lacks it |

### archivebox — deliberately disabled

Disabled 2026-08-21. It was the single largest memory consumer on the VM (~1.8 GB RSS; it runs a
headless Chrome to snapshot pages) while the host was thrashing — 20 GB fully used, swap exhausted,
load average 127, and the kernel reporting *all* tasks stalled on memory 45% of the time. Stopping it
recovered ~1.9 GB and brought load down to ~6.

The `include:` line in `compose.all.yml` is commented out. The service definition in
`archivebox/docker-compose.yml` and the `~/docker-volumes/archivebox` data are untouched.

Re-enable by uncommenting the include, then:

```bash
docker compose -f compose.all.yml up -d archivebox
```

Because archivebox is no longer in the rendered config, `up -d --remove-orphans` will *delete* the
stopped container. That is harmless — the data is a bind mount — but you would then need `up -d`
rather than `docker start` to bring it back.

### paperless-ngx-webserver — crash loop, needs a secret key

`Restarting (1)`, with a restart count past 15,000 and still climbing. Newer paperless-ngx images
refuse to boot when the secret key is unset or left at the default:

```
django.core.exceptions.ImproperlyConfigured: PAPERLESS_SECRET_KEY is not set or is the
default 'change-me' value.
```

`PAPERLESS_SECRET_KEY` is commented out in `paperless-ngx/docker-compose.env`. Generate one and set it:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(64))"
# write the result into paperless-ngx/docker-compose.env as PAPERLESS_SECRET_KEY=<value>
docker compose -f compose.all.yml up -d paperless-ngx-webserver
```

Worth fixing promptly — a tight restart loop burns CPU continuously. `paperless-ngx-db` and
`paperless-ngx-broker` are up and healthy, so only the web tier is down.

### docker-tailscale-1 — expired auth key

`Exited (1)`; last attempt 2026-08-20 04:46.

```
backend error: invalid key: unable to validate API key
boot: failed to auth tailscale: tailscale up failed: exit status 1
```

The `TS_AUTHKEY` expired — Tailscale auth keys last 90 days at most, so this recurs on a schedule.
See [Updating the auth key](#updating-the-auth-key) for the full procedure. The short version: mint a
new key in the admin console, replace it in the env file, then recreate the container with `up -d`
rather than `restart`, since the key is only read at boot.

### docker-live-auction-1 — SQLite schema drift

`Exited (255)`, 10 days before the snapshot.

```
sqlalchemy.exc.OperationalError: (sqlite3.OperationalError) no such column: users.timezone
ERROR:    Application startup failed. Exiting.
```

The image gained a `users.timezone` column but the existing SQLite volume was never migrated, so
startup queries select a column the database does not have. Either apply the upstream migration
against the volume or wipe the database and start fresh — the latter loses existing auction data.

### matomo-app / matomo-cron — host port conflict

Both stuck in `created` and never started, since 2026-08-11:

```
failed to set up container networking: driver failed programming external connectivity
on endpoint matomo-app: Bind for 0.0.0.0:8080 failed: port is already allocated
```

`matomo/docker-compose.yml` publishes `8080:80`, but drawio already owns host port 8080
(`docker-compose.yml:718`). `matomo-cron` is stuck only because it depends on `matomo-app`.

Fix by giving matomo a different host port (e.g. `8083:80`) or by dropping the host publish and
reaching it through Caddy — note matomo has no Caddy site block today, so removing the port binding
means adding one. `matomo-db` (mariadb) is running normally and still holds the data.

### komodo — disabled 2026-08-13 (MongoDB needs AVX)

The komodo stack is commented out in `docker-compose.yml` (~line 503), not missing. MongoDB 5+
requires AVX instructions and VM 100's default QEMU vCPU model does not expose them, so
`komodo-mongo` died with SIGILL in a permanent crash-restart loop. `komodo-core` depends on it, so
the whole stack was commented out together.

`komodo-mongo-data` and `komodo-mongo-config` are deliberately left declared in the `volumes:` block
so the data survives — they look like orphans but are not; do not prune them.

To re-enable: with the VM powered off, run `qm set 100 --cpu host` on the Proxmox host, then
uncomment the block. Fallback if the CPU type can't be changed: pin `mongo:4.4`, the last release
that runs without AVX. `docker/komodo/compose.env` is still there for whenever it comes back.


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


# Adding linux VM and setting up RDP and tailscale

https://www.freerdp.com

https://endeavouros.com
