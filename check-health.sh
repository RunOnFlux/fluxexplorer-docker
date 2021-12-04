#!/usr/bin/env bash

CURRENT_NODE_HEIGHT=$(flux-cli -datadir=/root/bitcore-node/bin/mynode/data getinfo | jq '.blocks')
if ! egrep -o "^[0-9]+$" <<< "$CURRENT_NODE_HEIGHT" &>/dev/null; then
  echo "Daemon not working correct..."
  exit 1
else
  echo "Daemon working correct..."
  exit
fi
