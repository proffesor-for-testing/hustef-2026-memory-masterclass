#!/usr/bin/env bash
# Seeds the Agentic QE fleet memory inside Iron Pets with what "a fleet that just ran" would leave behind —
# including ONE planted bare claim (no evidence). Finding it is hands-on #1.
# Every command here was executed against agentic-qe 3.14.7 — syntax is real, not illustrative.
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/workspace/iron-pets"

# These are simulated run r-0417 receipts for the exercise. Keep every nonempty
# evidence path inspectable so the empty cart-plan entry is the one bare claim.
mkdir -p artifacts
cat > artifacts/coverage-cart-2026-10-06.json <<'EOF'
{"exercise_fixture":true,"run":"r-0417","module":"cart.service.ts","line_coverage_percent":91}
EOF
cat > artifacts/coverage-checkout-2026-10-06.json <<'EOF'
{"exercise_fixture":true,"run":"r-0417","module":"checkout.service.ts","line_coverage_percent":84}
EOF
cat > artifacts/test-run-2026-10-06T09-14.log <<'EOF'
EXERCISE FIXTURE — simulated run r-0417
checkout happy path: PASS
checkout error states: 3 PASS
EOF
cat > artifacts/flake-history-cart.json <<'EOF'
{"exercise_fixture":true,"run":"r-0417","test":"cart-total-e2e","failures":3,"runs":20,"runner":"ci-runner-2","pattern":"after 17:00 CET deploys"}
EOF
cat > artifacts/incidents-payment-q3.json <<'EOF'
{"exercise_fixture":true,"run":"r-0417","module":"payment","incidents_last_90_days":3,"shared_path":"refund"}
EOF
cat > artifacts/staging-restore-cron.txt <<'EOF'
EXERCISE FIXTURE — simulated staging restore window: 09:30–10:00 CET.
EOF
cat > artifacts/gate-r-0417.json <<'EOF'
{"exercise_fixture":true,"run":"r-0417","verdict":"PASSED","consumed_as_verified":["test-plan/cart"]}
EOF

NS=aqe
put() {
  local result
  result="$(aqe memory store --key "$1" --value "$2" --namespace "$NS" 2>/dev/null)" \
    || { echo "Failed to seed $1" >&2; return 1; }
  printf '%s\n' "$result" | grep 'Stored' || true
}

echo "Seeding fleet memory (namespace: $NS) in $(pwd)"

put coverage/cart-service      '{"claim":"cart.service.ts 91% line coverage","evidence":["artifacts/coverage-cart-2026-10-06.json"],"agent":"qe-coverage-specialist","run":"r-0417"}'
put coverage/checkout-service  '{"claim":"checkout.service.ts 84% line coverage","evidence":["artifacts/coverage-checkout-2026-10-06.json"],"agent":"qe-coverage-specialist","run":"r-0417"}'
put test-plan/checkout         '{"claim":"checkout happy path + 3 error states covered","evidence":["artifacts/test-run-2026-10-06T09-14.log","src/iron-pets/backend/tests/checkout.test.ts"],"agent":"qe-test-architect","run":"r-0417"}'
put test-plan/cart             '{"claim":"cart-total fix verified — total updates on quantity change","evidence":[],"agent":"qe-test-architect","run":"r-0417"}'
put flaky/cart-total-e2e       '{"claim":"cart total e2e flaked 3/20 on ci-runner-2, all after 17:00 CET deploys","evidence":["artifacts/flake-history-cart.json"],"agent":"qe-flaky-hunter","run":"r-0417"}'
put risk/payment-module        '{"claim":"payment module: 3 incidents in 90 days, all in refund path","evidence":["artifacts/incidents-payment-q3.json"],"agent":"qe-regression-analyzer","run":"r-0417"}'
put env/staging-window         '{"claim":"staging DB restore runs 09:30–10:00 CET; tests before 10:00 hit a half-restored DB","evidence":["artifacts/staging-restore-cron.txt"],"agent":"qe-fleet-commander","run":"r-0417"}'
put quality-gate/r-0417        '{"claim":"gate PASSED","evidence":["artifacts/gate-r-0417.json"],"agent":"qe-quality-gate","run":"r-0417","note":"gate consumed test-plan/cart as verified"}'

echo
aqe memory list --namespace "$NS" 2>/dev/null | grep -vE "^\[|^$|Auto-init|System ready" || true
