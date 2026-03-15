# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker Compose setup for running a Sonic Robo Blast 2 (SRB2) dedicated game server. The Dockerfile compiles SRB2 from source inside the container and the entrypoint script (`srb2.sh`) launches the dedicated server with optional addon support.

## Key Files

- `Dockerfile` — Multi-stage build: compiles SRB2 from source, fetches game data, produces a minimal runtime image
- `docker-compose.yml` — Defines the `srb2` service with port mapping (`5029/udp`) and volume mounts
- `srb2.sh` — Container entrypoint that runs `lsdl2srb2 -dedicated` and optionally loads addons via `-file`
- `README.md` — Usage instructions
- `.dockerignore` — Excludes non-essential files from the Docker build context
- `.github/workflows/build.yml` — CI workflow that auto-builds and pushes to GHCR on push to main

## Commands

### Docker Compose
```bash
docker compose up -d
docker compose up -d --build              # Build from source
SRB2_VERSION=Release2.2.15 docker compose up -d --build
docker compose logs -f srb2               # View server output
docker compose restart                    # Restart after addon changes
docker compose pull && docker compose up -d  # Update to latest image
```

### Docker build + run (without Compose)
```bash
docker build -t srb2-docker .
docker build --build-arg SRB2_VERSION=Release2.2.15 -t srb2-docker .
docker run -d \
  -p 5029:5029/udp \
  -v ./addons:/addons \
  -v ./data:/data \
  srb2-docker
```

### Server console
```bash
docker compose logs -f srb2     # View server output
docker attach srb2              # Attach to server console (Ctrl+P, Ctrl+Q to detach)
```

## Architecture

The project is intentionally minimal — no build system beyond Docker.

**Build flow:** Three-stage Dockerfile:
1. **build** stage — clones SRB2 source from `git.do.srb2.org/STJr/SRB2` and compiles it with `make`. Shallow clone (`--depth 1`) for speed. `SRB2_VERSION` build arg (default `auto`, which resolves to the latest GitHub release tag) pins the source revision.
2. **gamedata** stage — fetches game data files (`.dat`, `.pk3`, `.dta`) from GitHub releases. `SRB2_VERSION` controls which release to download from. Downloads and extracts only the needed file types from the `Full.zip` asset.
3. **Runtime** stage — copies the `lsdl2srb2` binary from the build stage and game data from the gamedata stage into a clean `ubuntu:24.04` image with only the required runtime libraries.

**Runtime flow:** `srb2.sh` is the entrypoint. It checks if `/addons` has files (using nullglob), filters to recognized types (`.wad`, `.pk3`, `.soc`, `.lua`, `.kart`, `.cfg`), then launches `lsdl2srb2 -dedicated -config adedserv.cfg -home /data`, appending `-file` with the addon paths when present. Extra arguments passed to the container (`docker run ... srb2-docker -maxplayers 16` or via Compose `command:`) are forwarded to `lsdl2srb2` before the `-file` addon args. The script also handles SIGTERM/SIGINT forwarding for graceful shutdown.

**Volumes:**
- `/addons` — Optional mods/addons directory (`.wad`, `.pk3` files loaded automatically via `-file`)
- `/data` — Home directory for the SRB2 dedicated server process; the config file lives at `/data/.srb2/adedserv.cfg`

## Build Mode

The `docker-compose.yml` defaults to pulling a pre-built image from GHCR (`SRB2_IMAGE`). To build from source instead, clear the image variable and uncomment the `build:` block:
```bash
SRB2_IMAGE="" docker compose up -d --build
```

## Version Selection

The `SRB2_VERSION` build arg controls both the source revision and game data download:
- `auto` (default) — resolves the latest release tag and game data URL from GitHub
- A specific tag (e.g., `Release2.2.15`) — pins both source and game data to that release

## Game Data

The Dockerfile does not require game data files in the repository. The `gamedata` build stage automatically fetches the correct `Full.zip` from GitHub releases based on `SRB2_VERSION`, and extracts the required files (`models.dat`, `patch.pk3`, `patch_music.pk3`, `player.dta`, `srb2.pk3`, `zones.pk3`).

## CI

The `.github/workflows/build.yml` workflow triggers on push to `main`, pull requests to `main`, and manual dispatch. It fetches the latest SRB2 release tag, builds the Docker image with `SRB2_VERSION` set, and pushes to GHCR (`ghcr.io/<owner>/srb2-docker`). Images are tagged with `latest`, the SRB2 version, and the commit SHA. Builds use GitHub Actions cache (`type=gha`) for Docker layer caching. PR builds validate the image but do not push. On push, a Trivy vulnerability scan runs and uploads SARIF results.
