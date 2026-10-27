#!/usr/bin/env bash
# Prepares /data as root, then runs the explorer as the explorer user.
#
# /data/explorer holds everything that persists: bitcore-node.json, fluxd's datadir (data/) and
# its flux.conf. The code is in the image (/opt/explorer), so a new image is new code.
set -euo pipefail

DATA=/data/explorer
CHAIN=$DATA/data
STAGE=$DATA/bootstrap
MARKER=$DATA/.bootstrapping
# The previous image's fluxd datadir: its chain is kept, its code is not used
LEGACY_CHAIN=/data/bitcore-node/bin/mynode/data
BOOTSTRAP_URL=${BOOTSTRAP_URL:-https://cdn-geo.runonflux.io/apps/fluxshare/getfile/flux_explorer_bootstrap.tar.gz}
BOOTSTRAP_ATTEMPTS=3

log() { echo "[entrypoint] $*"; }
as_explorer() { setpriv --reuid=explorer --regid=explorer --init-groups -- env HOME=/home/explorer "$@"; }

# fluxd keeps a testnet chain in a subdirectory of its datadir
if [[ ${TESTNET:-0} == 1 ]]; then NETWORK=testnet; BLOCKS=$CHAIN/testnet3/blocks
else NETWORK=livenet; BLOCKS=$CHAIN/blocks; fi
DB_HOST=${DB_COMPONENT_NAME:-fluxmongodb_explorerflux}
log "network $NETWORK, database host $DB_HOST"

mkdir -p "$CHAIN"

if [[ -d $LEGACY_CHAIN/blocks && ! -d $CHAIN/blocks ]]; then
  log "moving the chain from $LEGACY_CHAIN to $CHAIN"
  find "$LEGACY_CHAIN" -mindepth 1 -maxdepth 1 ! -name flux.conf ! -name '*.tar.gz' \
    -exec mv -t "$CHAIN" {} +
fi

if [[ -n $(find "$DATA" ! -user explorer -print -quit) ]]; then
  log "giving $DATA to the explorer user"
  chown -R explorer:explorer "$DATA"
fi

# Written on every start, so a new image's settings reach an existing volume; the RPC password is
# kept from the previous file. maxconnections: an explorer only follows the chain. rpcworkqueue and
# rpcthreads take bitcore-node's calls in flight (rpcqueue in bitcore-node.json) with room to spare.
password=
if [[ -f $CHAIN/flux.conf ]]; then password=$(sed -n 's/^rpcpassword=//p' "$CHAIN/flux.conf"); fi
[[ -n $password ]] || password=$(head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')
log "writing $CHAIN/flux.conf"
{
  echo "server=1"
  echo "txindex=1"
  echo "addressindex=1"
  echo "timestampindex=1"
  echo "spentindex=1"
  echo "insightexplorer=1"
  echo "experimentalfeatures=1"
  echo "zmqpubrawtx=tcp://127.0.0.1:28332"
  echo "zmqpubhashblock=tcp://127.0.0.1:28332"
  echo "rpcport=16124"
  echo "rpcbind=127.0.0.1"
  echo "rpcallowip=127.0.0.1"
  echo "rpcuser=explorer"
  echo "rpcpassword=$password"
  echo "rpcworkqueue=128"
  echo "rpcthreads=8"
  echo "dbcache=450"
  echo "maxconnections=32"
  echo "uacomment=bitcore"
  echo "maxtxfee=1.0"
  echo "showmetrics=0"
  if [[ $NETWORK == testnet ]]; then echo "testnet=1"; fi
} | as_explorer tee "$CHAIN/flux.conf.new" >/dev/null
chmod 600 "$CHAIN/flux.conf.new"
mv "$CHAIN/flux.conf.new" "$CHAIN/flux.conf"

if [[ ${BOOTSTRAP:-0} == 1 && ! -d $BLOCKS ]]; then
  as_explorer touch "$MARKER"
  for attempt in $(seq 1 $BOOTSTRAP_ATTEMPTS); do
    rm -rf "$STAGE"
    as_explorer mkdir "$STAGE"
    log "bootstrap attempt $attempt of $BOOTSTRAP_ATTEMPTS: streaming $BOOTSTRAP_URL"
    # shellcheck disable=SC2016  # $1 and $2 are the inner shell's arguments
    if as_explorer bash -o pipefail -c 'curl -fsSL --retry 5 --retry-delay 10 "$1" | tar -xz -C "$2"' \
        _ "$BOOTSTRAP_URL" "$STAGE"; then
      # The archive's entries replace whatever a chainless datadir holds under the same names
      shopt -s dotglob nullglob
      for entry in "$STAGE"/*; do
        rm -rf "${CHAIN:?}/${entry##*/}"
        mv "$entry" "$CHAIN/"
      done
      shopt -u dotglob nullglob
      log "bootstrap unpacked"
      break
    fi
    log "bootstrap attempt $attempt failed"
  done
  rm -rf "$STAGE" "$MARKER"
  if [[ ! -d $BLOCKS ]]; then
    log "no bootstrap after $BOOTSTRAP_ATTEMPTS attempts: fluxd syncs from the network"
  fi
fi

jq -n --arg network "$NETWORK" --arg chain "$CHAIN" --arg fluxd "$(command -v fluxd)" \
  --arg db_host "$DB_HOST" '{
  network: $network,
  port: 3001,
  services: ["bitcoind", "@runonflux/insight-api", "@runonflux/insight-ui", "web"],
  messageLog: "",
  servicesConfig: {
    web: {disablePolling: false, enableSocketRPC: false},
    bitcoind: {
      sendTxLog: ($chain + "/pushtx.log"),
      shutdownTimeout: 60000,
      spawn: {
        datadir: $chain,
        exec: $fluxd,
        rpcqueue: 64,
        rpcport: 16124,
        zmqpubrawtx: "tcp://127.0.0.1:28332",
        zmqpubhashblock: "tcp://127.0.0.1:28332"
      }
    },
    "insight-api": {
      routePrefix: "api",
      db: {host: $db_host, port: "27017", database: ("flux-api-" + $network), user: "", password: ""},
      disableRateLimiter: true
    },
    "insight-ui": {apiPrefix: "api", routePrefix: ""}
  }
}' | as_explorer tee "$DATA/bitcore-node.json" >/dev/null

# bitcore-node loads its services from node_modules beside its config
as_explorer ln -sfn /opt/explorer/node_modules "$DATA/node_modules"

cd "$DATA"
log "starting bitcore-node"
# A heap limit makes node, not fluxd, the process that stops when memory runs out.
exec setpriv --reuid=explorer --regid=explorer --init-groups -- env HOME=/home/explorer \
  node --max-old-space-size="${NODE_HEAP_MB:-1536}" \
  /opt/explorer/node_modules/@runonflux/bitcore-node/bin/bitcore-node start
