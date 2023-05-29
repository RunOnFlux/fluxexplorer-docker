FROM debian:buster-slim
ENV DEBIAN_FRONTEND noninteractive
LABEL com.centurylinklabs.watchtower.enable="true"

ENV TESTNET=${TESTNET:-0}
RUN apt-get update && \
apt-get install -y wget curl jq lsb-release gnupg dirmngr tar pv bc build-essential libzmq3-dev git

RUN echo 'deb https://apt.runonflux.io/ '$(lsb_release -cs)' main' | tee --append /etc/apt/sources.list.d/flux.list && \
gpg --keyserver keyserver.ubuntu.com --recv 4B69CA27A986265D && \
gpg --export 4B69CA27A986265D | apt-key add - && \
apt-get update && \
apt-get install -y flux

RUN touch ~/.bashrc && chmod +x ~/.bashrc
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
RUN . ~/.nvm/nvm.sh && source ~/.bashrc && nvm install 8

RUN mkdir -p /root/bitcore-node
COPY daemon_initialize.sh /daemon_initialize.sh
COPY check-health.sh /check-health.sh
VOLUME /root/bitcore-node
EXPOSE 3001/tcp
RUN chmod 755 daemon_initialize.sh check-health.sh
HEALTHCHECK --start-period=15m --interval=2m --retries=5 --timeout=15s CMD ./check-health.sh
CMD ./daemon_initialize.sh
