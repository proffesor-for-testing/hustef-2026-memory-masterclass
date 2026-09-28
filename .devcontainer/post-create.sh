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
# agentic-qe is pinned: every Block 1 command was verified against this version (override: AQE_VERSION).
AQE_VERSION="${AQE_VERSION:-3.14.4}"
step "Installing Claude Code, Codex CLI and agentic-qe $AQE_VERSION (global npm)"
npm install -g --no-fund --no-audit \
  @anthropic-ai/claude-code \
  @openai/codex \
  "agentic-qe@$AQE_VERSION"

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
# nagual-qe 0.2.0 — merge commit of proffesor-for-testing/nagual-qe#40 (build fix, asymmetric reward rule
# with security failures, trained router, working `nagual serve`, semantic search over all patterns).
# Override with NAGUAL_QE_REF=<branch|tag|sha>.
clone_or_update https://github.com/proffesor-for-testing/nagual-qe.git           "$WS/nagual-qe" "${NAGUAL_QE_REF:-2ddb7faf366b3ebae8154d558961f60db826b373}"

# ── 3. ONNX Runtime + sentence model for semantic search (pinned, checksum-verified) ──
# Nagual embeds patterns with all-MiniLM-L6-v2 (384-d, projected to 128-d) through ONNX Runtime.
# ~8 MB runtime + ~90 MB model; cached in the home directory, so prebuilds download them once.
ORT_VERSION=1.24.1
ORT_HOME="$HOME/.local/lib/onnxruntime"
MODEL_DIR="${NAGUAL_MODEL_DIR:-$HOME/.nagual/models}"
HF_REV=1110a243fdf4706b3f48f1d95db1a4f5529b4d41   # sentence-transformers/all-MiniLM-L6-v2
case "$(uname -m)" in
  aarch64|arm64) ORT_ARCH=aarch64; ORT_SHA=0f56edd68f7602df790b68b874a46b115add037e88385c6c842bb763b39b9f89 ;;
  x86_64)        ORT_ARCH=x64;     ORT_SHA=9142552248b735920f9390027e4512a2cacf8946a1ffcbe9071a5c210531026f ;;
  *) echo "unsupported architecture $(uname -m)"; exit 1 ;;
esac
fetch() {  # url dest sha256
  if [ -f "$2" ] && echo "$3  $2" | sha256sum -c --status; then return 0; fi
  curl -fsSL --retry 3 -o "$2.part" "$1"
  echo "$3  $2.part" | sha256sum -c --status || { echo "  ! checksum mismatch for $1"; rm -f "$2.part"; exit 1; }
  mv "$2.part" "$2"
}
step "ONNX Runtime $ORT_VERSION ($ORT_ARCH) and all-MiniLM-L6-v2 @ ${HF_REV:0:7}"
mkdir -p "$ORT_HOME" "$MODEL_DIR"
if [ ! -f "$ORT_HOME/libonnxruntime.so.$ORT_VERSION" ]; then
  TGZ="$ORT_HOME/onnxruntime-$ORT_VERSION.tgz"
  fetch "https://github.com/microsoft/onnxruntime/releases/download/v$ORT_VERSION/onnxruntime-linux-$ORT_ARCH-$ORT_VERSION.tgz" "$TGZ" "$ORT_SHA"
  tar -xzf "$TGZ" -C "$ORT_HOME" --strip-components=2 "onnxruntime-linux-$ORT_ARCH-$ORT_VERSION/lib"
  rm -f "$TGZ"
fi
ln -sf "libonnxruntime.so.$ORT_VERSION" "$ORT_HOME/libonnxruntime.so"
fetch "https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/$HF_REV/onnx/model.onnx" \
      "$MODEL_DIR/all-MiniLM-L6-v2.onnx" 6fd5d72fe4589f189f8ebc006442dbb529bb7ce38f8082112682524616046452
fetch "https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/$HF_REV/tokenizer.json" \
      "$MODEL_DIR/tokenizer.json" be50c3628f2bf5bb5e3a7f17b1f74611b2561a3a27eeab05e5aa30f411572037
export ORT_DYLIB_PATH="$ORT_HOME/libonnxruntime.so" NAGUAL_MODEL_DIR="$MODEL_DIR"

# ── 4. Nagual: build from source (ONNX embeddings + dashboard) ────────────────────
if [ "${NAGUAL_SKIP_BUILD:-0}" != "1" ]; then
  step "Building nagual (cargo, release, features: kos,onnx-embed,serve) — 5–10 min on first run, cached afterwards"
  ( cd "$WS/nagual-qe" && cargo build --release --features serve )
  # Logs go to stderr since nagual-qe 0.2.0, so the binary is installed as-is (no wrapper needed).
  rm -f "$HOME/.local/bin/nagual-bin"
  install -m 0755 "$WS/nagual-qe/target/release/nagual" "$HOME/.local/bin/nagual"
  step "nagual $(nagual --version 2>/dev/null || echo installed)"
else
  step "NAGUAL_SKIP_BUILD=1 — skipping nagual build"
fi

# ── 5. Iron Pets: dependencies + database (the demo codebase for hands-on #1) ──
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

# ── 6. Fleet memory: init agentic-qe inside Iron Pets and plant the exercise data ──
step "Initialising the Agentic QE fleet inside Iron Pets and seeding fleet memory"
( cd "$WS/iron-pets" && aqe init --auto --minimal --skip-code-index >/dev/null 2>&1 || true )
bash "$ROOT/scripts/seed-fleet-memory.sh"

# ── 7. Nagual: seed the QE pattern set + the masterclass starter patterns ──────
if command -v nagual >/dev/null 2>&1; then
  bash "$ROOT/scripts/seed-nagual.sh"
fi

# ── 8. Projector-friendly shell ───────────────────────────────────────────────
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

# ── 9. Report ──────────────────────────────────────────────────────────────────
bash "$ROOT/.devcontainer/verify.sh" || true
printf '\n\033[1;32mSetup done. Open exercises/00-check-your-setup.md and run: make check\033[0m\n'
