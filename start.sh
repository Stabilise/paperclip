#!/usr/bin/env bash
set -e

APP_CMD="node --import ./server/node_modules/tsx/dist/loader.mjs server/dist/index.js"
TS_DIR="/paperclip/tailscale"
TS_SOCKET="/tmp/tailscaled.sock"

# --- FIX EXISTING PERMISSIONS (non-destructive) ---
echo "Fixing existing /paperclip permissions..."
mkdir -p /paperclip
chown -R node:node /paperclip 2>/dev/null || true
chmod -R u+rwX /paperclip 2>/dev/null || true

# --- drop privileges ---
exec su node -c "
set -e

mkdir -p $TS_DIR

if ! pgrep -x tailscaled > /dev/null; then
  tailscaled \
    --state=$TS_DIR/tailscaled.state \
    --socket=$TS_SOCKET \
    --tun=userspace-networking &
fi

for i in {1..10}; do
  [ -S $TS_SOCKET ] && break
  sleep 1
done

if tailscale --socket=$TS_SOCKET status >/dev/null 2>&1; then
  echo 'Tailscale already connected'
else
  tailscale --socket=$TS_SOCKET up \
    --authkey=$TS_AUTHKEY \
    --hostname=${TS_HOSTNAME:-paperclip} \
    --accept-dns=false
fi

# ensure hostname allowed (safe, idempotent)
pnpm paperclipai allowed-hostname ${TS_HOSTNAME:-paperclip} || true

exec $APP_CMD
"