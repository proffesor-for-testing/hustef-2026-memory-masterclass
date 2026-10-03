#!/usr/bin/env bash
# Prints one line per tool. Green = ready. Used by post-create and by `make check`.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ok()   { printf '  \033[1;32m✔\033[0m %-18s %s\n' "$1" "$2"; }
miss() { printf '  \033[1;31m✘\033[0m %-18s %s\n' "$1" "$2"; FAIL=1; }
FAIL=0
echo; echo "  Masterclass environment check"; echo "  -----------------------------"

v() { "$@" 2>/dev/null | head -1; }
if command -v node >/dev/null && node -e 'const [major, minor] = process.versions.node.split(".").map(Number); process.exit(major > 22 || (major === 22 && minor >= 13) ? 0 : 1)'; then
  ok node "$(v node --version)"
else
  miss node "Node >=22.13 required by agentic-qe 3.14.7"
fi
command -v npm     >/dev/null && ok npm     "$(v npm --version)"           || miss npm "not found"
command -v cargo   >/dev/null && ok cargo   "$(v cargo --version)"         || miss cargo "not found"
command -v python3 >/dev/null && ok python3 "$(v python3 --version)"       || miss python3 "not found"
command -v claude  >/dev/null && ok claude  "$(v claude --version)"        || miss claude "npm i -g @anthropic-ai/claude-code"
command -v codex   >/dev/null && ok codex   "$(v codex --version)"         || miss codex "npm i -g @openai/codex"
command -v aqe     >/dev/null && ok aqe     "agentic-qe $(v aqe --version)" || miss aqe "npm i -g agentic-qe"
command -v nagual  >/dev/null && ok nagual  "$(v nagual --version)"        || miss nagual "bash .devcontainer/post-create.sh"
command -v gh      >/dev/null && ok gh      "$(v gh --version)"            || miss gh "optional"

fleet_ready() {
  local entries key
  cd "$ROOT/workspace/iron-pets" || return 1
  entries="$(aqe memory list --namespace aqe 2>/dev/null)" || return 1
  for key in coverage/cart-service coverage/checkout-service test-plan/checkout test-plan/cart \
             flaky/cart-total-e2e risk/payment-module env/staging-window quality-gate/r-0417; do
    [[ "$entries" == *"$key"* ]] || return 1
  done
}
if [ -d "$ROOT/workspace/iron-pets/.agentic-qe" ] \
   && command -v aqe >/dev/null \
   && (fleet_ready); then
  ok "fleet memory" "$ROOT/workspace/iron-pets/.agentic-qe"
else
  miss "fleet memory" "missing seeded entries or CLI failure — run: make reset"
fi
if [ -f "$ROOT/workspace/iron-pets/artifacts/coverage-cart-2026-10-06.json" ] \
   && [ -f "$ROOT/workspace/iron-pets/artifacts/coverage-checkout-2026-10-06.json" ] \
   && [ -f "$ROOT/workspace/iron-pets/artifacts/test-run-2026-10-06T09-14.log" ] \
   && [ -f "$ROOT/workspace/iron-pets/artifacts/flake-history-cart.json" ] \
   && [ -f "$ROOT/workspace/iron-pets/artifacts/incidents-payment-q3.json" ] \
   && [ -f "$ROOT/workspace/iron-pets/artifacts/staging-restore-cron.txt" ] \
   && [ -f "$ROOT/workspace/iron-pets/artifacts/gate-r-0417.json" ] \
   && [ -f "$ROOT/workspace/iron-pets/src/iron-pets/backend/tests/checkout.test.ts" ]; then
  ok "run receipts" "simulated evidence files present"
else
  miss "run receipts" "missing simulated evidence — run: bash scripts/seed-fleet-memory.sh"
fi
[ -f "${ORT_DYLIB_PATH:-/nonexistent}" ] && ok "onnx runtime" "$(basename "$(readlink -f "$ORT_DYLIB_PATH")")" || miss "onnx runtime" "bash .devcontainer/post-create.sh"
[ -f "${NAGUAL_MODEL_DIR:-$HOME/.nagual/models}/all-MiniLM-L6-v2.onnx" ] && ok "embedding model" "all-MiniLM-L6-v2" || miss "embedding model" "bash .devcontainer/post-create.sh"
if [ -f "$ROOT/.nagual/nagual.db" ] && command -v sqlite3 >/dev/null; then
  read -r TOTAL EMB <<<"$(sqlite3 -separator ' ' "$ROOT/.nagual/nagual.db" "SELECT COUNT(*), COALESCE(SUM(embedding IS NOT NULL AND length(embedding) > 0), 0) FROM reasoning_patterns" 2>/dev/null)"
  [ -n "${TOTAL:-}" ] && [ "$TOTAL" = "$EMB" ] && ok "embeddings" "$EMB/$TOTAL patterns" || miss "embeddings" "${EMB:-0}/${TOTAL:-?} patterns - run: make reset"
fi
[ -f "$ROOT/.nagual/nagual.db" ] && ok "nagual db" "$ROOT/.nagual/nagual.db ($(du -h "$ROOT/.nagual/nagual.db" | cut -f1))" || miss "nagual db" "run: make reset"

if pg_isready -h postgres -U ironpets >/dev/null 2>&1; then ok postgres "reachable (postgres:5432)"; else miss postgres "not reachable — Iron Pets UI demo only; memory exercises unaffected"; fi
if redis-cli -h redis ping >/dev/null 2>&1; then ok redis "reachable"; else miss redis "not reachable — optional"; fi

echo
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then ok "ANTHROPIC_API_KEY" "set"; else printf '  \033[1;33m•\033[0m %-18s %s\n' "ANTHROPIC_API_KEY" "not set — run 'claude' once to log in, or add a Codespaces secret"; fi
if [ -n "${OPENAI_API_KEY:-}" ];    then ok "OPENAI_API_KEY" "set";    else printf '  \033[1;33m•\033[0m %-18s %s\n' "OPENAI_API_KEY" "not set — optional; run 'codex login' if you want Codex"; fi
echo
exit $FAIL
