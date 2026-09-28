#!/usr/bin/env bash
# Facilitator pre-flight: runs every participant-facing command from exercises/00-03 in order, then
# resets both memory systems. Run it in your own environment the day before (`make smoke`).
# Look for: 3 cart keys (not 0 for "cart*"), the CLAIM gate line, exit=3/exit=1 on the wrapper checks,
# Pattern reward 0.50 -> 0.35 then 0.35 -> 0.45, semantic hits ranked 1st, and HTTP 200s for the dashboard and Iron Pets.
set -uo pipefail
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
cd /workspaces/masterclass
echo "bashrc filter blocks: $(grep -c "init-log filter" ~/.bashrc)"; eval "$(sed -n "/^aqe() {/,/^}/p" ~/.bashrc)"; type aqe | head -1
h(){ printf '\n\033[1;35m######## %s\033[0m\n' "$*"; }
h "00 make reset"; make reset; echo "exit=$?"
h "00 make check"; make check; echo "exit=$?"

h "01 step1 list"; cd workspace/iron-pets; aqe memory list --namespace aqe; echo "exit=$?"
h "01 step2 search *cart*"; aqe memory search --pattern "*cart*" --namespace aqe; echo "exit=$?"
h "01 step2 search cart* (the gotcha)"; aqe memory search --pattern "cart*" --namespace aqe; echo "exit=$?"
h "01 step3 get"; for k in coverage/cart-service test-plan/cart flaky/cart-total-e2e; do aqe memory get --key $k --namespace aqe --include-metadata; echo "exit=$?"; done
h "01 step4 gate"; aqe memory get --key quality-gate/r-0417 --namespace aqe; echo "exit=$?"
h "01 extra store"; aqe memory store --key test-plan/wishlist --namespace aqe --value '{"claim":"wishlist add/remove covered","evidence":["tests/wishlist.spec.ts"],"agent":"you"}'; echo "exit=$?"
cd /workspaces/masterclass

export NAGUAL_DB=$PWD/.nagual/nagual.db
h "02 step0 status"; nagual status --db-path $NAGUAL_DB; echo "exit=$?"
h "02 step0 search flaky"; nagual knowledge search "flaky" --limit 5 --db-path $NAGUAL_DB; echo "exit=$?"
h "02 step0 semantic (want: Cart total ... first, twice)"; nagual knowledge search "flaky cart test" --semantic --limit 3 --db-path $NAGUAL_DB | grep -E "^1\\."; nagual knowledge search "unstable shopping basket test" --semantic --limit 3 --db-path $NAGUAL_DB | grep -E "^1\\."
h "02 step1 store"; OUT=$(nagual knowledge store "Login e2e test fails only on Mondays after the weekend DB snapshot" --solution "Session table is truncated by the Sunday snapshot job; seed a fresh session in the test setup" --domain "qe.flaky" --tags "login,e2e,snapshot" --confidence 0.7 --db-path $NAGUAL_DB); echo "$OUT"; ID=$(printf '%s\n' "$OUT" | sed -n 's/^ID: *//p' | head -1); echo "ID=$ID"
h "02 step2 search back"; nagual knowledge search "login mondays snapshot" --limit 5 --db-path $NAGUAL_DB; echo "exit=$?"
h "02 step2 embed + semantic in other words (want: Login ... first)"; nagual learn embed --db-path $NAGUAL_DB | grep -E "Embedded|already"; nagual knowledge search "sign-in end-to-end check breaks at the start of the week" --semantic --limit 3 --db-path $NAGUAL_DB | grep -E "^1\\."
h "02 get before"; nagual knowledge get $ID --db-path $NAGUAL_DB | grep -iE "reward|tier|effect|confidence"
h "02 step3 failure"; nagual learn record $ID failure --failure-mode verification --feedback "couldn't tell whether the fix took — no log access" --db-path $NAGUAL_DB; echo "exit=$?"
h "02 get after failure"; nagual knowledge get $ID --db-path $NAGUAL_DB | grep -iE "reward|tier|effect"
h "02 security failure on a second pattern"; OUT2=$(nagual knowledge store "Debug endpoint left enabled in staging build" --solution "Guard it with a feature flag" --domain "qe.security" --tags "debug,staging" --db-path $NAGUAL_DB); ID2=$(printf '%s\n' "$OUT2" | sed -n 's/^ID: *//p' | head -1); nagual learn record $ID2 failure --failure-mode security --feedback "exposed tokens" --db-path $NAGUAL_DB | grep "Pattern reward"
h "02 step3 success"; nagual learn record $ID success --feedback "worked on CI too" --db-path $NAGUAL_DB; echo "exit=$?"
h "02 get after success"; nagual knowledge get $ID --db-path $NAGUAL_DB | grep -iE "reward|tier|effect"
h "02 step4 insights"; nagual learn insights --windows 7d --db-path $NAGUAL_DB; echo "exit=$?"
h "stdout cleanliness: any JSON log lines on stdout?"; nagual knowledge search "flaky" --limit 2 --db-path $NAGUAL_DB 2>/dev/null | grep -c '^{"timestamp"'

