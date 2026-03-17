#!/usr/bin/env bash
set -e

APP_DIR="/app"
TS_DIR="/paperclip/tailscale"
TS_SOCKET="/tmp/tailscaled.sock"

# --- 1. Fix volume permissions (Railway mounts as root) ---
if [ "$(id -u)" = "0" ]; then
  mkdir -p "$TS_DIR"
  chown -R node:node /paperclip
  exec su node -c "$APP_DIR/start.sh"
fi

# --- 2. Ensure tailscale state dir exists ---
mkdir -p "$TS_DIR"

# --- 3. Start tailscaled if not already running ---
if ! pgrep -x tailscaled > /dev/null; then
  tailscaled \
    --state="$TS_DIR/tailscaled.state" \
    --socket="$TS_SOCKET" \
    --tun=userspace-networking &
fi

# --- 4. Wait for tailscaled socket ---
for i in {1..10}; do
  if [ -S "$TS_SOCKET" ]; then
    break
  fi
  sleep 1
done

# --- 5. Check if already authenticated ---
if tailscale --socket="$TS_SOCKET" status >/dev/null 2>&1; then
  echo "Tailscale already authenticated"
else
  echo "Authenticating Tailscale..."
  tailscale --socket="$TS_SOCKET" up \
    --authkey="$TS_AUTHKEY" \
    --hostname="${TS_HOSTNAME:-paperclip}" \
    --accept-dns=false
fi

# --- 6. Start app ---
exec node --import ./server/node_modules/tsx/dist/loader.mjs server/dist/index.js