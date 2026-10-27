#!/usr/bin/env bash
# Starts the image with an empty volume and a MongoDB beside it, no bootstrap, and checks what a
# fresh Flux instance depends on: the files the entrypoint writes, the user everything runs as,
# the health check passing, the API answering, and fluxd stopping cleanly on the image's stop signal.
#
# Usage: test/smoke.sh <image>
set -euo pipefail

IMAGE=$1
NET=explorer-smoke
DB=fluxmongodb_explorersmoke

cleanup() { docker rm -f explorer "$DB" >/dev/null 2>&1 || true; docker network rm "$NET" >/dev/null 2>&1 || true; }
trap cleanup EXIT
fail() { echo "FAIL: $*"; docker logs explorer 2>&1 | tail -40; exit 1; }

cleanup
docker network create "$NET" >/dev/null
docker run -d --name "$DB" --network "$NET" mongo:8.0.34 >/dev/null
docker run -d --name explorer --network "$NET" -e DB_COMPONENT_NAME="$DB" -e BOOTSTRAP=0 "$IMAGE" >/dev/null

for _ in $(seq 1 60); do
  docker exec explorer check-health.sh >/dev/null 2>&1 && break
  sleep 5
done
docker exec explorer check-health.sh >/dev/null 2>&1 || fail "the health check never passed"
echo "health check passes"

# bitcore-node has started every service once the API answers
for _ in $(seq 1 60); do
  docker exec explorer curl -sf -m 5 http://127.0.0.1:3001/api/sync >/dev/null 2>&1 && break
  sleep 5
done
sync=$(docker exec explorer curl -sf -m 5 http://127.0.0.1:3001/api/sync) || fail "the API never answered"
echo "the API answers: $sync"

config=$(docker exec explorer cat /data/explorer/bitcore-node.json)
[[ $(jq -r '.network' <<<"$config") == livenet ]] || fail "network is not livenet"
[[ $(jq -r '.servicesConfig["insight-api"].db.host' <<<"$config") == "$DB" ]] || fail "database host is not $DB"
[[ $(jq -r '.servicesConfig.bitcoind.spawn.datadir' <<<"$config") == /data/explorer/data ]] || fail "datadir"
echo "bitcore-node.json names livenet, $DB and /data/explorer/data"

docker exec explorer grep -qx 'rpcport=16124' /data/explorer/data/flux.conf || fail "flux.conf"
docker exec explorer grep -qx 'rpcworkqueue=128' /data/explorer/data/flux.conf || fail "flux.conf tuning"
[[ $(docker exec explorer stat -c '%U %a' /data/explorer/data/flux.conf) == "explorer 600" ]] \
  || fail "flux.conf is not the explorer user's, mode 600"
echo "flux.conf written, explorer's, mode 600"

others=$(docker exec explorer ps -o user=,comm= -A | awk '$1 != "explorer" && $2 != "ps"')
[[ -z $others ]] || fail "processes not run as explorer: $others"
docker exec explorer ps -o comm= -A | grep -qx fluxd || fail "fluxd is not running"
echo "node and fluxd run as explorer"

password=$(docker exec explorer sed -n 's/^rpcpassword=//p' /data/explorer/data/flux.conf)
docker exec explorer sed -i 's/^dbcache=.*/dbcache=1/' /data/explorer/data/flux.conf
docker restart -t 120 explorer >/dev/null
for _ in $(seq 1 60); do
  docker exec explorer curl -sf -m 5 http://127.0.0.1:3001/api/sync >/dev/null 2>&1 && break
  sleep 5
done
[[ $(docker exec explorer sed -n 's/^rpcpassword=//p' /data/explorer/data/flux.conf) == "$password" ]] \
  || fail "the RPC password changed on restart"
docker exec explorer grep -qx 'dbcache=450' /data/explorer/data/flux.conf || fail "flux.conf not rewritten on restart"
echo "a restart keeps the RPC password and rewrites the settings"

docker stop -t 120 explorer >/dev/null
[[ $(docker inspect explorer --format '{{.State.ExitCode}}') == 0 ]] || fail "non-zero exit on stop"
debuglog=$(mktemp)
docker cp explorer:/data/explorer/data/debug.log "$debuglog" || fail "fluxd's debug.log could not be read"
grep -q 'Shutdown: done' "$debuglog" || { tail -5 "$debuglog"; fail "fluxd did not shut down cleanly"; }
rm -f "$debuglog"
echo "stops cleanly: exit 0, fluxd logged its shutdown"