h "03 piece1 write gate"; cd workspace/iron-pets; bash ../../examples/hooks/memory-write-gate.sh test-plan/cart '{"claim":"cart-total fix verified","evidence":[],"agent":"qe-test-architect"}'; echo "exit=$?"
aqe memory get --key claims/test-plan/cart --namespace aqe; cd /workspaces/masterclass
h "03 piece2 wrapper, no pattern in play: must still run + keep exit code"; rm -f .nagual/current-pattern; bash examples/hooks/record-outcome.sh -- bash -c 'echo "ran: npm test"; exit 3'; echo "exit=$? (want 3)"
h "03 piece2 record-outcome (wrapper mode)"; mkdir -p .nagual; echo $ID > .nagual/current-pattern; bash examples/hooks/record-outcome.sh -- bash -c 'echo "npm test"; exit 1'; echo "exit=$? (want 1)"
h "03 piece2 record-outcome (hook mode, PostToolUse JSON)"; printf '{"tool_input":{"command":"cargo test"},"tool_response":{"exit_code":0}}' | bash examples/hooks/record-outcome.sh; echo "exit=$?"
nagual knowledge get $ID --db-path $NAGUAL_DB | grep -iE "reward|usage|reuse"
rm -f .nagual/current-pattern
h "03 piece3 preload"; mkdir -p workspace/iron-pets/.agentic-qe; bash examples/hooks/preload-patterns.sh qe.flaky qe.regression qe.nonexistent; echo "exit=$?"

h "dashboard"; for i in $(seq 1 20); do curl -s -o /dev/null http://localhost:3333/ && break; sleep 0.5; done
curl -s -o /dev/null -w "GET / -> %{http_code}\n" http://localhost:3333/
curl -s -w "\n-> %{http_code}\n" http://localhost:3333/api/status | cut -c1-300
curl -s -w "\n-> %{http_code}\n" "http://localhost:3333/api/patterns?limit=1" | cut -c1-300
curl -s -o /dev/null -w "GET /api/graph/3d?limit=50 -> %{http_code}\n" "http://localhost:3333/api/graph/3d?limit=50"
h "search flakes cart"; nagual knowledge search "flakes cart" --limit 3 --db-path $NAGUAL_DB
h "make ironpets"; make ironpets; for i in $(seq 1 60); do curl -s -o /dev/null http://localhost:3001/ && break; sleep 1; done
curl -s -o /dev/null -w "backend :3001/health -> %{http_code}\n" http://localhost:3001/health
for i in $(seq 1 60); do curl -s -o /dev/null http://localhost:3000/ && break; sleep 1; done
curl -s -o /dev/null -w "frontend :3000 -> %{http_code}\n" http://localhost:3000/
tmux kill-session -t ironpets 2>/dev/null; true

h "cleanup"; cd /workspaces/masterclass; make reset >/dev/null 2>&1 && echo "memory systems reset to the seeded state"
