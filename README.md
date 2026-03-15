# srb2-docker

Run a [Sonic Robo Blast 2](https://srb2.org/) dedicated server in Docker. Drop in mods, restart, done.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) 20.10+
- [Docker Compose](https://docs.docker.com/compose/install/) v2 (the `docker compose` command, not `docker-compose`)

## Quick Start

```bash
docker compose up -d
```

Or with plain Docker:

```bash
docker run -d \
  --name srb2 \
  -p 5029:5029/udp \
  -v ./mods:/mods \
  -v ./data:/data \
  ghcr.io/ebears/srb2-docker:latest
```

A default server config is copied to `data/.srb2/adedserv.cfg` on first run. Edit it to customize your server. See the [SRB2 Wiki -- Server Options](https://wiki.srb2.org/wiki/Console/Variables#Server_options) for available variables.


## Mods

Place `.wad`, `.pk3`, `.soc`, `.lua`, or `.cfg` files in the `mods/` directory. They load automatically on startup.

To add or remove mods, copy the files in and restart:

```bash
cp my-mod.pk3 mods/
docker compose restart
```

## Custom Server Arguments

Extra arguments are forwarded to the SRB2 process. In Compose:

```yaml
services:
  srb2:
    image: ghcr.io/ebears/srb2-docker:latest
    command: ["-maxplayers", "16"]
```

With `docker run`, append them after the image name:

```bash
docker run -d -p 5029:5029/udp ... ghcr.io/ebears/srb2-docker:latest -maxplayers 16
```

## Version Tags

Images are tagged with the SRB2 game version they were built against. To pin to a specific version:

```yaml
image: ghcr.io/ebears/srb2-docker:Release2.2.15
```

The `latest` tag always tracks the most recent SRB2 release.

## Building from Source

To build the image yourself instead of pulling from GHCR:

```bash
docker build -t srb2-docker .

# Or pin to a specific SRB2 version:
docker build --build-arg SRB2_VERSION=Release2.2.15 -t srb2-docker .
```

Then in `docker-compose.yml`, set `SRB2_IMAGE` to empty and uncomment the `build:` block:

```bash
SRB2_IMAGE="" docker compose up -d --build
```

## Volumes

| Volume | Purpose |
|--------|---------|
| `/mods` | Optional mods (`.wad`, `.pk3`, etc.) loaded automatically via `-file` |
| `/data` | Home directory for server data and config file (`data/.srb2/adedserv.cfg`) |

## Resource Limits

The default Compose file sets a 512 MB memory limit, 2 CPU cores, `restart: unless-stopped`, and a healthcheck that verifies the `lsdl2srb2` process is running (every 30s, 3 retries). Adjust `mem_limit` and `cpus` in `docker-compose.yml` based on your player count and mods.

## Server Console

To send commands to the running server:

```bash
# View server output
docker compose logs -f srb2

# Attach to the server console (Ctrl+P, Ctrl+Q to detach without stopping)
docker attach srb2
```

> **Note:** Using `Ctrl+C` while attached will stop the server. Use the detach sequence above instead.

## Updating

```bash
docker compose pull
docker compose up -d
```

This pulls the latest image and recreates the container. Your `data/` and `mods/` volumes are preserved.

## Networking

SRB2 uses **UDP port 5029**. If running behind a NAT/firewall, forward this port to your host machine. Players connect via your public IP or hostname.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Container exits immediately | Check logs: `docker compose logs srb2`. Usually a missing game data file or port conflict. |
| Port already in use | Another process is using UDP 5029. Stop it or change the host port mapping (e.g., `"5030:5029/udp"`). |
| Mods not loading | Ensure files are in `mods/` with supported extensions (`.wad`, `.pk3`, `.soc`, `.lua`, `.cfg`). Check logs for error messages. |
| `docker compose` command not found | Install Docker Compose v2, or use `docker-compose` (with hyphen) for v1. |
| Server not visible to other players | Verify port forwarding on your router and that your firewall allows UDP 5029. |
| Build fails during game data download | The GitHub API rate limit may have been reached. Wait an hour or use a GitHub token. |

## CI/CD

Pushes to `main` build the image and publish it to [GHCR](https://ghcr.io). Pull requests to `main` also trigger builds to validate the image (but do not push). Images are tagged with `latest`, the SRB2 version, and the commit SHA. Trivy vulnerability scanning runs on each push.
