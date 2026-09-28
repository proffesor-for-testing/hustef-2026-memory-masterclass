#!/usr/bin/env bash
# record-outcome.sh — close the loop automatically at a tool boundary.
#
# Claude Code: registered as a PostToolUse hook for Bash (see claude-settings.example.json). Claude Code
# passes the tool call as JSON on stdin; we look at the command and its exit code.
# Codex CLI: wrap your test command instead:  bash examples/hooks/record-outcome.sh -- npm test
#
# Which pattern is "in play" is read from .nagual/current-pattern (one id per line; last one wins).
# Set it when you start applying a pattern:  echo <id> > .nagual/current-pattern
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
DB="${NAGUAL_DB:-$ROOT/.nagual/nagual.db}"
PID_FILE="$ROOT/.nagual/current-pattern"

[ -s "$PID_FILE" ] || exit 0          # nothing in play → nothing to record
PATTERN_ID="$(tail -n1 "$PID_FILE")"

if [ "${1:-}" = "--" ]; then          # wrapper mode: run the command ourselves
  shift; "$@"; CODE=$?; CMD="$*"
else                                  # hook mode: read Claude Code's PostToolUse payload
  PAYLOAD="$(cat)"
  CMD="$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // empty')"
  CODE="$(printf '%s' "$PAYLOAD" | jq -r '.tool_response.exit_code // .tool_response.exitCode // 0')"
fi

# only test-ish commands count as outcomes; everything else is noise
case "$CMD" in
  *"npm test"*|*"npx jest"*|*"npx playwright"*|*"cargo test"*|*"pytest"*|*"aqe test"*) ;;
  *) exit 0 ;;
esac

if [ "$CODE" = "0" ]; then
  nagual learn record "$PATTERN_ID" success --feedback "auto: '$CMD' exit 0" --db-path "$DB" >/dev/null 2>&1
else
  # The failure mode is a guess here — 'verification' means "we could not confirm it worked".
  # A human should reclassify it: nagual learn record <id> failure --failure-mode <mast>
  nagual learn record "$PATTERN_ID" failure --failure-mode verification \
    --feedback "auto: '$CMD' exit $CODE — reclassify me" --db-path "$DB" >/dev/null 2>&1
fi
exit 0
