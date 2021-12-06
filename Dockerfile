FROM debian:buster-slim
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
apt-get install -y wget curl jq lsb-release gnupg dirmngr tar pv

RUN echo 'deb https://apt.runonflux.io/ '$(lsb_release -cs)' main' | tee --append /etc/apt/sources.list.d/flux.list && \
gpg --keyserver keyserver.ubuntu.com --recv 4B69CA27A986265D && \
gpg --export 4B69CA27A986265D | apt-key add - && \
apt-get update && \
apt-get install -y flux

RUN mkdir -p /root/bitcore-node
COPY daemon_initialize.sh /daemon_initialize.sh
COPY check-health.sh /check-health.sh
VOLUME /root/bitcore-node
EXPOSE 3001/tcp
RUN chmod 755 daemon_initialize.sh check-health.sh
HEALTHCHECK --start-period=15m --interval=2m --retries=5 --timeout=15s CMD ./check-health.sh
CMD ./daemon_initialize.sh
