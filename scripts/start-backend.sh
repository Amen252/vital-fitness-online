#!/bin/bash
# Start the VitalFitness API and wait until it responds on /api/health.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND="$ROOT/backend"
PORT="${PORT:-5050}"
HEALTH_URL="http://127.0.0.1:${PORT}/api/health"
MAX_WAIT=30

if curl -sf "$HEALTH_URL" >/dev/null 2>&1; then
  echo "Backend already running on port ${PORT}"
  exit 0
fi

cd "$BACKEND"
echo "Starting backend on port ${PORT}..."
npm run dev &
BACKEND_PID=$!

cleanup() {
  if kill -0 "$BACKEND_PID" 2>/dev/null; then
    kill "$BACKEND_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

for ((i = 1; i <= MAX_WAIT; i++)); do
  if curl -sf "$HEALTH_URL" >/dev/null 2>&1; then
    echo "Backend ready at ${HEALTH_URL}"
    wait "$BACKEND_PID"
    exit 0
  fi
  sleep 1
done

echo "Backend failed to start within ${MAX_WAIT}s. Check backend logs above."
exit 1
