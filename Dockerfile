ARG UBUNTU_VERSION=24.04

# Resolve SRB2_VERSION=auto to actual tag once, shared by build and gamedata stages
FROM alpine:3.23@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659 AS version
ARG SRB2_VERSION=auto
RUN apk add --no-cache curl jq
RUN if [ "$SRB2_VERSION" = "auto" ]; then \
      curl -fsSL https://api.github.com/repos/STJr/SRB2/releases/latest \
        | jq -r '.tag_name' > /resolved_version; \
    else \
      echo "$SRB2_VERSION" > /resolved_version; \
    fi

FROM ubuntu:${UBUNTU_VERSION}@sha256:98ff7968124952e719a8a69bb3cccdd217f5fe758108ac4f21ad22e1df44d237 AS build

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpng-dev zlib1g-dev libsdl2-dev \
    libsdl2-mixer-dev libgme-dev libopenmpt-dev libminiupnpc-dev \
    libcurl4-openssl-dev nasm git curl pkg-config ca-certificates jq \
    && rm -rf /var/lib/apt/lists/*

COPY --from=version /resolved_version /resolved_version
RUN SRB2_VERSION=$(cat /resolved_version) && \
    echo "Cloning SRB2 ref: $SRB2_VERSION" && \
    git clone --depth 1 --branch "$SRB2_VERSION" https://git.do.srb2.org/STJr/SRB2.git
WORKDIR /SRB2
RUN make -j$(nproc)

FROM alpine:3.23@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659 AS gamedata
RUN apk add --no-cache wget unzip jq curl
COPY --from=version /resolved_version /resolved_version
RUN SRB2_VERSION=$(cat /resolved_version) && \
    GAMEDATA_URL=$(curl -fsSL "https://api.github.com/repos/STJr/SRB2/releases/tags/${SRB2_VERSION}" \
      | jq -r '.assets[] | select(.name | test("Full\\.zip$")) | .browser_download_url') && \
    if [ -z "$GAMEDATA_URL" ]; then \
      echo "ERROR: Could not find Full.zip for SRB2_VERSION=${SRB2_VERSION}" >&2; \
      exit 1; \
    fi && \
    cd /tmp && \
    wget -q "$GAMEDATA_URL" -O gamedata.zip && \
    unzip -jo gamedata.zip "*.dat" "*.pk3" -d /gamedata/ && \
    rm gamedata.zip && \
    echo "Extracted files:" && ls -la /gamedata/

FROM ubuntu:${UBUNTU_VERSION}@sha256:98ff7968124952e719a8a69bb3cccdd217f5fe758108ac4f21ad22e1df44d237

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libsdl2-2.0-0 libsdl2-mixer-2.0-0 libgme0 libopenmpt0 libpng16-16 \
    libminiupnpc17 libcurl4 ca-certificates gosu \
    && rm -rf /var/lib/apt/lists/*

RUN set -e; \
    if ! getent group srb2 >/dev/null; then \
      existing=$(getent group 1000 | cut -d: -f1 || true); \
      if [ -n "$existing" ]; then groupmod -n srb2 "$existing"; \
      else groupadd -g 1000 srb2; fi; \
    fi; \
    if ! getent passwd srb2 >/dev/null; then \
      existing=$(getent passwd 1000 | cut -d: -f1 || true); \
      if [ -n "$existing" ]; then usermod -l srb2 -g srb2 -m -d /home/srb2 "$existing"; \
      else useradd -u 1000 -g srb2 -m srb2; fi; \
    fi

COPY --from=build /SRB2/bin/lsdl2srb2 /SRB2/bin/lsdl2srb2
COPY --from=gamedata /gamedata /SRB2/
COPY adedserv.cfg /defaults/adedserv.cfg

RUN chown -R srb2:srb2 /SRB2

VOLUME /mods
VOLUME /data

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD pgrep -x lsdl2srb2 || exit 1

EXPOSE 5029/udp

COPY --chmod=755 srb2.sh /usr/bin/srb2.sh

WORKDIR /SRB2

ENTRYPOINT ["/usr/bin/srb2.sh"]
