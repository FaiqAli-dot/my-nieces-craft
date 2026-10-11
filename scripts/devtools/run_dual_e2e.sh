#!/usr/bin/env bash
# Full 15-step two-player scenario: real server + two Godot client processes.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
E2E_DIR="${COZY_E2E_DIR:-/tmp/cozy_e2e_$$}"
DATA_DIR="${COZY_HOUSE_DATA:-/tmp/cozyblocks_houses_e2e_$$}"
SHOT_DIR="${COZY_SHOT_DIR:-/opt/cursor/artifacts/screenshots/phase2}"
PORT="${COZY_NET_PORT:-19090}"
mkdir -p "$E2E_DIR" "$DATA_DIR" "$SHOT_DIR" /opt/cursor/artifacts/videos
rm -f "$E2E_DIR"/*

echo "[E2E] dir=$E2E_DIR port=$PORT"

# Free stale listeners on this port (prior dual-e2e / stray server.tscn).
if command -v fuser >/dev/null 2>&1; then
  fuser -k "${PORT}/tcp" 2>/dev/null || true
elif command -v lsof >/dev/null 2>&1; then
  lsof -tiTCP:"$PORT" -sTCP:LISTEN | xargs -r kill 2>/dev/null || true
fi
sleep 0.3

# 1) Headless server (with env from the first launch)
export COZY_NET_PORT="$PORT" COZY_HOUSE_DATA="$DATA_DIR"
COZY_NET_PORT="$PORT" COZY_HOUSE_DATA="$DATA_DIR" \
  godot --headless --path . res://scenes/server/server.tscn \
  >"$E2E_DIR/server.log" 2>&1 &
SERVER_PID=$!
for _i in $(seq 1 40); do
  if grep -q "listening on" "$E2E_DIR/server.log" 2>/dev/null; then
    break
  fi
  if grep -q "Failed to listen" "$E2E_DIR/server.log" 2>/dev/null; then
    echo "[E2E] server failed to bind port $PORT" >&2
    cat "$E2E_DIR/server.log" >&2 || true
    exit 1
  fi
  sleep 0.15
done
if ! grep -q "listening on" "$E2E_DIR/server.log" 2>/dev/null; then
  echo "[E2E] server did not become ready" >&2
  cat "$E2E_DIR/server.log" >&2 || true
  exit 1
fi

# Shared Xvfb for dual windows side-by-side
export DISPLAY=:98
pkill -f "Xvfb :98" 2>/dev/null || true
rm -f /tmp/.X98-lock /tmp/.X11-unix/X98 2>/dev/null || true
sleep 0.2
Xvfb :98 -screen 0 2560x720x24 >/tmp/xvfb98.log 2>&1 &
XVFB_PID=$!
for _i in $(seq 1 40); do
  if xdpyinfo -display :98 >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
if ! xdpyinfo -display :98 >/dev/null 2>&1; then
  echo "[E2E] Xvfb :98 not ready" >&2
  cat /tmp/xvfb98.log >&2 || true
  kill "$SERVER_PID" 2>/dev/null || true
  exit 1
fi

# 2) Alice client (left)
COZY_NET_HOST=127.0.0.1 COZY_NET_PORT="$PORT" \
COZY_DEV_IDENTITY=alice_e2e COZY_DISPLAY_NAME=Alice \
COZY_E2E_ROLE=alice COZY_E2E_DIR="$E2E_DIR" COZY_E2E_QUIT=1 \
COZY_FORCE_TOUCH=1 COZY_SHOT_DIR="$SHOT_DIR" \
  godot --path . res://scenes/house/house.tscn --resolution 1280x720 \
  --position 0,0 \
  --rendering-method gl_compatibility --rendering-driver opengl3 \
  >"$E2E_DIR/alice.log" 2>&1 &
ALICE_PID=$!

# 3) Bob client (right)
COZY_NET_HOST=127.0.0.1 COZY_NET_PORT="$PORT" \
COZY_DEV_IDENTITY=bob_e2e COZY_DISPLAY_NAME=Bob \
COZY_E2E_ROLE=bob COZY_E2E_DIR="$E2E_DIR" COZY_E2E_QUIT=1 \
COZY_NET_AUTOSTART=1 COZY_FORCE_TOUCH=1 COZY_SHOT_DIR="$SHOT_DIR" \
  godot --path . res://scenes/house/house.tscn --resolution 1280x720 \
  --position 1280,0 \
  --rendering-method gl_compatibility --rendering-driver opengl3 \
  >"$E2E_DIR/bob.log" 2>&1 &
BOB_PID=$!

# Record side-by-side while scenario runs
ffmpeg -y -f x11grab -video_size 2560x720 -framerate 12 -i :98 -t 55 \
  -c:v libx264 -pix_fmt yuv420p \
  /opt/cursor/artifacts/videos/phase2_dual_client_e2e.mp4 \
  >"$E2E_DIR/ffmpeg.log" 2>&1 &
FFMPEG_PID=$!

# Orchestrate backend restart when alice signals
(
  for i in $(seq 1 90); do
    if [[ -f "$E2E_DIR/alice_done_pre_restart.txt" && -f "$E2E_DIR/bob_disconnected.txt" ]]; then
      echo "[E2E] restarting server..."
      kill "$SERVER_PID" 2>/dev/null || true
      sleep 0.8
      COZY_NET_PORT="$PORT" COZY_HOUSE_DATA="$DATA_DIR" \
        godot --headless --path . res://scenes/server/server.tscn \
        >"$E2E_DIR/server_restart.log" 2>&1 &
      SERVER_PID=$!
      sleep 1.0
      echo 1 >"$E2E_DIR/restart_done.txt"
      break
    fi
    sleep 0.5
  done
) &

# Wait for clients
ALICE_EC=0
BOB_EC=0
wait "$ALICE_PID" || ALICE_EC=$?
wait "$BOB_PID" || BOB_EC=$?
wait "$FFMPEG_PID" 2>/dev/null || true

# Side-by-side still from latest dual frames if present
LEFT="$SHOT_DIR/alice_02_both_visible.png"
RIGHT="$SHOT_DIR/bob_02_placed.png"
if [[ ! -f "$LEFT" ]]; then LEFT="$SHOT_DIR/alice_03_synced_chair.png"; fi
if [[ -f "$LEFT" && -f "$RIGHT" ]]; then
  LEFT="$LEFT" RIGHT="$RIGHT" SHOT_DIR="$SHOT_DIR" python3 - <<'PY' || echo "[E2E] side-by-side collage skipped (Pillow unavailable)"
import os, sys
try:
    from PIL import Image
except ImportError:
    sys.exit(1)
left = Image.open(os.environ["LEFT"])
right = Image.open(os.environ["RIGHT"])
h = max(left.height, right.height)
canvas = Image.new("RGB", (left.width + right.width, h), (40, 44, 48))
canvas.paste(left, (0, 0))
canvas.paste(right, (left.width, 0))
out = os.path.join(os.environ["SHOT_DIR"], "08_dual_client_side_by_side.png")
canvas.save(out)
print("wrote side-by-side", out)
PY
fi

kill "$SERVER_PID" 2>/dev/null || true
kill "$XVFB_PID" 2>/dev/null || true

echo "[E2E] alice_exit=$ALICE_EC bob_exit=$BOB_EC"
grep -E 'PASS:|FAIL:|Results' "$E2E_DIR/alice.log" "$E2E_DIR/bob.log" || true
ls -la "$SHOT_DIR"/alice_*.png "$SHOT_DIR"/bob_*.png 2>/dev/null || true
ls -la /opt/cursor/artifacts/videos/phase2_dual_client_e2e.mp4 2>/dev/null || true

# Fail if any FAIL lines
if grep -q 'FAIL:' "$E2E_DIR/alice.log" "$E2E_DIR/bob.log"; then
  exit 1
fi
exit 0
