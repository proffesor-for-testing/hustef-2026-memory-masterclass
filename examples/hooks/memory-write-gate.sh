#!/usr/bin/env bash
# memory-write-gate.sh KEY JSON_VALUE [NAMESPACE]
# The "verify before you write" gate from Block 3, in its smallest honest form:
# an entry is stored as a RESULT only if every path in its `evidence` list exists on disk.
# Otherwise it is stored under claims/<key> — visible, searchable, but never mistaken for a result.
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
KEY="$1"; VALUE="$2"; NS="${3:-aqe}"

command -v jq >/dev/null || { echo "jq is required"; exit 2; }
mapfile -t EVIDENCE < <(printf '%s' "$VALUE" | jq -r '.evidence // [] | .[]')

missing=()
if [ "${#EVIDENCE[@]}" -eq 0 ]; then
  missing+=("<no evidence listed>")
else
  for p in "${EVIDENCE[@]}"; do [ -e "$p" ] || missing+=("$p"); done
fi

if [ "${#missing[@]}" -eq 0 ]; then
  aqe memory store --key "$KEY" --value "$VALUE" --namespace "$NS" 2>/dev/null | grep -E "Stored|error"
  echo "  gate: RESULT  $KEY  (evidence verified: ${#EVIDENCE[@]} artifact(s))"
else
  TAGGED=$(printf '%s' "$VALUE" | jq -c --arg why "${missing[*]}" '. + {gate:"claim", missing_evidence:$why}')
  aqe memory store --key "claims/$KEY" --value "$TAGGED" --namespace "$NS" 2>/dev/null | grep -E "Stored|error"
  echo "  gate: CLAIM   claims/$KEY  (missing: ${missing[*]})"
fi
