#!/usr/bin/env bash
# preload-patterns.sh DOMAIN [DOMAIN...]  — prints a Markdown block of the highest-reward patterns per domain,
# ready to drop into an agent's context file (CLAUDE.md, AGENTS.md, .agentic-qe/PRELOAD.md).
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
DB="${NAGUAL_DB:-$ROOT/.nagual/nagual.db}"
LIMIT="${LIMIT:-5}"

echo "# Preloaded patterns ($(date -u +%Y-%m-%dT%H:%MZ))"
echo
echo "These are the highest-reward patterns for the domains this run touches. Treat each as a hypothesis with a score, not a fact."
for d in "$@"; do
  echo
  echo "## $d"
  # Needs nagual-qe >= 0.2.0 — earlier builds applied --limit before the --domain filter.
  out="$(nagual knowledge list --domain "$d" --sort reward --limit "$LIMIT" --db-path "$DB" 2>/dev/null)"
  if printf '%s\n' "$out" | grep -qE '^[0-9a-f]{8}-'; then
    printf '%s\n' "$out"
  else
    echo "_(no patterns yet — this run will create the first ones)_"
  fi
done
