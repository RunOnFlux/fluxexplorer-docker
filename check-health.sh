#!/usr/bin/env bash
# Healthy when the explorer's API answers. While the bootstrap downloads, or fluxd is loading or
# catching up before bitcore-node serves, a fluxd that answers RPC is enough.
set -uo pipefail

DATA=/data/explorer

[[ -e $DATA/.bootstrapping ]] && exit 0
curl -sf -m 10 http://127.0.0.1:3001/api/sync >/dev/null && exit 0
flux-cli -conf="$DATA/data/flux.conf" -datadir="$DATA/data" getblockcount >/dev/null 2>&1
