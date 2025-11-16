
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

- Backup data: `ssh logan@10.0.0.33 'cd ~/homelab/docker && docker compose exec -T uptime-kuma sqlite3 /app/data/kuma.db ".backup /dev/stdout"' > uptime-kuma-backup_$(date +%F).db`

## Tailscale

1. Create account at https://login.tailscale.com/admin
2. Generate auth key and add to env variable
3. `docker compose up --build tailscale`
4. Go to `https://login.tailscale.com/admin/machines` and you should see the machine


## Test Postgres



if you have to rerun the SQL script: `docker compose -f docker/docker-compose.yml exec -T test-db psql -U testuser -d test_database -f docker-entrypoint-initdb.d/10-test-table.sql`


`docker exec -it postgres_db psql -U testuser -d test_database -c 'SELECT * FROM "test-table";'`

# Live-Auction

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

# Redis

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

# Umami

Username: admin
Password: umami

# Ollama

- `docker exec -it ollama ollama list`
- `docker exec -it ollama ollama pull deepseek-r1:1.5b`

# Komodo

Username: admin
Password: changeme

All of Hoarder's data are in the DATA_DIR. If you can periodically snapshot that folder, that would take a full backup of hoarder. You don't need to backup meillisearch as the data there can be reconstructed.

`ssh logan@10.0.0.33 "docker run --rm -v karakeep-data:/data -v \$HOME:/backup alpine sh -c 'tar czf /backup/karakeep-backup-\$(date +%Y%m%d-%H%M%S).tar.gz -C /data .'"`

- You might see this error in the Mongo logs that will prevent the app from working: _WARNING: MongoDB 5.0+ requires a CPU with AVX support, and your current system does not appear to have that!_
  - To fix this, go to the Hardware settings of the VM, Edit the Processors and select `x86-64-v3` as the `Type`. Restart the VM



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

# Deploying on Proxmox

- pveversion --verbose

1. apt install vim

- Since we don't have an enterprise subscription, we have to change the APT repositories, or apt update will fail with `The repository 'https://enterprise.proxmox.com/debian/pve bookworm InRelease' is not signed` [Read Here](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#sysadmin_enterprise_repo)
  1. Comment out the pve-enterprise line at `vi /etc/apt/sources.list.d/pve-enterprise.list`
  2. 

1. Create Ubuntu VM
2. Install Docker
3. Set pihole records to IP of proxmox
4. Set devices to use pihole as DNS
5. Create LXC for tailscale



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
