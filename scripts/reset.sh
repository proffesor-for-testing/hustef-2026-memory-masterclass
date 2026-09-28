#!/usr/bin/env bash
# Wipes both memory systems back to the seeded state. Run between sessions or when an exercise goes sideways.
set -euo pipefail
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Resetting fleet memory (Iron Pets .agentic-qe)"
rm -rf "$ROOT/workspace/iron-pets/.agentic-qe"
( cd "$ROOT/workspace/iron-pets" && aqe init --auto --minimal --skip-code-index >/dev/null 2>&1 || true )
bash "$ROOT/scripts/seed-fleet-memory.sh"

echo
echo "Resetting Nagual"
pkill -f "[n]agual serve" 2>/dev/null || true
rm -f "$ROOT/.nagual/nagual.db" "$ROOT/.nagual/nagual.db-shm" "$ROOT/.nagual/nagual.db-wal" \
      "$ROOT/.nagual/nagual.dlq.db" "$ROOT/.nagual/.starters-seeded" "$ROOT/.nagual/current-pattern"
bash "$ROOT/scripts/seed-nagual.sh"
bash "$ROOT/.devcontainer/post-start.sh" >/dev/null 2>&1 || true
echo "Done."
