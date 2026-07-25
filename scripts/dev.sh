#!/bin/bash
# Start backend + Flutter app together (recommended for local development).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-5050}"

# Start backend in background if not already running
if ! curl -sf "http://127.0.0.1:${PORT}/api/health" >/dev/null 2>&1; then
  echo "Starting backend..."
  (cd "$ROOT/backend" && npm run dev) &
  BACKEND_PID=$!

  for ((i = 1; i <= 30; i++)); do
    if curl -sf "http://127.0.0.1:${PORT}/api/health" >/dev/null 2>&1; then
      echo "Backend ready on port ${PORT}"
      break
    fi
    if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
      echo "Backend process exited unexpectedly."
      exit 1
    fi
    sleep 1
  done

  if ! curl -sf "http://127.0.0.1:${PORT}/api/health" >/dev/null 2>&1; then
    echo "Backend did not become ready in time."
    kill "$BACKEND_PID" 2>/dev/null || true
    exit 1
  fi
else
  echo "Backend already running on port ${PORT}"
fi

cd "$ROOT/mobile"
echo "Launching Flutter app..."
flutter "$@"
