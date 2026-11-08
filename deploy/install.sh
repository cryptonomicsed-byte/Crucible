#!/usr/bin/env bash
# P1-17: build the crucible-cli release, generate the resolver key ON this
# VPS, and install the socket-activated MCP service. Idempotent.
#
#   sudo bash deploy/install.sh
#
# The resolver key is the community oracle: Policy::oracle_authorities must
# name its pubkey (see README). Its secret never leaves this host -- the key
# is generated here and written 0600.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF_DIR="/etc/ares/crucible"
KEY_FILE="$CONF_DIR/resolver.json"
SERVICE_USER="ares"

command -v cargo >/dev/null 2>&1 || { echo "cargo not found" >&2; exit 1; }
command -v node  >/dev/null 2>&1 || { echo "node not found" >&2; exit 1; }

echo "== build release =="
cargo build --release -p crucible-cli
BIN="$HERE/target/release/crucible"
[ -x "$BIN" ] || { echo "release binary missing: $BIN" >&2; exit 1; }

echo "== resolver key (generated here, never leaves) =="
install -d -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0700 "$CONF_DIR"
if [ -s "$KEY_FILE" ]; then
  echo "resolver key already present at $KEY_FILE (leaving it in place)"
else
  # keygen.live draws from the OS CSPRNG; it is the real key, not the demo one.
  echo '{}' | "$BIN" keygen.live > "$KEY_FILE.tmp"
  chown "$SERVICE_USER:$SERVICE_USER" "$KEY_FILE.tmp"
  chmod 0600 "$KEY_FILE.tmp"
  mv "$KEY_FILE.tmp" "$KEY_FILE"
fi

echo "== resolver pubkey (wire into policy.oracle_authorities) =="
node -e 'const k=require(process.argv[1]); console.log(k.pubkey)' "$KEY_FILE"

echo "== install systemd socket + service =="
install -m 0644 "$HERE/deploy/ares-crucible.socket" /etc/systemd/system/
install -m 0644 "$HERE/deploy/ares-crucible.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now ares-crucible.socket
echo "done. Connect over the unix socket /run/ares-crucible.sock (stdio MCP)."
