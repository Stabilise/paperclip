#!/usr/bin/env bash
set -e

curl -fsSL https://tailscale.com/install.sh | sh

mkdir -p /paperclip/tailscale

tailscaled \
  --state=$TS_STATE_DIR/tailscaled.state \
  --socket=/tmp/tailscaled.sock &

sleep 2

tailscale up \
  --authkey=$TS_AUTHKEY \
  --hostname=$TS_HOSTNAME \
  --accept-dns=false

node --import ./server/node_modules/tsx/dist/loader.mjs server/dist/index.js