<p align="center">
  <img src="assets/logo.gif" alt="srb2-docker" width="480">
</p>

<p align="center">
  Run a <a href="https://srb2.org/">Sonic Robo Blast 2</a> dedicated server in Docker. Drop in mods, restart, done.
</p>

<p align="center">
  <a href="https://github.com/ebears/srb2-docker/pkgs/container/srb2-docker"><img src="https://img.shields.io/badge/image-ghcr.io%2Febears%2Fsrb2--docker-blue?logo=docker&logoColor=white" alt="Docker Image"></a>
  <a href="https://github.com/ebears/srb2-docker/actions"><img src="https://img.shields.io/github/actions/workflow/status/ebears/srb2-docker/build.yml?branch=main&label=build" alt="CI"></a>
</p>

---

## Quick Start

```bash
docker compose up -d
```

A default server config is copied to `data/.srb2/adedserv.cfg` on first run. Edit it to customize your server -- see the [SRB2 Wiki: Server Options](https://wiki.srb2.org/wiki/Console/Variables#Server_options) for available variables.

<p align="center">
  <img src="assets/reading.gif" alt="Sonic reading" width="320">
</p>
<details>
<summary>Using plain Docker (without Compose)</summary>

```bash
docker run -d \
  --name srb2 \
  -p 5029:5029/udp \
  -v ./mods:/mods \
  -v ./data:/data \
  ghcr.io/ebears/srb2-docker:latest
```

</details>

---

## Mods

Place `.wad`, `.pk3`, `.soc`, `.lua`, or `.cfg` files in the `mods/` directory. They load automatically on startup.

```bash
cp my-mod.pk3 mods/
docker compose restart
```

## Custom Arguments

Pass extra arguments via Compose:

```yaml
services:
  srb2:
    image: ghcr.io/ebears/srb2-docker:latest
    command: ["-maxplayers", "16"]
```

Or with `docker run`:

```bash
docker run -d -p 5029:5029/udp ... ghcr.io/ebears/srb2-docker:latest -maxplayers 16
```

## Version Pinning

Images are tagged with the SRB2 version. Pin to a release:

```yaml
image: ghcr.io/ebears/srb2-docker:Release2.2.15
```

The `latest` tag tracks the most recent SRB2 release.

## Building from Source

```bash
docker build -t srb2-docker .
docker build --build-arg SRB2_VERSION=Release2.2.15 -t srb2-docker .
```

Then set `SRB2_IMAGE=""` and uncomment the `build:` block in `docker-compose.yml`:

```bash
SRB2_IMAGE="" docker compose up -d --build
```

---

## Volumes

| Mount | Purpose |
|-------|---------|
| `/mods` | Mods (`.wad`, `.pk3`, etc.) loaded automatically via `-file` |
| `/data` | Server home directory; config at `data/.srb2/adedserv.cfg` |

## Resource Limits

The default Compose file sets a **1 GB memory limit** and **2 CPU cores**, with `restart: unless-stopped`. The Dockerfile includes a healthcheck that verifies the `lsdl2srb2` process is running (every 30s, 3 retries). Adjust `memory` and `cpus` in `docker-compose.yml` based on your player count and mods.

## Server Console

```bash
# Stream server output
docker compose logs -f srb2

# Attach to the server console
docker attach srb2          # Ctrl+P, Ctrl+Q to detach
```

> **Warning:** `Ctrl+C` while attached will stop the server. Use the detach sequence instead.

## Updating

```bash
docker compose pull
docker compose up -d
```

Your `data/` and `mods/` volumes are preserved across updates.

## Networking

SRB2 uses **UDP port 5029**. Forward this port through your NAT/firewall so players can connect via your public IP or hostname.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Container exits immediately | `docker compose logs srb2` -- usually a missing game data file or port conflict |
| Port already in use | Another process is using UDP 5029. Stop it or remap the host port (`"5030:5029/udp"`) |
| Mods not loading | Check file extensions (`.wad`, `.pk3`, `.soc`, `.lua`, `.cfg`) and logs for errors |
| `docker compose` not found | Install [Docker Compose v2](https://docs.docker.com/compose/install/), or use `docker-compose` (v1) |
| Server not visible | Verify port forwarding on your router and firewall rules for UDP 5029 |
| Build fails on game data | GitHub API rate limit reached. Wait or use a GitHub token |

## CI/CD

Pushes to `main` build and publish images to [GHCR](https://ghcr.io). Pull requests trigger validation builds (no push). Images are tagged with `latest`, the SRB2 version, and the commit SHA. [Trivy](https://github.com/aquasecurity/trivy) vulnerability scanning runs on each push.
