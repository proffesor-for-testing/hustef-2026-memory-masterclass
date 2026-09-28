#!/usr/bin/env bash
# Runs once, after the container is built. Idempotent — safe to re-run with: bash .devcontainer/post-create.sh
# Escape hatches: NAGUAL_SKIP_BUILD=1 (skip the Rust build), SKIP_IRONPETS_DEPS=1 (skip npm install for Iron Pets)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS="$ROOT/workspace"
mkdir -p "$WS" "$HOME/.local/bin" "$ROOT/.nagual"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

# Named volumes (cargo registry cache, nagual build dir) are created root-owned on first boot.
sudo -n mkdir -p /usr/local/cargo/registry "$WS/nagual-qe/target" 2>/dev/null || true
sudo -n chown node:node /usr/local/cargo/registry "$WS/nagual-qe/target" 2>/dev/null || true

# ── 1. Coding agents + the fleet CLI ──────────────────────────────────────────
step "Installing Claude Code, Codex CLI and agentic-qe (global npm)"
npm install -g --no-fund --no-audit \
  @anthropic-ai/claude-code \
  @openai/codex \
  agentic-qe@latest

# ── 2. The three project repos, optionally pinned to a known-good ref ─────────
# A ref can be a branch, tag or full commit SHA. It is fetched explicitly: a shallow clone only
# contains the tip of the default branch, so a plain `git checkout <sha>` would fail.
clone_or_update() {
  local url="$1" dir="$2" ref="${3:-HEAD}"
  # init-in-place rather than `git clone`: docker-compose mounts a cargo target volume at
  # workspace/nagual-qe/target, so that directory already exists (non-empty) on first boot.
  if [ ! -d "$dir/.git" ]; then
    step "Cloning $(basename "$dir")"
    mkdir -p "$dir"; git -C "$dir" init -q; git -C "$dir" remote add origin "$url"
  else
    step "Updating $(basename "$dir")"
  fi
  git -C "$dir" fetch -q --depth 1 origin "$ref"
  git -C "$dir" checkout -q -f --detach FETCH_HEAD
  printf '    %s @ %s\n' "$(basename "$dir")" "$(git -C "$dir" log -1 --format='%h %s')"
}
clone_or_update https://github.com/proffesor-for-testing/agentic-qe.git          "$WS/agentic-qe"
clone_or_update https://github.com/proffesor-for-testing/iron-pets-by-jarvis.git "$WS/iron-pets"
# nagual-qe 0.2.0 (head of proffesor-for-testing/nagual-qe PR #40): builds again after the dependabot
# sha3/sqlx/axum bumps, `nagual serve` starts and serves the dashboard on a fresh DB, `knowledge list`
# pagination fixed, logs on stderr, PII redaction on the HTTP read path.
# Repin to the merge commit once the PR is merged. Override with NAGUAL_QE_REF=<branch|tag|sha>.
clone_or_update https://github.com/proffesor-for-testing/nagual-qe.git           "$WS/nagual-qe" "${NAGUAL_QE_REF:-9bc6b5042b990e3f4146def56ad35a79a9a968d9}"

# ── 3. Nagual: build from source (hash embedder + dashboard; no ONNX runtime needed) ──
if [ "${NAGUAL_SKIP_BUILD:-0}" != "1" ]; then
  step "Building nagual (cargo, release, features: kos,serve) — 5–10 min on first run, cached afterwards"
  ( cd "$WS/nagual-qe" && cargo build --release --no-default-features --features kos,serve )
  # Logs go to stderr since nagual-qe 0.2.0, so the binary is installed as-is (no wrapper needed).
  rm -f "$HOME/.local/bin/nagual-bin"
  install -m 0755 "$WS/nagual-qe/target/release/nagual" "$HOME/.local/bin/nagual"
  step "nagual $(nagual --version 2>/dev/null || echo installed)"
else
  step "NAGUAL_SKIP_BUILD=1 — skipping nagual build"
fi

# ── 4. Iron Pets: dependencies + database (the demo codebase for hands-on #1) ──
if [ "${SKIP_IRONPETS_DEPS:-0}" != "1" ]; then
  step "Installing Iron Pets dependencies (backend + frontend)"
  ( cd "$WS/iron-pets/src/iron-pets/backend"  && npm install --no-fund --no-audit --silent ) || echo "  ! backend npm install failed — see exercises/00-check-your-setup.md"
  # --legacy-peer-deps: eslint-config-next 16 declares a peer range that npm 10 rejects against eslint 10.
  ( cd "$WS/iron-pets/src/iron-pets/frontend" && npm install --no-fund --no-audit --silent --legacy-peer-deps ) || echo "  ! frontend npm install failed — see exercises/00-check-your-setup.md"
  if [ -f "$WS/iron-pets/src/iron-pets/backend/prisma/schema.prisma" ]; then
    # Iron Pets ships a schema and a seed script but no migrations, so `db push` (not `migrate deploy`).
    step "Iron Pets: create schema + demo data in the compose Postgres"
    ( cd "$WS/iron-pets/src/iron-pets/backend" \
      && export DATABASE_URL="${DATABASE_URL_IRONPETS:-postgresql://ironpets:ironpets@postgres:5432/ironpets}" \
      && npx prisma db push >/dev/null \
      && { SEED_OUT="$(npx prisma db seed 2>&1)" \
           || { printf '%s' "$SEED_OUT" | grep -q "Unique constraint" && echo "    demo data already present"; }; } ) \
      || echo "  ! Iron Pets database setup failed — the memory exercises still work; see FACILITATOR.md"
  fi
fi

# ── 5. Fleet memory: init agentic-qe inside Iron Pets and plant the exercise data ──
step "Initialising the Agentic QE fleet inside Iron Pets and seeding fleet memory"
( cd "$WS/iron-pets" && aqe init --auto --minimal --skip-code-index >/dev/null 2>&1 || true )
bash "$ROOT/scripts/seed-fleet-memory.sh"

# ── 6. Nagual: seed the QE pattern set + the masterclass starter patterns ──────
if command -v nagual >/dev/null 2>&1; then
  bash "$ROOT/scripts/seed-nagual.sh"
fi

# ── 7. Projector-friendly shell ───────────────────────────────────────────────
# agentic-qe prints ~90 lines of init logs (stderr) before every `aqe` command, and LOG_LEVEL does not
# change that. In interactive shells, drop the known init chatter; anything with ERROR/WARN still shows.
if ! grep -q "masterclass: aqe init-log filter" "$HOME/.bashrc" 2>/dev/null; then
  cat >> "$HOME/.bashrc" <<'RC'
# masterclass: aqe init-log filter (raw output: `command aqe ...`)
aqe() {
  command aqe "$@" 2> >(grep --line-buffered -vE '^\[[0-9:.]+\] \[(INFO|DEBUG) *\]|^\[[A-Za-z]+\] (Initialized|Removed stale|MinCut bridge)|^\[PersistentSONAEngine\]|^\[QueenGovernance\]|No model providers available for consensus|^Auto-initializing|^System ready' >&2)
}
RC
fi

# ── 8. Report ──────────────────────────────────────────────────────────────────
bash "$ROOT/.devcontainer/verify.sh" || true
printf '\n\033[1;32mSetup done. Open exercises/00-check-your-setup.md and run: make check\033[0m\n'
