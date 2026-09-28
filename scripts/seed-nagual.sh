#!/usr/bin/env bash
# Seeds Nagual with (a) the public QE seed set shipped in nagual-qe and (b) a handful of masterclass
# starter patterns that the exercises search for. Idempotent: the importer dedups by content hash.
set -euo pipefail
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB="$ROOT/.nagual/nagual.db"
mkdir -p "$ROOT/.nagual"

echo "Seeding Nagual at $DB"

# (a) the curated QE seed — 500+ patterns, PII-scrubbed
if [ -f "$ROOT/workspace/nagual-qe/seeds/qe-seed-v1.jsonl" ]; then
  nagual knowledge import --seed "$ROOT/workspace/nagual-qe/seeds/qe-seed-v1.jsonl" --db-path "$DB" 2>&1 | grep -v '^{' | grep -v "^$" | tail -3 || echo "  ! seed import skipped (see FACILITATOR.md)"
fi

# (b) masterclass starter patterns — the ones hands-on #2 searches for.
# `knowledge store` has no dedup (only `import` does), so guard with a marker to stay idempotent.
MARK="$ROOT/.nagual/.starters-seeded"
if [ -f "$MARK" ]; then echo "  starter patterns already seeded (rm $MARK to force)"; else
store() {  # problem, solution, domain, tags
  nagual knowledge store "$1" --solution "$2" --domain "$3" --tags "$4" --confidence 0.7 --db-path "$DB" 2>&1 | grep "^ID:" | sed "s/^/  stored /"
}
store "Cart total e2e test flakes after evening deploys on ci-runner-2" \
      "Not a test bug: the runner's Redis cache survives the deploy and serves a stale cart total for ~90s. Fix: flush the cart cache in the deploy hook, or make the test wait for the cache-version header to change. Quarantining the test hides the real defect." \
      "qe.flaky" "cart,redis,cache,deploy,e2e"
store "Regression scope for a change in the payment module is unclear" \
      "Start from incident history, not from the diff: the last three payment incidents were all in the refund path. Run refund e2e + partial-refund + currency-rounding suites first; full payment regression only if those change behaviour." \
      "qe.regression" "payment,refund,risk-based,scope"
store "Tests run before 10:00 CET on staging fail with inconsistent data" \
      "The nightly DB restore on staging finishes around 10:00 CET. Anything before that reads a half-restored database. Gate the pipeline on the restore-complete marker file, or schedule staging suites after 10:15." \
      "qe.environment" "staging,restore,timing,flaky"
store "An agent reports a fix as verified but the memory entry has no evidence attached" \
      "Treat it as a claim, not a result. Ask for the artifact: test-run log, diff, or coverage file. In the fleet, entries with an empty evidence list are exactly where completion theater hides — audit those first." \
      "qe.agentic" "completion-theater,evidence,claim-audit,fleet-memory"
store "Same bug filed twice with different wording, months apart" \
      "Search the knowledge base before filing: use the symptom words a colleague would use (what the user sees), not the root-cause words. Link the new report to the existing pattern id so the duplicate cluster becomes visible." \
      "qe.bug-reporting" "duplicate,search,vocabulary"
touch "$MARK"
fi

echo
nagual status --db-path "$DB" 2>/dev/null | grep -E "Total Patterns|Avg Reward" || true
