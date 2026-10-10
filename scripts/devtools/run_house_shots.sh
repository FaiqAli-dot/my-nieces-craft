#!/usr/bin/env bash
# Live-server Phase 2 house screenshots (no "Offline demo").
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
SHOT_DIR="${COZY_SHOT_DIR:-/opt/cursor/artifacts/screenshots/phase2}"
DATA_DIR="${COZY_HOUSE_DATA:-/tmp/cozyblocks_houses_shots_$$}"
PORT="${COZY_NET_PORT:-19091}"
mkdir -p "$SHOT_DIR" "$DATA_DIR"

export DISPLAY="${DISPLAY:-:97}"
pkill -f "Xvfb ${DISPLAY}" 2>/dev/null || true
Xvfb "$DISPLAY" -screen 0 1280x720x24 >/tmp/xvfb_shots.log 2>&1 &
XVFB_PID=$!
sleep 0.6

COZY_NET_PORT="$PORT" COZY_HOUSE_DATA="$DATA_DIR" \
  godot --headless --path . res://scenes/server/server.tscn \
  >/tmp/cozy_shot_server.log 2>&1 &
SERVER_PID=$!
sleep 1.2

COZY_NET_HOST=127.0.0.1 COZY_NET_PORT="$PORT" \
COZY_DEV_IDENTITY=alice_shots COZY_DISPLAY_NAME=Alice \
COZY_NET_AUTOSTART=1 COZY_SCREENSHOTS=1 COZY_SMOKE_QUIT=1 \
COZY_SHOT_DIR="$SHOT_DIR" COZY_FORCE_TOUCH=1 \
  godot --path . res://scenes/house/house.tscn --resolution 1280x720 \
  --rendering-method gl_compatibility --rendering-driver opengl3 \
  >/tmp/cozy_shot_client.log 2>&1
CLIENT_EC=$?

kill "$SERVER_PID" 2>/dev/null || true
kill "$XVFB_PID" 2>/dev/null || true
ls -la "$SHOT_DIR"/*.png || true
grep -E 'SHOT|Offline|ERROR|Parse' /tmp/cozy_shot_client.log || true
exit "$CLIENT_EC"
