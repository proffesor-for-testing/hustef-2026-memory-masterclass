#!/usr/bin/env bash
# Optional facilitator setup. Ruflo is not needed for either participant exercise.
set -euo pipefail

RUFLO_VERSION=3.51.1
PROXY_RELEASE=0.7.5
MANIFEST="$HOME/.ruflo/proxy/install-manifest.json"
BINARY="$HOME/.ruflo/bin/meta-proxy"

if ! command -v ruflo >/dev/null 2>&1 || [ "$(ruflo --version)" != "ruflo v$RUFLO_VERSION" ]; then
  npm install -g --no-fund --no-audit "ruflo@$RUFLO_VERSION"
fi

installed_version() {
  node -e 'try { console.log(require(process.argv[1]).version) } catch { process.exit(1) }' "$MANIFEST"
}

if [ "$(installed_version 2>/dev/null || true)" != "$PROXY_RELEASE" ]; then
  # Ruflo 3.51.1 may report an activation error after verifying and placing
  # Meta-Proxy: its /version probe returns 404 on the 0.7.5 binary.
  ruflo proxy install --release "$PROXY_RELEASE" --yes || true
fi

node - "$MANIFEST" "$BINARY" "$PROXY_RELEASE" <<'JS'
const fs = require('node:fs');
const crypto = require('node:crypto');
const [manifestPath, binaryPath, expectedVersion] = process.argv.slice(2);
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const hash = crypto.createHash('sha256').update(fs.readFileSync(binaryPath)).digest('hex');
if (manifest.version !== expectedVersion || manifest.sha256 !== hash || !manifest.verifiedAt || !manifest.pubkeyFingerprint) {
  console.error('Meta-Proxy binary does not match its verified install manifest.');
  process.exit(1);
}
console.log(`Verified Meta-Proxy ${manifest.version} artifact and install manifest.`);
JS

proxy_healthy() {
  node - "$PROXY_RELEASE" <<'JS'
const fs = require('node:fs');
const expected = process.argv[2];
const token = fs.readFileSync(`${process.env.HOME}/.ruflo/proxy-token`, 'utf8').trim();
fetch('http://127.0.0.1:11435/status', {
  headers: { Authorization: `Bearer ${token}` },
  signal: AbortSignal.timeout(2000),
}).then(async response => {
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  const status = await response.json();
  if (status.version !== expected || status.proxy_token_valid !== true || status.bind !== '127.0.0.1:11435') {
    throw new Error('unexpected version, token status, or bind address');
  }
  console.log(`Meta-Proxy ${status.version} ready on ${status.bind} (${status.data_plane}).`);
}).catch(error => { console.error(`Meta-Proxy health check: ${error.message}`); process.exitCode = 1; });
JS
}

if ! proxy_healthy; then
  # Also clears a stale PID left by Ruflo's failed activation check.
  ruflo proxy stop >/dev/null 2>&1 || true
  ruflo proxy start --service
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if proxy_healthy; then exit 0; fi
    sleep 1
  done
  echo 'Meta-Proxy did not pass its authenticated health check.' >&2
  exit 1
fi
