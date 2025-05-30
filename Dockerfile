FROM ubuntu:24.04

ENV DEBIAN_FRONTEND noninteractive
LABEL com.centurylinklabs.watchtower.enable="true"

ENV TESTNET=${TESTNET:-0}

# Install required dependencies + Python 3.10 from PPA
RUN apt-get update && apt-get install -y \
    software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update && apt-get install -y \
    wget curl jq gnupg lsb-release dirmngr tar pv pwgen dirmngr tar pv bc build-essential libzmq3-dev git \
    python3.10 python3.10-distutils && \
    ln -sf /usr/bin/python3.10 /usr/bin/python && \
    rm -rf /var/lib/apt/lists/*

# Add the Flux repository and import GPG key
RUN mkdir -p /usr/share/keyrings root/.gnupg  && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/flux-archive-keyring.gpg] https://apt.runonflux.io/ focal main" | tee /etc/apt/sources.list.d/flux.list > /dev/null && \
    gpg --no-default-keyring --keyring /usr/share/keyrings/flux-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 4B69CA27A986265D && \
    apt-get update && \
    apt-get install -y flux

RUN /bin/bash -c "flux-fetch-params.sh"
RUN touch ~/.bashrc && chmod +x ~/.bashrc

# Ensure you install nvm properly
RUN export NVM_DIR="/root/.nvm" && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash && \
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && \
    nvm install 12.22.12 && \
    nvm use 12.22.12 && \
    nvm alias default 12.22.12 && \
    ln -sf $NVM_DIR/versions/node/v12.22.12/bin/node /usr/bin/node && \
    ln -sf $NVM_DIR/versions/node/v12.22.12/bin/npm /usr/bin/npm

COPY daemon_initialize.sh /daemon_initialize.sh
COPY check-health.sh /check-health.sh
RUN chmod 755 daemon_initialize.sh check-health.sh

RUN mkdir -p /data
VOLUME /data
EXPOSE 3001/tcp

HEALTHCHECK --start-period=15m --interval=2m --retries=5 --timeout=15s CMD ./check-health.sh

CMD ["bash", "-c", "./daemon_initialize.sh"]
