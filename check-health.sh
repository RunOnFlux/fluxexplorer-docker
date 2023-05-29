#!/usr/bin/env bash
if [[ "$NETWORK" == "1" ]]; then
  CURRENT_NODE_HEIGHT=$(flux-cli -testnet -datadir=/data/bitcore-node/bin/mynode/data getinfo | jq '.blocks')
else
  CURRENT_NODE_HEIGHT=$(flux-cli -datadir=/data/bitcore-node/bin/mynode/data getinfo | jq '.blocks')
fi
if ! egrep -o "^[0-9]+$" <<< "$CURRENT_NODE_HEIGHT" &>/dev/null; then
  echo "Daemon not working correct..."
  exit 1
else
  echo "Daemon working correct..."
  exit
fi
