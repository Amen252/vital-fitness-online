#!/bin/bash
# Starts the backend (if needed) then runs Flutter from the correct app folder.
ROOT="$(cd "$(dirname "$0")" && pwd)"
exec "$ROOT/scripts/dev.sh" "$@"
