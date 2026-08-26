# Homelab Repository — Known Issues

Audit of the `add-forgejo` branch as of 2026-08-26. Every line reference below was
verified against the working tree at the time of writing.

Scope: the whole repo — `docker/` (the live fleet), `proxmox/terraform/`,
`proxmox/ansible/`, and repo hygiene. Issues already written up in
`docker/README.md` are marked **[README]** and cross-referenced rather than repeated
in full.

Severity: **H** = broken or a real exposure · **M** = works but wrong/fragile ·
**L** = cosmetic, hygiene, or stale docs.

---

## Contents

- [A. Wired but silently dead](#a-wired-but-silently-dead)
- [B. Observability config & best practice](#b-observability-config--best-practice)
- [C. Services currently broken or degraded](#c-services-currently-broken-or-degraded)
- [D. Secrets & access control](#d-secrets--access-control)
- [E. Backup & restore](#e-backup--restore)
- [F. Addressing, DNS & networking drift](#f-addressing-dns--networking-drift)
- [G. Repo hygiene & committed state](#g-repo-hygiene--committed-state)
- [H. Terraform & Ansible layer](#h-terraform--ansible-layer)
- [I. Placeholders never filled in](#i-placeholders-never-filled-in)
- [What's already right](#whats-already-right)
- [Resolved since the last audit](#resolved-since-the-last-audit)
- [Suggested order of work](#suggested-order-of-work)

---

## A. Wired but silently dead

Things that are configured, evaluate without error, and produce nothing.

### A1 — Alerting goes nowhere (H)

There is no Alertmanager anywhere in the repo, but three separate components are
configured to talk to one:

| Where | Line | What it says |
|-|-|-|
| `docker/observability/prometheus/prometheus.yml` | 8–11 | `alertmanagers` → `targets: []` |
| `docker/observability/grafana/provisioning/datasources/datasources.yml` | 41–45 | datasource `AlertManager` → `http://alertmanager:9093` |
| `docker/observability/loki/loki.yml` | 37 | `ruler.alertmanager_url: http://localhost:9093` |

There is no `alertmanager` service in `docker/observability/docker-compose.yml`, so
`alertmanager:9093` does not resolve. All **9 rules** in
`docker/observability/prometheus/rules/observability.yml` evaluate on schedule and
fire into the void — `ServiceDown`, `PrometheusTargetMissing`,
`PrometheusConfigurationReloadFailure`, `LokiRequestErrors`, `LokiRequestLatency`,
`AlloyDown`, `HighErrorRate`, `DiskSpaceUsage`, `HighContainerCPU`.

Loki's `alertmanager_url` is additionally wrong on the host as well as the port:
`localhost` inside the Loki container is Loki, not a sibling service. It would need
to be `http://alertmanager:9093` even once one exists.

**Net effect:** nothing in the stack can notify anyone. The whole alerting path is
decorative.

### A2 — No node-exporter, so the host is a blind spot (H)

`prometheus.yml:40–43` declares a `node-exporter` job with `targets: []` and a
`# Add node-exporter:9100 when deployed` comment. It was never deployed.

Downstream consequences:

- The `DiskSpaceUsage` alert (`rules/observability.yml:85–97`) queries
  `node_filesystem_avail_bytes` / `node_filesystem_size_bytes`. Those series are
  never collected, so the expression returns empty and the alert **can never fire** —
  it is not "quiet", it is structurally incapable of triggering.
- `grafana/provisioning/dashboards/general/y0neis-dashboard.json:1996` queries
  `node_exporter_build_info` — a permanently empty panel.
- `grafana/provisioning/dashboards/general/homelab.json:830` has a note that on-disk
  Loki size "needs node-exporter on the loki_data volume path" — acknowledged gap.

cAdvisor only sees containers. Host-level CPU, RAM, disk, filesystem, network and
load are uncovered by Prometheus. (Netdata and Beszel are running and do cover some
of this — but neither feeds Prometheus, so no alert rule or Grafana Prometheus panel
can use it.)

### A3 — Tracing references with no tracing backend (M)

| Where | Line | Points at |
|-|-|-|
| `datasources.yml` | 21–23 | `exemplarTraceIdDestinations` → `datasourceUid: jaeger` |
| `datasources.yml` | 33–37 | Loki `derivedFields` → `datasourceUid: jaeger` |
| `docker/docker-compose.yml` | 654 | `live-auction` → `OTEL_EXPORTER_OTLP_ENDPOINT=tempo:4317` |

There is no `jaeger` datasource and no `jaeger` or `tempo` container anywhere in the
repo. `docker-compose.yml:661–662` even has a commented-out `depends_on: tempo`.

So: exemplar links in Prometheus panels and TraceID links in Loki both resolve to a
non-existent datasource, and the `live-auction` app exports spans to a hostname that
does not resolve. Either stand up Tempo and point all three at it, or strip the
references.

### A4 — Gatus monitors two disabled services (M)

`docker/gatus/config/config.yaml` checks `http://komodo.homelab` (line 17–22) and
`http://archivebox.homelab` (line 201) every 60s. Both stacks are deliberately
disabled — komodo is commented out in `docker/docker-compose.yml:427–492`, archivebox's
`include:` is commented out in `docker/compose.all.yml:17`. Both are therefore
permanently red, which trains you to ignore the Gatus board.

Caddy still has live routes for both (`Caddyfile:112–114` → `komodo-core:9120`,
`Caddyfile:193–195` → `archivebox:8000`), so they return 502 rather than 404.

### A5 — Gatus has no alerting configured (M)

`docker/gatus/config/config.yaml` has an `endpoints:` block and nothing else — no
`alerting:`, no `storage:`, no `ui:`, no `security:`. Checks run and fail silently
with no notification provider, and results are held in memory only (lost on every
restart). Same failure class as A1: monitoring that observes but cannot tell you.

---

## B. Observability config & best practice

### B1 — Grafana admin password hardcoded in three places (H)

`admin123` is committed at:

- `docker/observability/docker-compose.yml:108` — `GF_SECURITY_ADMIN_PASSWORD=admin123`
- `docker/observability/grafana/grafana.ini:34` — `admin_password = admin123`
- `docker/homepage/config/services.yaml:42` — the Homepage Grafana widget credential

**`grafana.ini` wins.** A mounted `grafana.ini` overrides the `GF_*` environment
variable, so the compose value is misleading — editing it alone changes nothing.

Should be `${GRAFANA_ADMIN_PASSWORD}` sourced from `docker/.env`, set in one place,
with the `grafana.ini` `[security]` entry removed so the env var is actually
authoritative. Homepage's widget then needs the same value (it has no interpolation
from `docker/.env`, so it needs its own handling).

### B2 — `--web.enable-admin-api` on an unauthenticated Prometheus (H)

`docker/observability/docker-compose.yml:48` enables the admin API. Caddy proxies
`http://prometheus.homelab` (`Caddyfile:85–87`) over plain HTTP with **no
authentication**. Anyone on the LAN can delete the entire TSDB with a single curl to
`/api/v1/admin/tsdb/delete_series`.

Drop the flag unless it is actively in use. `--web.enable-lifecycle` (line 47) is a
milder version of the same exposure — it lets anyone on the LAN force a config
reload.

`--web.enable-remote-write-receiver` (line 49) *is* required, because Alloy
remote-writes into Prometheus.

### B3 — Alloy metrics are collected twice (M)

Two independent paths carry the same series:

- `prometheus.yml:21–24` — Prometheus scrapes `alloy:12345` directly.
- `alloy/config.alloy:18–21` — Alloy scrapes `localhost:12345` (itself) and
  remote-writes to Prometheus.

Identical series arriving by two routes risks duplicate-sample rejection and
inflates cardinality for no benefit. Pick one path.

Related: **cAdvisor is only reachable via Alloy.** `config.alloy:24–29` scrapes
`cadvisor:8080` and remote-writes it; Prometheus has no cAdvisor scrape job of its
own. So if Alloy stops, all container metrics stop, and the `HighContainerCPU` rule
goes silent — while `AlloyDown` (which depends on Prometheus's *direct* scrape of
Alloy) is the only thing that would tell you. For a single host, having Prometheus
scrape cAdvisor directly and dropping Alloy's metrics pipeline entirely (keeping
Alloy for logs only) is simpler and removes both problems at once.

### B4 — `HighContainerCPU` alerts on the wrong series (M)

`rules/observability.yml:99–101`:

```
rate(container_cpu_usage_seconds_total{image!=""}[5m]) > 0.8
```

No aggregation. `container_cpu_usage_seconds_total` is emitted per cgroup per CPU,
so this evaluates per-core-per-container and will alert on a container using 80% of
*one* core — while the summary text says "CPU > 80%" as if it were the container
total. Needs `sum by (name) (...)`, and on a multi-core host a threshold reflecting
the core count.

### B5 — Prometheus retention has no size cap and no external labels (M)

`docker/observability/docker-compose.yml:46` sets
`--storage.tsdb.retention.time=200h` only. There is no
`--storage.tsdb.retention.size`, so a cardinality spike can fill the disk before the
time-based retention ever kicks in — on a VM that has already been through a
memory-thrash incident (see `docker/README.md`, archivebox section), that is a real
risk.

`prometheus.yml` also has no `global.external_labels`. Nothing identifies this
Prometheus if a second one is ever added or if data is federated/remote-written out.

### B6 — Loki `reject_old_samples_max_age` equals the retention period (L)

`loki/loki.yml:53–55` sets `retention_period: 168h` and
`reject_old_samples_max_age: 168h`. That is coherent, but it means any log line
older than the retention window is dropped at ingest rather than stored and aged
out — worth knowing when backfilling or when a container's clock drifts.

### B7 — `alloy` publishes a host port with no Caddy route (L)

`docker/observability/docker-compose.yml:73` publishes `12345:12345` (the Alloy UI).
There is no `alloy.homelab` block in the Caddyfile and no Pi-hole record, so it is
reachable only as `http://<host>:12345`, unauthenticated. `docker/README.md:3093`
records this as "N/A (no Caddy block)". Either add the route or drop the publish.

---

## C. Services currently broken or degraded

`docker/README.md` (~line 3143) already carries a "known broken" table. Consolidated
and re-verified here:

| Service | State | Cause | Sev |
|-|-|-|-|
| `matomo-app` / `matomo-cron` | `Created`, never started | Host port 8080 collision **[README]** | H |
| `paperless-ngx-webserver` | Crash loop | `PAPERLESS_SECRET_KEY` unset **[README]** | H |
| `docker-tailscale-1` | `Exited (1)` | Expired auth key **[README]** | M |
| `docker-live-auction-1` | `Exited (255)` | SQLite schema drift **[README]** | M |
| `archivebox` | Disabled on purpose | Memory pressure, 2026-08-21 **[README]** | — |
| `komodo` | Commented out on purpose | MongoDB 5+ needs AVX **[README]** | — |
| `beszel-agent` | Commented out on purpose | `BESZEL_TOKEN` still `changeMe` | M |

### C1 — Host port 8080 collision: drawio vs matomo (H) **[README]**

`docker/docker-compose.yml:508` publishes `8080:8080` for drawio;
`docker/matomo/docker-compose.yml:26` publishes `8080:80` for matomo. Both are pulled
in by `compose.all.yml`, so matomo can never bind:

```
Bind for 0.0.0.0:8080 failed: port is already allocated
```

`matomo-cron` is stuck only because it depends on `matomo-app`. `matomo-db` is
running normally and still holds the data.

Two details the README section is now stale on:
- It cites `docker-compose.yml:718` for drawio's port publish; the actual line is
  **507–508** after the service reorganisation.
- It says matomo has "no Caddy site block today" and the URL table at
  `docker/README.md:3092` says `N/A (no Caddy block)` — but `Caddyfile:186–188` now
  proxies `matomo.homelab` → `matomo-app:80`. The fix the README recommends (drop
  the host publish, reach it through Caddy) is therefore already half-done; only
  removing `8080:80` from `matomo/docker-compose.yml` remains.

### C2 — Paperless crash loop: secret key commented out (H) **[README]**

`docker/paperless-ngx/docker-compose.env:4` — `# PAPERLESS_SECRET_KEY=changeme` is
commented out, so the app exits on start.

Two further problems in the same file once it does start:
- `PAPERLESS_ADMIN_PASSWORD` is `changeme` (line 8).
- `PAPERLESS_AUTO_LOGIN_USERNAME=admin` (line 12) disables authentication entirely —
  anyone who reaches `paperless.homelab` is logged in as admin. The file's own
  comment says "only safe on trusted LAN"; combined with the wide-open Caddy
  frontend that is the whole LAN.

### C3 — Missing bind-mount source directories (M)

Docker silently creates a missing bind-mount source as an empty **root-owned**
directory rather than failing. Three sources referenced by compose do not exist in
the repo:

| Compose reference | Missing path | Consequence |
|-|-|-|
| `docker/docker-compose.yml:208` | `docker/jotty/config` | jotty runs as `1000:1000` (line 203) and cannot write to a root-owned config dir |
| `docker/docker-compose.yml:658` | `docker/live-auction/logs` | app logs land in a root-owned dir |
| `docker/glance/docker-compose.yml:14` | `docker/glance/assets` | glance's custom-assets mount is an empty root-owned dir |

Fix by committing a `.gitkeep` in each (the pattern already used for
`docker/paperless-ngx/consume/`, `docker/backrest/tmp/`, and
`docker/observability/grafana/provisioning/dashboards/infrastructure/`).

### C4 — `test-db` is on the default network and publishes 5432 to the LAN (M)

`docker/docker-compose.yml:629–641`. Unlike every other service in the file, `test-db`
declares no `networks:` block, so it lands on the implicit `default` network and
cannot be reached by name from anything on `main-network`. It also publishes
`5432:5432` on the host with credentials `testuser` / `testpassword` (lines 634–636),
which `docker/README.md:1495–1499` documents as the intended access path — so this
is a deliberately open Postgres on the LAN.

### C5 — Unused volume declaration (L)

`docker/docker-compose.yml:723` declares `pihole_etc:`, but pihole uses bind mounts
(`~/docker-volumes/pihole-config/etc-pihole` and `./pihole/etc-dnsmasq.d`, lines
88–89). The named volume is never referenced. Unlike `komodo-mongo-data`/`-config`
— which are deliberately retained to preserve data — this one holds nothing.

---

## D. Secrets & access control

> **Context:** this repo is public and commits real `.env` values on purpose. The
> items below are recorded so the exposure is explicit and reviewable, not as a
> recommendation to start gitignoring them. **D1 is the exception** and is called out
> separately because it is a live, billable third-party credential rather than a
> LAN-local password.

### D1 — `ANTHROPIC_API_KEY` committed to a public repo (H)

`docker/.env:24`. Unlike every other value in that file, this is not a homelab-local
password — it is a live credential against a paid third-party account, usable by
anyone on the internet who reads the repo, with cost and rate-limit consequences.
Git history means removing it from `HEAD` is not sufficient; the key needs rotating
at the provider.

Consumed by `docker/hermes-agent/docker-compose.yml:18`.

### D2 — Hardcoded credentials outside `.env` (M)

Values baked directly into committed compose files, bypassing `docker/.env`
entirely:

| File | Line | Value |
|-|-|-|
| `docker/docker-compose.yml` | 187 | `AUTH_PASSWORD: very_strong_password` (cronmaster) |
| `docker/docker-compose.yml` | 145 | `DATABASE_URL: postgresql://umami:umami@umami-db:5432/umami` |
| `docker/docker-compose.yml` | 166 | `POSTGRES_PASSWORD: umami` |
| `docker/docker-compose.yml` | 291 | `POSTGRES_PASSWORD: paperless` |
| `docker/docker-compose.yml` | 560 | `WEBUI_SECRET_KEY=t0p-s3cr3t` (ollama-webui) |
| `docker/docker-compose.yml` | 635 | `POSTGRES_PASSWORD: testpassword` (test-db) |
| `docker/observability/docker-compose.yml` | 108 | `GF_SECURITY_ADMIN_PASSWORD=admin123` |
| `docker/observability/grafana/grafana.ini` | 34 | `admin_password = admin123` |
| `docker/glance/docker-compose.yml` | 21 | `MY_SECRET_TOKEN=123456` |
| `docker/penpot/docker-compose.yml` | 53, 106 | `PENPOT_DATABASE_PASSWORD: penpot` |
| `docker/homepage/config/services.yaml` | 42 | Grafana widget `password: admin123` |
| `proxmox/terraform/lxc.tf` | 29, 68, 110, 154, 195, 237, 282, 329 | LXC root `password = "password123"` |
| `proxmox/ansible/inventory.yml` | 24 | `pihole_web_password: your_secure_password_here` |
| `proxmox/ansible/pihole/inventory/hosts.yml` | 8 | same |
| `proxmox/ansible/grafana/roles/linux_configure_grafana/defaults/main.yml` | 7 | `grafana_admin_password: admin@2023` |

### D3 — Services with authentication disabled (M)

- `docker/docker-compose.yml:557` — `WEBUI_AUTH=False` on ollama-webui, plus
  `ENV=dev` (line 556). Proxied at `ollama-webui.homelab` with no auth.
- `docker/docker-compose.yml:529–543` — `ollama` itself is proxied at
  `ollama.homelab` with no auth; the API allows model pull/delete.
- `docker/paperless-ngx/docker-compose.env:12` — `PAPERLESS_AUTO_LOGIN_USERNAME=admin`.
- `docker/observability/loki/loki.yml:1` — `auth_enabled: false`, and Loki is proxied
  at `loki.homelab`. Standard for single-tenant Loki, but combined with the open
  Caddy frontend it means anyone on the LAN can query all logs.
- `docker/planka/docker-compose.yml:52` — `POSTGRES_HOST_AUTH_METHOD=trust` on
  planka-postgres. Contained to the isolated `planka` network, so lower risk.

### D4 — Privileged containers with host access (M)

- `cronmaster` (`docker-compose.yml:177–199`) — `privileged: true`, `pid: "host"`,
  `user: "root"`, `/var/run/docker.sock` mounted, published on host `40123` with a
  hardcoded password. This is effectively root on the host, LAN-reachable.
- `netdata` (394–419), `cadvisor` (`observability/docker-compose.yml:19`) —
  `privileged`/`SYS_ADMIN` with broad host mounts. Expected for what they do.
- `docker.sock` is mounted into **seven** containers — dozzle
  (`docker-compose.yml:67`), cronmaster (`:190`), netdata (`:416`), flame (`:623`),
  homepage (`homepage/docker-compose.yml:16`), cadvisor
  (`observability/docker-compose.yml:28`) and alloy (`:79`). Only netdata mounts it
  `:ro`; the other six get **read-write** access, each a full root-equivalent escape
  path. dozzle, homepage and cadvisor only ever read, so `:ro` costs nothing there.
  Consider a socket proxy (e.g. `tecnativa/docker-socket-proxy`) for the read-only
  consumers.

### D5 — Committed session state and a JWT signing secret (M)

`docker/backrest/data/` is tracked in git and contains live runtime state:

```
docker/backrest/data/jwt-secret          <- signs Backrest session tokens
docker/backrest/data/oplog.sqlite        (+ -wal, -shm, .lock)
docker/backrest/data/general.sqlite
docker/backrest/data/tasklogs/logs.sqlite (+ -wal, -shm)
docker/backrest/data/processlogs/backrest.log
docker/backrest/config/config.json       <- repos, plans, admin user
docker/backrest/config/config.json.bak.2025-11-18-20-{37-59,53-51,54-22}
```

The `jwt-secret` file lets anyone forge a Backrest session. The `.sqlite-wal` /
`-shm` files are also actively-written SQLite sidecars — committing them produces a
dirty working tree on every run and can corrupt on checkout. Three dated `.bak`
copies of `config.json` are committed alongside.

Also tracked: `docker/live-auction/db/app.db` (a live SQLite database).

### D6 — Insecure SSH pattern committed in `.claude/settings.local.json` (L)

The allowlist includes `Bash(export SSHPASS=password)` and pre-approved
`sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
root@192.168.1.98 ...`. That is a root password, host-key verification disabled, and
a hardcoded host — committed. Note the file is currently **untracked**, so this is a
"don't commit it" item rather than an existing exposure.

---

## E. Backup & restore

### E1 — The backup loop only covers named volumes; bind mounts are skipped (H)

`docker/backup-remote-volumes.sh:34–41`:

```
for v in $(docker volume ls -q); do ... tar czf /backup/${v}.tar.gz . ; done
```

`docker volume ls -q` lists **named volumes only**. Every service that stores state
in a `~/docker-volumes/...` bind mount is silently excluded from every backup:

`tailscale` state · `pihole` config · `jellyfin` config+cache · `ollama` models and
webui data · `matomo` db **and** app · `tubearchivist` media/cache/redis/**elasticsearch**
· `hermes-agent` · `cta-map` · `backrest` data · `beszel` · `cronmaster` · `jotty` ·
`pinchflat` config+downloads · `flame` · `homepage` logs · **immich's Postgres**
(`immich/docker-compose.yml:53` — `${DB_DATA_LOCATION}`) and its library
(`${UPLOAD_LOCATION}`).

Immich's photo library and its database are the most serious omission. The script
prints a total size and "Done", so it reports success while covering perhaps half
the fleet.

The same loop also picks up anonymous volumes (hash-named), so the backup set is
simultaneously incomplete and noisy.

### E2 — Backup/restore scripts are out of date with `compose.all.yml` (H)

Both scripts predate the `compose.all.yml` reorganisation and stop/start an explicit
subset of stacks:

`backup-remote-volumes.sh:21–28` and `:49–53` — `docker-compose.yml`, immich,
tubearchivist, planka, forgejo.

`restore-docker-backup.sh:40–43` and `:69–72` — the same list **minus forgejo**.

Problems this creates:

1. **The restart is lossy.** `docker compose down` removes every container carrying
   the `docker` project label — i.e. the whole fleet, including matomo, penpot,
   linkwarden, navidrome, kafka, redis-pubsub, gatus, glance, homepage and the entire
   observability stack. The matching `up -d` then only brings back what is named in
   those few files. After a backup run, most of the fleet stays down.
2. **Restore corrupts what it doesn't stop.** `restore-docker-backup.sh` wipes and
   replaces volume contents (`rm -rf ..?* .[!.]* *` inside the volume, line 62) for
   *every* tarball found — including volumes belonging to containers it never
   stopped.
3. **Restore omits forgejo**, which backup explicitly stops for consistency because
   its SQLite DB and git repos share one volume (comment at
   `backup-remote-volumes.sh:26–28`). Restoring forgejo's volume under a running
   forgejo is exactly the case that comment warns about.

Both should drive off `compose.all.yml` (`docker compose -f docker/compose.all.yml
down` / `up -d`) instead of an enumerated list that has to be maintained by hand.

### E3 — Backup scripts point at a host that no longer matches the documented IP (M)

`backup-remote-volumes.sh:4` and `restore-docker-backup.sh:11` both set
`REMOTE_HOST="logan@10.0.0.33"`. `docker/README.md:53` documents that the network moved to
`192.168.1.x` and the Proxmox host was re-IP'd to `192.168.1.98`; the Docker VM is
`192.168.1.150` (`docker/gatus/docker-compose.yml:16`,
`docker/archivebox/backup-archivebox.sh:15`). `10.0.0.33` also matches no host in any
inventory. Verify before the next backup run — as written these scripts likely fail
to connect, which is the *good* outcome; the bad one is connecting to something else.

### E4 — No rotation or cleanup of backup archives (L)

`backup-remote-volumes.sh:59–62` writes `docker-backups-<timestamp>.tar.gz` into the
current working directory and never prunes. `$BACKUP_DIR` on the remote also
accumulates one `.tar.gz` per volume per run with no rotation.

---

## F. Addressing, DNS & networking drift

### F1 — Three different subnets across the repo (M)

| Value | Where |
|-|-|
| `10.0.0.32` | `docker/pihole/etc-dnsmasq.d/10-homelab.conf` — every `.homelab` A record |
| `10.0.0.33` | `docker/backup-remote-volumes.sh:4`, `docker/restore-docker-backup.sh:11` |
| `10.0.0.98` | `proxmox/terraform/providers.tf:16`, `docker/README.md:24` |
| `10.0.0.47`–`10.0.0.54` | all `proxmox/ansible/*/inventory/*` hosts, and the service-URL list at `README.md:43–53` |
| `192.168.1.98` | Proxmox host, per `docker/README.md:53` and `.claude/settings.local.json` |
| `192.168.1.100` | `proxmox/terraform/variables.tf:3` (`proxmox_api_url` default) |
| `192.168.1.150` | Docker VM, per `docker/gatus/docker-compose.yml:16` |

`docker/README.md:53` and `:232` document the `10.0.0.x` → `192.168.1.x` move and
`docker/README.md:289` covers moving back, so the drift is known — but the migration
was never propagated to the backup scripts (E3), the Terraform provider (H1), or the
Ansible inventories (H4).

> The `10.0.0.32` records in `10-homelab.conf` are a **deliberate placeholder** —
> the live records are managed in Pi-hole itself. Left as-is on purpose; noted here
> only so the file is not mistaken for the source of truth.

### F2 — Caddy routes to containers that don't exist (L)

`Caddyfile:112–114` → `komodo-core:9120` and `Caddyfile:193–195` → `archivebox:8000`.
Both stacks are disabled, so both return 502. Corresponding Pi-hole records
(`10-homelab.conf:29`, `:54`) also still resolve. Harmless, but they are what makes
the dead Gatus monitors (A4) look like outages rather than "not deployed".

### F3 — `redis` and `kafka` publish to the LAN (L)

`docker-compose.yml:233` publishes `6379:6379` (password-protected via
`${REDIS_PASSWORD}`); `kafka/docker-compose.yml:29–30` publishes `9092`/`29092`
(PLAINTEXT, no auth). Both are LAN-wide. Kafka's `KAFKA_ADVERTISED_LISTENERS`
includes `PLAINTEXT_HOST://localhost:9092` (line 42), so the published port only
works from the host itself — a remote LAN client that connects will be handed back
`localhost:9092` and fail. Either intentional (host-only testing) or an unfinished
setup; worth deciding which.

### F4 — The root `README.md` service list points at the retired LXC estate (M)

`README.md:43–53` lists the way in to each service:

```
http://10.0.0.47:3000 - Grafana
http://10.0.0.48:3000 - homepage
http://10.0.0.49      - Pihole
http://10.0.0.50:3001 - Uptime Kuma
http://10.0.0.51:5678/setup - N8N
http://10.0.0.52      - kafka
http://10.0.0.53:8096/web - Jellyfin
10.0.0.54             - Tailscale
```

Every one of those is an LXC address on the retired `10.0.0.x` subnet (H4). All seven
services now run as Docker containers reached at `*.homelab` through Caddy. The root
README is the first thing a reader opens, and its front-page service list is entirely
stale — while the accurate one lives 3,000 lines into `docker/README.md`.


---

## G. Repo hygiene & committed state

### G1 — Runtime state committed to git (M)

See D5 for the security angle. Purely as hygiene, these should not be tracked:

- `docker/backrest/data/**` — SQLite DBs, WAL/SHM sidecars, a lock file, logs
- `docker/backrest/config/config.json.bak.*` — three dated backups
- `docker/live-auction/db/app.db`
- `proxmox/ansible/pihole/inventory/hosts.ini.bak`
- `docker/uptime-kuma/backup_files/*.json`,
  `proxmox/backup_files/Uptime_Kuma_Backup_2025_07_16-09_20_36.json` — two
  Uptime-Kuma export snapshots in two different locations

### G2 — `.gitignore` doesn't match practice (L)

Root `.gitignore` is the stock Terraform template plus `.DS_Store`.
`docker/.gitignore` ignores only `.DS_Store` and `live-auction/.env` — while every
other `.env` in the tree (`docker/.env`, `karakeep/`, `linkwarden/`, `planka/`,
`penpot/`, `navidrome/`) *is* committed. That is the deliberate policy for this repo,
but the single `live-auction/.env` exception is unexplained and reads as an
oversight either way. Worth a one-line comment stating the policy so the exception is
obviously intentional.

`.DS_Store` files still exist in the tree (`./.DS_Store`,
`docker/observability/grafana/provisioning/.DS_Store`) — check whether they were
committed before the ignore rule was added.

### G3 — Stray unrelated file at repo root (L)

`live_auction.md` is a raw AI-chat transcript ("Here's a battle-plan for using
Ansible to get your React + Flask 'live-auction' app up and running…"), sitting at
the top level next to `README.md`. It is untracked. Either move it under
`docker/live-auction/` as a note, or delete it.

### G4 — 30 local branches, 28 remote (L)

`git branch -a` shows 30 local and 28 remote branches, many of which look merged
(`organize-services`, `add-consumer-to-kafka-setup`, `linkwarden`, `planka`,
`penpot`, `navidrome`, `matomo`, `archive-box`, …). The three most recent commits on
this branch are all titled `wip`.

### G5 — `docker/README.md` is 3,308 lines (L)

It is genuinely good documentation — deep, honest, full of hard-won "why" comments —
but at 3,300 lines in one file it is hard to navigate and hard to keep true. The
staleness in C1 (a line reference and a "no Caddy block" claim that are both now
wrong) is the predictable result. Consider splitting per-service sections into
`docker/docs/<service>.md` with the root README as an index.

---

## H. Terraform & Ansible layer

This layer provisions LXCs on Proxmox for Grafana, Homepage, Uptime-Kuma, Kafka,
n8n, Jellyfin and Pi-hole — **all seven of which also run as Docker containers** in
`docker/compose.all.yml`. Two parallel, diverging provisioning stacks for the same
services. Nothing indicates which is current; the Ansible inventories still use the
old `10.0.0.x` addressing (F1), suggesting it is the dormant one. Worth an explicit
note at the top of `proxmox/README` (or deletion) so the intent is unambiguous.

### H1 — Terraform provider URL is hardcoded and contradicts its own variables (M)

`proxmox/terraform/providers.tf:16` hardcodes
`pm_api_url = "https://10.0.0.98:8006/api2/json"` with the variable-driven form
commented out on line 15. Meanwhile:

- `variables.tf:1–4` declares `proxmox_api_url` (default `https://192.168.1.100:8006`)
  — **never referenced**.
- `variables.tf:31–34` declares `proxmox_host` — referenced only by the commented-out
  line 15, so also dead.
- `terraform.tfvars.example:5` supplies `10.0.0.98`.

Three different addresses, none of them the current `192.168.1.98`.

### H2 — `pm_tls_insecure = true` (L)

`providers.tf:19`. Expected for a self-signed Proxmox cert, but it disables
verification outright rather than pinning the CA.

### H3 — Hardcoded absolute Mac paths and root passwords in `lxc.tf` (M)

Every LXC resource sets `password = "password123"` and
`ssh_public_keys = file("/Users/logan/.ssh/id_rsa_terraform.pub")` — lines 29/30,
68/69, 110/111, 154/155, 195/196, 237/238, 282/283, 329/330. The absolute path makes
the config non-portable, and `variables.tf:39–42` already declares
`ssh_private_key_path` (unused) for exactly this.

`lxc.tf:100` also hardcodes `~/.ssh/id_rsa_terraform` in a `remote-exec` connection
block.

### H4 — Ansible inventories are on the retired subnet (M)

Every host in `proxmox/ansible/inventory.yml` and the per-role `inventory/hosts`
files is `10.0.0.47`–`10.0.0.54`. All also set
`ansible_ssh_common_args: -o StrictHostKeyChecking=no`, and
`proxmox/ansible/pihole/ansible.cfg:2` sets `host_key_checking = False`.

### H5 — ChatGPT citation artifact left in committed config (L)

`providers.tf:19` ends with
`[oai_citation:0‡Terraform Registry](https://registry.terraform.io/...?utm_source=chatgpt.com)`
— a pasted-in citation marker in a `.tf` file.

---

## I. Placeholders never filled in

Config that was copied from upstream examples and never customised:

| File | Line | Placeholder |
|-|-|-|
| `docker/homepage/config/services.yaml` | 5–18 | The three stock demo entries ("My First Group" / "Homepage is awesome") still ship above the real config |
| `docker/homepage/config/services.yaml` | 30 | Pi-hole widget `key: changeme` — widget renders an error |
| `docker/homepage/config/services.yaml` | 106 | Jellyfin widget `key: REPLACE_WITH_JELLYFIN_API_KEY` |
| `docker/glance/config/home.yml` | all | Entirely stock: Twitch channels (theprimeagen, j_blow…), LTT/Fireship/MKBHD YouTube feeds, `weather: London, United Kingdom` |
| `docker/glance/docker-compose.yml` | 21 | `MY_SECRET_TOKEN=123456` |
| `docker/docker-compose.yml` | 591 | Jellyfin `JELLYFIN_PublishedServerUrl=http://example.com` |
| `docker/docker-compose.yml` | 558 | `WEBUI_NAME=valiantlynx AI` — from the upstream example author |
| `docker/.env` | 34 | `BESZEL_TOKEN` still `changeMe`, which is why beszel-agent is disabled |
| `docker/paperless-ngx/docker-compose.env` | 4, 8 | `SECRET_KEY` commented out; admin password `changeme` |
| `proxmox/ansible/inventory.yml` | 24 | `pihole_web_password: your_secure_password_here` |
| `docker/penpot/docker-compose.yml` | 59–60 | `no-reply@example.com` |

Also: `docker/penpot/docker-compose.yml:26,45` keep
`disable-secure-session-cookies` and `disable-email-verification` in `PENPOT_FLAGS`,
which the file's own header warns must be removed before any internet exposure.
`PENPOT_TELEMETRY_ENABLED: "true"` (line 57) is also on, unlike the analytics-off
posture taken everywhere else in the stack.

---

## What's already right

Worth stating, because the audit above is one-sided:

- **Alloy instead of Promtail.** Promtail is EOL; this is the correct choice.
- **Loki on TSDB / schema v13**, with the compactor *and* `retention_enabled: true`
  actually set — the default leaves logs forever, and that default was not accepted.
- **Everything provisioned as code.** Datasources, dashboards and rules are all
  files, not clicked-in state.
- **Analytics reporting off** in both Loki (`loki.yml:49–50`) and Grafana
  (`grafana.ini:47–49`, including `check_for_updates = false`).
- **No Angular panels in any dashboard JSON**, so a Grafana major upgrade will not
  break the dashboards.
- **Version pinning is now near-universal** across the observability stack (see
  below) and on several app images (`uptime-kuma:2.0.2`, `apache/kafka:4.0.0`,
  `forgejo:16`, `meilisearch:v1.13.3`, `elasticsearch:8.18.2`, plus SHA-pinned
  Immich images).
- **The commenting is exceptional.** Disabled stacks carry dated explanations with
  root cause and a re-enable procedure (archivebox, komodo, beszel-agent); non-obvious
  choices are justified inline (why navidrome needs a named volume and not a bind
  mount; why `name: docker` is pinned in the Kafka file; why redis moved off
  kafka-network; why linkwarden's `DATABASE_URL` is written out literally). This is
  the single best quality signal in the repo.
- **Health checks and `depends_on: service_healthy`** are used properly on the
  Postgres/MariaDB-backed stacks rather than bare `depends_on`.

---

## Resolved since the last audit

The previous review flagged these; they are fixed on this branch and are recorded
here only so the delta is clear:

| Previously flagged | Status now |
|-|-|
| Grafana 10.2 → needs upgrade | `grafana/grafana:13.2.0` |
| Prometheus 2.47 → needs upgrade | `prom/prometheus:v3.14.0` |
| `prometheusVersion: 2.47.0` in datasource must track the upgrade | `prometheusVersion: 3.14.0` — matches |
| `grafana/alloy:latest` unpinned | `grafana/alloy:v1.18.1` |
| Loki / cAdvisor need bumping | `grafana/loki:3.6.0`, `cadvisor:v0.60.5` |
| Overlapping dashboard providers — default provider's path recursively contained `observability/`, provisioning that dashboard twice | Fixed: the `default` provider now points at `.../dashboards/general`, so the three providers cover disjoint subdirectories |

Everything else from that review is still open and is carried forward above.

---

## Suggested order of work

1. **Rotate `ANTHROPIC_API_KEY`** (D1). It is a live third-party credential in a
   public repo; nothing else here has an external blast radius.
2. **Fix the backup scripts** (E1, E2, E3). Right now they report success while
   omitting Immich's database and photo library, and the restore path can corrupt
   volumes under running containers. This is the only issue in the list where the
   consequence is unrecoverable data loss.
3. **Add alertmanager + node-exporter** (A1, A2). Two small service blocks that close
   the two real blind spots and make nine existing rules and one existing dashboard
   panel start working. Point Loki's `ruler.alertmanager_url` at
   `http://alertmanager:9093` at the same time, and give Gatus an `alerting:` block
   (A5) while you are in a notifications frame of mind.
4. **Drop `--web.enable-admin-api`** (B2) and **move the Grafana password to `.env`**
   (B1) — removing the `[security]` block from `grafana.ini` so the env var actually
   takes effect.
5. **Unblock the two crash-looped services**: uncomment `PAPERLESS_SECRET_KEY` (C2)
   and take matomo off host port 8080 now that its Caddy route exists (C1).
6. **Fix `HighContainerCPU`** with `sum by (name)` (B4) and add
   `--storage.tsdb.retention.size` plus `external_labels` (B5).
7. **Pick one metrics path for Alloy** (B3) — for a single host, letting Prometheus
   scrape cAdvisor directly and reducing Alloy to logs-only is simplest.
8. **Clean up the dead references**: jaeger/tempo (A3), Caddy routes and Gatus
   monitors for komodo and archivebox (A4, F2), the unused `pihole_etc` volume (C5).
9. **Add the three missing `.gitkeep` directories** (C3) and untrack the committed
   runtime state (D5, G1).
10. **Decide the fate of `proxmox/`** (H). Either update the addressing and declare it
    current, or mark it archived — leaving two divergent provisioning stacks for the
    same seven services is the largest source of "which of these is true?" in the
    repo.
