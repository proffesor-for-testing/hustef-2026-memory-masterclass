#!/usr/bin/env bash
# Prints one line per tool. Green = ready. Used by post-create and by `make check`.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ok()   { printf '  \033[1;32m✔\033[0m %-18s %s\n' "$1" "$2"; }
miss() { printf '  \033[1;31m✘\033[0m %-18s %s\n' "$1" "$2"; FAIL=1; }
FAIL=0
echo; echo "  Masterclass environment check"; echo "  -----------------------------"

v() { "$@" 2>/dev/null | head -1; }
command -v node    >/dev/null && ok node    "$(v node --version)"          || miss node "not found"
command -v npm     >/dev/null && ok npm     "$(v npm --version)"           || miss npm "not found"
command -v cargo   >/dev/null && ok cargo   "$(v cargo --version)"         || miss cargo "not found"
command -v python3 >/dev/null && ok python3 "$(v python3 --version)"       || miss python3 "not found"
command -v claude  >/dev/null && ok claude  "$(v claude --version)"        || miss claude "npm i -g @anthropic-ai/claude-code"
command -v codex   >/dev/null && ok codex   "$(v codex --version)"         || miss codex "npm i -g @openai/codex"
command -v aqe     >/dev/null && ok aqe     "agentic-qe $(v aqe --version)" || miss aqe "npm i -g agentic-qe"
command -v nagual  >/dev/null && ok nagual  "$(v nagual --version)"        || miss nagual "bash .devcontainer/post-create.sh"
command -v gh      >/dev/null && ok gh      "$(v gh --version)"            || miss gh "optional"

[ -d "$ROOT/workspace/iron-pets/.agentic-qe" ] && ok "fleet memory" "$ROOT/workspace/iron-pets/.agentic-qe" || miss "fleet memory" "run: make reset"
[ -f "$ROOT/.nagual/nagual.db" ] && ok "nagual db" "$ROOT/.nagual/nagual.db ($(du -h "$ROOT/.nagual/nagual.db" | cut -f1))" || miss "nagual db" "run: make reset"

if pg_isready -h postgres -U ironpets >/dev/null 2>&1; then ok postgres "reachable (postgres:5432)"; else miss postgres "not reachable — Iron Pets UI demo only; memory exercises unaffected"; fi
if redis-cli -h redis ping >/dev/null 2>&1; then ok redis "reachable"; else miss redis "not reachable — optional"; fi

echo
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then ok "ANTHROPIC_API_KEY" "set"; else printf '  \033[1;33m•\033[0m %-18s %s\n' "ANTHROPIC_API_KEY" "not set — run 'claude' once to log in, or add a Codespaces secret"; fi
if [ -n "${OPENAI_API_KEY:-}" ];    then ok "OPENAI_API_KEY" "set";    else printf '  \033[1;33m•\033[0m %-18s %s\n' "OPENAI_API_KEY" "not set — optional; run 'codex login' if you want Codex"; fi
echo
exit $FAIL
