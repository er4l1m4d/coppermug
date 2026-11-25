#!/usr/bin/env bash
# Fill a local gnodev with a believable evening at the Copper Mug.
#
# Prerequisites:
#   - running `gnodev .` (or gnodev with this package loaded)
#   - keys named mira, bram and sable in the local keybase, auto-funded by gnodev
#
# Optional:
#   GNO_PASSWORD=...   piped to gnokey instead of prompting
#   PKG=gno.land/r/coppermug/v0
set -uo pipefail

PKG="${PKG:-gno.land/r/coppermug/v0}"
REMOTE="${REMOTE:-http://localhost:26657}"
CHAIN_ID="${CHAIN_ID:-dev}"

run_gnokey() {
  if [ -n "${GNO_PASSWORD:-}" ]; then
    printf '%s\n' "$GNO_PASSWORD" | gnokey "$@"
  else
    gnokey "$@"
  fi
}

tx() {
  local key=$1 fn=$2
  shift 2
  local args=()
  for a in "$@"; do args+=(-args "$a"); done

  local extra=()
  [ -n "${GNO_PASSWORD:-}" ] && extra=(-insecure-password-stdin)

  local out
  out=$(run_gnokey maketx call \
    -pkgpath "$PKG" -func "$fn" "${args[@]}" \
    -gas-fee 3000000ugnot -gas-wanted 10000000 \
    -chainid "$CHAIN_ID" -remote "$REMOTE" "${extra[@]}" "$key" 2>&1)

  if echo "$out" | grep -q "OK!"; then
    echo "  $fn $key: ok"
  else
    echo "  $fn $key: $(echo "$out" | grep -m1 -E 'panic|Error|error' || echo failed)"
  fi
}

echo "seeding $PKG on $REMOTE"

tx mira  Join "Mira" "mage"
tx bram  Join "Bram" "fighter"
tx sable Join "Sable" "rogue"

tx mira  Say "First round is on the house. Pull up a stool."
tx bram  Say "I hear the cellar door only opens at midnight."
tx sable Say "Then we have three hours to lose our gold."

tx bram  Tip "Mira" "15"
tx mira  Tip "Bram" "20"
tx sable BuyRound

tx mira  Say "Who is brave enough for the Cup?"

tx mira  OpenCup "40" && tx mira Roll  && tx mira Hold  || true
tx bram  OpenCup "20" && tx bram Roll  && tx bram Hold  || true

tx sable OpenCup "30" && tx sable Roll && tx sable Roll && tx sable Roll && tx sable Hold || true
tx sable OpenCup "30" && tx sable Roll && tx sable Roll && tx sable Hold || true

echo "done"
