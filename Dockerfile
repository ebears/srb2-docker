ARG UBUNTU_VERSION=24.04

FROM ubuntu:${UBUNTU_VERSION}@sha256:98ff7968124952e719a8a69bb3cccdd217f5fe758108ac4f21ad22e1df44d237 AS build

ARG DEBIAN_FRONTEND=noninteractive
ARG SRB2_VERSION=auto

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpng-dev zlib1g-dev libsdl2-dev \
    libsdl2-mixer-dev libgme-dev libopenmpt-dev libminiupnpc-dev \
    libcurl4-openssl-dev nasm git curl pkg-config ca-certificates jq \
    && rm -rf /var/lib/apt/lists/*

RUN if [ "$SRB2_VERSION" = "auto" ]; then \
      SRB2_VERSION=$(curl -fsSL https://api.github.com/repos/STJr/SRB2/releases/latest \
        | jq -r '.tag_name' || echo "master"); \
    fi && \
    echo "Cloning SRB2 ref: $SRB2_VERSION" && \
    git clone --depth 1 --branch "$SRB2_VERSION" https://git.do.srb2.org/STJr/SRB2.git
WORKDIR /SRB2
RUN make -j$(nproc)

FROM alpine:3.23@sha256:59855d3dceb3ae53991193bd03301e082b2a7faa56a514b03527ae0ec2ce3a95 AS gamedata
ARG SRB2_VERSION=auto
RUN apk add --no-cache wget unzip jq curl
RUN mkdir -p /gamedata && \
    if [ "$SRB2_VERSION" = "auto" ]; then \
      GAMEDATA_URL=$(curl -fsSL https://api.github.com/repos/STJr/SRB2/releases/latest \
        | jq -r '.assets[] | select(.name | test("Full\\.zip$")) | .browser_download_url'); \
    else \
      GAMEDATA_URL=$(curl -fsSL "https://api.github.com/repos/STJr/SRB2/releases/tags/${SRB2_VERSION}" \
        | jq -r '.assets[] | select(.name | test("Full\\.zip$")) | .browser_download_url'); \
    fi && \
    if [ -z "$GAMEDATA_URL" ]; then \
      echo "ERROR: Could not find Full.zip for SRB2_VERSION=${SRB2_VERSION}" >&2; \
      exit 1; \
    fi && \
    cd /tmp && \
    wget -q "$GAMEDATA_URL" -O gamedata.zip && \
    unzip -jo gamedata.zip "*.dat" "*.pk3" -d /gamedata/ && \
    unzip -jo gamedata.zip "*.dta" -d /gamedata/ 2>/dev/null || true && \
    rm gamedata.zip

FROM ubuntu:${UBUNTU_VERSION}@sha256:98ff7968124952e719a8a69bb3cccdd217f5fe758108ac4f21ad22e1df44d237

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libsdl2-2.0-0 libsdl2-mixer-2.0-0 libgme0 libopenmpt0 libpng16-16 \
    libminiupnpc17 libcurl4 ca-certificates \
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
COPY --from=gamedata /gamedata /SRB2/bin/

RUN chown -R srb2:srb2 /SRB2/bin

VOLUME /addons
VOLUME /data

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD pgrep -x lsdl2srb2 || exit 1

EXPOSE 5029/udp

COPY --chmod=755 srb2.sh /usr/bin/srb2.sh

WORKDIR /SRB2

USER srb2

ENTRYPOINT ["srb2.sh"]
