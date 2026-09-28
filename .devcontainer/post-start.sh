#!/usr/bin/env bash
# Runs every time the container starts. Keeps it quick.
set -uo pipefail
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Nagual dashboard in the background (Block 2 demo). Harmless if the binary is missing.
if command -v nagual >/dev/null 2>&1 && ! pgrep -f "[n]agual serve" >/dev/null 2>&1; then
  ( cd "$ROOT/.nagual" && nohup nagual serve --port 3333 --db-path "$ROOT/.nagual/nagual.db" >"$ROOT/.nagual/serve.log" 2>&1 & ) || true
fi

cat <<'EOF'

  HUSTEF 2026 · Memory as a Quality Signal
  ----------------------------------------
  make check      verify every tool is installed
  make reset      wipe + reseed both memory systems
  exercises/      the two hands-on blocks, in order

EOF
