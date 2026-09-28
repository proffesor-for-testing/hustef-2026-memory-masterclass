#!/usr/bin/env bash
# Seeds the Agentic QE fleet memory inside Iron Pets with what "a fleet that just ran" would leave behind —
# including ONE planted bare claim (no evidence). Finding it is hands-on #1.
# Every command here was executed against agentic-qe 3.14.x — syntax is real, not illustrative.
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/workspace/iron-pets"

NS=aqe
put() { aqe memory store --key "$1" --value "$2" --namespace "$NS" 2>/dev/null | grep -E "Stored|error" || true; }

echo "Seeding fleet memory (namespace: $NS) in $(pwd)"

put coverage/cart-service      '{"claim":"cart.service.ts 91% line coverage","evidence":["artifacts/coverage-cart-2026-10-06.json"],"agent":"qe-coverage-specialist","run":"r-0417"}'
put coverage/checkout-service  '{"claim":"checkout.service.ts 84% line coverage","evidence":["artifacts/coverage-checkout-2026-10-06.json"],"agent":"qe-coverage-specialist","run":"r-0417"}'
put test-plan/checkout         '{"claim":"checkout happy path + 3 error states covered","evidence":["artifacts/test-run-2026-10-06T09-14.log","tests/checkout.e2e.spec.ts"],"agent":"qe-test-architect","run":"r-0417"}'
put test-plan/cart             '{"claim":"cart-total fix verified — total updates on quantity change","evidence":[],"agent":"qe-test-architect","run":"r-0417"}'
put flaky/cart-total-e2e       '{"claim":"cart total e2e flaked 3/20 on ci-runner-2, all after 17:00 CET deploys","evidence":["artifacts/flake-history-cart.json"],"agent":"qe-flaky-hunter","run":"r-0417"}'
put risk/payment-module        '{"claim":"payment module: 3 incidents in 90 days, all in refund path","evidence":["artifacts/incidents-payment-q3.json"],"agent":"qe-regression-analyzer","run":"r-0417"}'
put env/staging-window         '{"claim":"staging DB restore runs 09:30–10:00 CET; tests before 10:00 hit a half-restored DB","evidence":["artifacts/staging-restore-cron.txt"],"agent":"qe-fleet-commander","run":"r-0417"}'
put quality-gate/r-0417        '{"claim":"gate PASSED","evidence":["artifacts/gate-r-0417.json"],"agent":"qe-quality-gate","run":"r-0417","note":"gate consumed test-plan/cart as verified"}'

echo
aqe memory list --namespace "$NS" 2>/dev/null | grep -vE "^\[|^$|Auto-init|System ready" || true
