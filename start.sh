#!/usr/bin/env bash
set -e

APP_CMD="node --import ./server/node_modules/tsx/dist/loader.mjs server/dist/index.js"
TS_DIR="/paperclip/tailscale"
TS_SOCKET="/tmp/tailscaled.sock"

# --- always fix permissions first (we are root now) ---
mkdir -p "$TS_DIR"
chown -R node:node /paperclip

# --- drop to node user for everything else ---
exec su node -c "
  set -e

  # start tailscaled if not running
  if ! pgrep -x tailscaled > /dev/null; then
    tailscaled \
      --state=$TS_DIR/tailscaled.state \
      --socket=$TS_SOCKET \
      --tun=userspace-networking &
  fi

  # wait for socket
  for i in {1..10}; do
    [ -S $TS_SOCKET ] && break
    sleep 1
  done

  # authenticate only if needed
  if tailscale --socket=$TS_SOCKET status >/dev/null 2>&1; then
    echo 'Tailscale already connected'
  else
    tailscale --socket=$TS_SOCKET up \
      --authkey=$TS_AUTHKEY \
      --hostname=${TS_HOSTNAME:-paperclip} \
      --accept-dns=false
  fi

  # start app
  exec $APP_CMD
"