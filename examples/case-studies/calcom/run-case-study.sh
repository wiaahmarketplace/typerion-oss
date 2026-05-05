#!/usr/bin/env bash
#
# Reproducible Cal.com case study : fetch schema, parse to IR, verify.
#
# Usage :
#   ./run-case-study.sh
#
# Output :
#   1. fetches Cal.com schema.prisma at a pinned commit SHA
#   2. parses it via the hacky Cal.com-targeted parser
#   3. posts the resulting IR to the Typerion verify endpoint
#   4. prints the kernel verdict
#
# Anyone with python3 + curl + jq can run this end-to-end and
# reproduce the findings.

set -uo pipefail

# Pin to a specific commit so results are deterministic across time.
# Update this only when re-running the case study against a fresh
# Cal.com state.
CAL_COM_SHA="a4a01a0"
CAL_COM_SCHEMA_URL="https://raw.githubusercontent.com/calcom/cal.com/${CAL_COM_SHA}/packages/prisma/schema.prisma"

API="${TYPERION_API:-https://typerion-v1-typerion-server-r3wh.vercel.app}"
PAT="${TYPERION_PAT:-pat_typerion_preview_demo_2026_05}"
HERE="$(cd "$(dirname "$0")" && pwd)"

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "missing dep : $1" >&2; exit 1; }
}
require python3
require curl
require jq

echo "── Cal.com schema fetch ──────────────────────────────"
echo "Pinned SHA : $CAL_COM_SHA"
SCHEMA_TMP=$(mktemp -t calcom-schema.XXXXXX)
curl -fsSL "$CAL_COM_SCHEMA_URL" -o "$SCHEMA_TMP"
echo "Bytes : $(wc -c < "$SCHEMA_TMP" | tr -d ' ')"
echo "Lines : $(wc -l < "$SCHEMA_TMP" | tr -d ' ')"
echo "Models : $(grep -c '^model ' "$SCHEMA_TMP")"
echo "Enums  : $(grep -c '^enum '  "$SCHEMA_TMP")"

echo
echo "── Parse to SimpleIR ─────────────────────────────────"
IR_TMP=$(mktemp -t calcom-ir.XXXXXX.json)
python3 "$HERE/parse-prisma.py" "$SCHEMA_TMP" > "$IR_TMP"

echo
echo "── Submit to Typerion verify ─────────────────────────"
RESPONSE=$(curl -fsS --max-time 30 -X POST "$API/v1/verify" \
  -H "Authorization: Bearer $PAT" \
  -H "Content-Type: application/json" \
  -d @"$IR_TMP")

echo "Verdict :"
echo "$RESPONSE" | jq '{
  status,
  reasonsCount: (.reasons | length),
  fingerprint
}'

REASONS_COUNT=$(echo "$RESPONSE" | jq '.reasons | length')
if [ "$REASONS_COUNT" -gt 0 ]; then
  echo
  echo "Reasons :"
  echo "$RESPONSE" | jq -r '.reasons[] | "  - " + .'
fi

echo
echo "── Done ──────────────────────────────────────────────"
echo "  Schema : $SCHEMA_TMP (delete or keep for inspection)"
echo "  IR     : $IR_TMP (delete or keep for inspection)"
echo "  See README.md in this directory for the analysis writeup."
