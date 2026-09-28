#!/usr/bin/env bash
# Runs once, after the container is built. Idempotent — safe to re-run with: bash .devcontainer/post-create.sh
# Escape hatches: NAGUAL_SKIP_BUILD=1 (skip the Rust build), SKIP_IRONPETS_DEPS=1 (skip npm install for Iron Pets)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS="$ROOT/workspace"
mkdir -p "$WS" "$HOME/.local/bin" "$ROOT/.nagual"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

# ── 1. Coding agents + the fleet CLI ──────────────────────────────────────────
step "Installing Claude Code, Codex CLI and agentic-qe (global npm)"
npm install -g --no-fund --no-audit \
  @anthropic-ai/claude-code \
  @openai/codex \
  agentic-qe@latest

# ── 2. The three project repos, pinned to a known-good commit if set ──────────
clone_or_update() {
  local url="$1" dir="$2" ref="${3:-}"
  if [ -d "$dir/.git" ]; then
    step "Updating $(basename "$dir")"; git -C "$dir" fetch -q --depth 1 origin
  else
    step "Cloning $(basename "$dir")"; git clone -q --depth 1 "$url" "$dir"
  fi
  if [ -n "$ref" ]; then git -C "$dir" checkout -q "$ref" || true; fi
}
clone_or_update https://github.com/proffesor-for-testing/agentic-qe.git          "$WS/agentic-qe"
clone_or_update https://github.com/proffesor-for-testing/iron-pets-by-jarvis.git "$WS/iron-pets"
# nagual-qe main does not compile at the moment: dependabot bumped sha3 to 0.12 (#26) and sqlx to 0.9 (#29),
# both with breaking API changes. 54f6932 is the last commit that builds cleanly. Bump the pin once main is fixed.
clone_or_update https://github.com/proffesor-for-testing/nagual-qe.git           "$WS/nagual-qe" 54f6932

# ── 3. Nagual: build from source (hash embedder + dashboard; no ONNX runtime needed) ──
if [ "${NAGUAL_SKIP_BUILD:-0}" != "1" ]; then
  step "Building nagual (cargo, release, features: kos,serve) — 5–10 min on first run, cached afterwards"
  ( cd "$WS/nagual-qe" && cargo build --release --no-default-features --features kos,serve )
  cp "$WS/nagual-qe/target/release/nagual" "$HOME/.local/bin/nagual-bin"
  # The CLI prints its structured JSON log lines on stdout, which is unreadable on a projector.
  # `nagual` is a thin wrapper that strips them; `nagual-bin` is the raw binary.
  cat > "$HOME/.local/bin/nagual" <<'WRAP'
#!/usr/bin/env bash
exec "$HOME/.local/bin/nagual-bin" "$@" 2> >(grep -v "ORT_DYLIB_PATH\|ML features (embeddings)" >&2) | grep --line-buffered -v '^{"timestamp"'
exit "${PIPESTATUS[0]}"
WRAP
  chmod +x "$HOME/.local/bin/nagual"
  step "nagual $(nagual --version 2>/dev/null || echo installed)"
else
  step "NAGUAL_SKIP_BUILD=1 — skipping nagual build"
fi

# ── 4. Iron Pets: dependencies + database (the demo codebase for hands-on #1) ──
if [ "${SKIP_IRONPETS_DEPS:-0}" != "1" ]; then
  step "Installing Iron Pets dependencies (backend + frontend)"
  ( cd "$WS/iron-pets/src/iron-pets/backend"  && npm install --no-fund --no-audit --silent ) || echo "  ! backend npm install failed — see exercises/00-check-your-setup.md"
  ( cd "$WS/iron-pets/src/iron-pets/frontend" && npm install --no-fund --no-audit --silent ) || echo "  ! frontend npm install failed — see exercises/00-check-your-setup.md"
  if [ -f "$WS/iron-pets/src/iron-pets/backend/prisma/schema.prisma" ]; then
    step "Iron Pets: Prisma migrate against the compose Postgres"
    ( cd "$WS/iron-pets/src/iron-pets/backend" \
      && DATABASE_URL="${DATABASE_URL_IRONPETS:-postgresql://ironpets:ironpets@postgres:5432/ironpets}" \
         npx prisma migrate deploy --schema prisma/schema.prisma ) || echo "  ! prisma migrate failed — the memory exercises still work; see FACILITATOR.md"
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

# ── 7. Report ──────────────────────────────────────────────────────────────────
bash "$ROOT/.devcontainer/verify.sh" || true
printf '\n\033[1;32mSetup done. Open exercises/00-check-your-setup.md and run: make check\033[0m\n'
