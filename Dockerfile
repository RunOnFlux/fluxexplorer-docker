FROM ubuntu:24.04

ARG NODE_VERSION=24.22.1
ARG NODE_SHA256=6c172a9ab6718f7b801fb5a7bd486af2ee5e32758086a04b84fcce2aa77095e6
ARG NPM_VERSION=12.2.1
ARG FLUX_VERSION=9.1.0
ARG FLUX_APT_FINGERPRINT=4F7FEBBF1BDDD2397DABE2CF4B69CA27A986265D

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg jq libgomp1 xz-utils \
    && rm -rf /var/lib/apt/lists/*

# fluxd and flux-cli from Flux's apt repository, at a pinned version, signed by the key with this
# fingerprint
RUN export GNUPGHOME="$(mktemp -d)" \
    && curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${FLUX_APT_FINGERPRINT}" \
        | gpg --dearmor > /usr/share/keyrings/flux-archive-keyring.gpg \
    && gpg --show-keys --with-colons /usr/share/keyrings/flux-archive-keyring.gpg \
        | grep -qx "fpr:::::::::${FLUX_APT_FINGERPRINT}:" \
    && rm -rf "$GNUPGHOME" \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/flux-archive-keyring.gpg] https://apt.runonflux.io/ noble main" \
        > /etc/apt/sources.list.d/flux.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends "flux=${FLUX_VERSION}" \
    && rm -rf /var/lib/apt/lists/*

ENV PATH=/opt/node/bin:$PATH
RUN curl -fsSL -o /tmp/node.tar.xz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
    && echo "${NODE_SHA256}  /tmp/node.tar.xz" | sha256sum -c - \
    && mkdir -p /opt/node \
    && tar -xJf /tmp/node.tar.xz -C /opt/node --strip-components=1 \
    && rm /tmp/node.tar.xz \
    && /opt/node/bin/npm install -g "npm@${NPM_VERSION}" \
    && /opt/node/bin/npm cache clean --force

RUN useradd --system --create-home --home-dir /home/explorer --shell /usr/sbin/nologin explorer

# fluxd reads its proving parameters from its user's home
RUN setpriv --reuid=explorer --regid=explorer --init-groups -- env HOME=/home/explorer flux-fetch-params

WORKDIR /opt/explorer
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund && npm cache clean --force

COPY entrypoint.sh check-health.sh /usr/local/bin/

VOLUME /data
EXPOSE 3001/tcp

# bitcore-node stops fluxd cleanly on SIGINT and has no SIGTERM handler
STOPSIGNAL SIGINT

HEALTHCHECK --start-period=30m --interval=2m --retries=5 --timeout=15s CMD ["check-health.sh"]

ENTRYPOINT ["entrypoint.sh"]
