#!/usr/bin/env bash
# preload-patterns.sh DOMAIN [DOMAIN...]  — prints a Markdown block of the highest-reward patterns per domain,
# ready to drop into an agent's context file (CLAUDE.md, AGENTS.md, .agentic-qe/PRELOAD.md).
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
DB="${NAGUAL_DB:-$ROOT/.nagual/nagual.db}"
LIMIT="${LIMIT:-5}"
command -v jq >/dev/null || { echo 'jq is required' >&2; exit 2; }

echo "# Preloaded patterns ($(date -u +%Y-%m-%dT%H:%MZ))"
echo
echo "These are the highest-reward patterns for the domains this run touches. Treat each as a hypothesis with a score, not a fact."
for d in "$@"; do
  echo
  echo "## $d"
  # Needs nagual-qe >= 0.2.0 — earlier builds applied --limit before the --domain filter.
  out="$(nagual knowledge list --domain "$d" --sort reward --limit "$LIMIT" --json --db-path "$DB")"
  if [ "$(printf '%s\n' "$out" | jq 'length')" -eq 0 ]; then
    echo "_(no patterns yet — this run will create the first ones)_"
  else
    while IFS= read -r id; do
      item="$(nagual knowledge get "$id" --json --db-path "$DB")"
      printf '%s\n' "$item" | jq -r '"### \(.problem)\n\n- ID: \(.id)\n- Reward: \(.reward) · Reuse: \(.reuse_count)\n- Solution: \(.solution)\n"'
    done < <(printf '%s\n' "$out" | jq -r '.[].id')
  fi
done
