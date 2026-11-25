#!/usr/bin/env bash
# Deploy Copper Mug to a Gno network under an address namespace.
#
#   ./scripts/deploy.sh <key-name> <g1-address>
#
# Optional environment:
#   CHAIN_ID=onyx-1
#   REMOTE=https://rpc.latest.testnets.gno.land:443
#   GNO_PASSWORD=...   (piped to gnokey instead of prompting)
#   GAS_FEE=5000000ugnot
#   GAS_WANTED=200000000
set -euo pipefail

KEY="${1:?usage: deploy.sh <key-name> <g1-address>}"
ADDR="${2:?usage: deploy.sh <key-name> <g1-address>}"
CHAIN_ID="${CHAIN_ID:-onyx-1}"
REMOTE="${REMOTE:-https://rpc.latest.testnets.gno.land:443}"
GAS_FEE="${GAS_FEE:-5000000ugnot}"
GAS_WANTED="${GAS_WANTED:-200000000}"

case "$ADDR" in
  g1*) ;;
  *) echo "error: address must start with g1" >&2; exit 1 ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG_PATH="${PKG_PATH:-gno.land/r/${ADDR}/coppermug}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Ship source only: tests stay in the repository.
cp "$ROOT"/*.gno "$TMP"/
rm -f "$TMP"/*_test.gno
cat > "$TMP/gnomod.toml" <<EOF
module = "${PKG_PATH}"
gno = "0.9"
EOF

echo "deploying ${PKG_PATH}"
echo "  chain:  ${CHAIN_ID}"
echo "  remote: ${REMOTE}"
echo "  blobs:  $(du -sh "$TMP" | cut -f1)"

run_gnokey() {
  if [ -n "${GNO_PASSWORD:-}" ]; then
    printf '%s\n' "$GNO_PASSWORD" | gnokey "$@"
  else
    gnokey "$@"
  fi
}

run_gnokey maketx addpkg \
  -pkgpath "$PKG_PATH" \
  -pkgdir "$TMP" \
  -gas-fee "$GAS_FEE" \
  -gas-wanted "$GAS_WANTED" \
  -chainid "$CHAIN_ID" \
  -remote "$REMOTE" \
  ${GNO_PASSWORD:+-insecure-password-stdin} \
  "$KEY"

echo
echo "once the package is enabled:"
echo "  https://latest.testnets.gno.land/r/${ADDR}/coppermug"
