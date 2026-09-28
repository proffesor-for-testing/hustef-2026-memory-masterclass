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
  # NOTE: nagual applies --limit BEFORE the --domain filter (src/cli/knowledge.rs, run_list), so a small limit
  # returns nothing. Ask for everything, then cut the table here.
  nagual knowledge list --domain "$d" --sort reward --limit 5000 --db-path "$DB" 2>/dev/null \
    | awk -v n="$LIMIT" '/^[0-9a-f]{8}-/{c++; if(c>n) next} {print}' \
    || echo "_(no patterns yet — this run will create the first ones)_"
done
