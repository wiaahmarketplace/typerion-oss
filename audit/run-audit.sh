#!/usr/bin/env bash
#
# typerion preview audit — re-run the kernel against every fixture in
# audit/fixtures/ and assert outputs match audit/expected-outputs.json.
#
# Determinism claim verified by this script :
#   given identical inputs and a versioned kernel execution
#   (VERIFY_VERSION = v15.5-austere-1), the kernel produces the same
#   {status, reasons, fingerprint} on every run, on every machine.
#
# It does NOT claim determinism across kernel versions, across
# different inputs, or under network failure. Those are out of scope.
#
# Usage :
#   ./audit/run-audit.sh                                    # against hosted preview
#   TYPERION_API=http://localhost:4101 ./audit/run-audit.sh # against local server
#

set -uo pipefail

API="${TYPERION_API:-https://typerion-v1-typerion-server-r3wh.vercel.app}"
PAT="${TYPERION_PAT:-pat_typerion_preview_demo_2026_05}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT_DIR="$ROOT/audit"
EXPECTED="$AUDIT_DIR/expected-outputs.json"

PASS=0
FAIL=0
FIXTURES_RUN=0

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "missing dep : $1" >&2; exit 1; }
}
require curl
require jq

if [ ! -f "$EXPECTED" ]; then
  echo "error : expected-outputs.json not found at $EXPECTED" >&2
  exit 1
fi

ok()   { echo "  ✓ $*"; PASS=$((PASS + 1)); }
ko()   { echo "  ✗ $*"; FAIL=$((FAIL + 1)); }

echo "Typerion preview audit"
echo "──────────────────────"
echo "API      : $API"
echo "Kernel   : $(jq -r '.kernelVersion' "$EXPECTED")"
echo "Fixtures : $(ls "$AUDIT_DIR"/fixtures/case-*.json 2>/dev/null | wc -l | tr -d ' ')"
echo ""

for fixture in "$AUDIT_DIR"/fixtures/case-*.json; do
  name=$(basename "$fixture" .json)
  FIXTURES_RUN=$((FIXTURES_RUN + 1))
  echo "── $name ──"

  expected=$(jq --arg n "$name" '.fixtures[$n]' "$EXPECTED")
  if [ "$expected" = "null" ]; then
    ko "no expected output pinned in expected-outputs.json — add an entry"
    continue
  fi

  expected_status=$(echo "$expected" | jq -r '.status')
  expected_count=$(echo "$expected" | jq -r '.reasonsCount')
  expected_fp=$(echo "$expected" | jq -r '.fingerprint')

  body=$(jq '{baseline: .baseline, candidate: .candidate}' "$fixture")
  resp=$(curl -fsS --max-time 10 -X POST "$API/v1/verify" \
    -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    -d "$body" 2>&1)
  if [ $? -ne 0 ]; then
    ko "POST /v1/verify failed network-side : $resp"
    continue
  fi

  actual_status=$(echo "$resp" | jq -r '.status')
  actual_count=$(echo "$resp" | jq -r '.reasons | length')
  actual_fp=$(echo "$resp" | jq -r '.fingerprint')

  # Status check
  if [ "$actual_status" = "$expected_status" ]; then
    ok "status = $actual_status"
  else
    ko "status mismatch : expected '$expected_status', got '$actual_status'"
  fi

  # Reasons count
  if [ "$actual_count" = "$expected_count" ]; then
    ok "reasons count = $actual_count"
  else
    ko "reasons count mismatch : expected $expected_count, got $actual_count"
  fi

  # Reasons substring assertions
  reason_count=$(echo "$expected" | jq '.reasonSubstrings | length')
  for ((i=0; i<reason_count; i++)); do
    needle=$(echo "$expected" | jq -r ".reasonSubstrings[$i]")
    if echo "$resp" | jq -r '.reasons[]' | grep -F -- "$needle" > /dev/null; then
      ok "reason contains : \"$needle\""
    else
      ko "reason missing : expected a reason containing \"$needle\""
    fi
  done

  # Fingerprint exact match — the determinism claim
  if [ "$actual_fp" = "$expected_fp" ]; then
    ok "fingerprint = $actual_fp (determinism preserved)"
  else
    ko "fingerprint drift : expected $expected_fp, got $actual_fp"
  fi

  echo ""
done

echo "──────────────────────"
echo "Audit results : $PASS pass / $FAIL fail across $FIXTURES_RUN fixtures"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo "✓ Every fixture matches its pinned ground truth."
  echo "  Determinism claim verified : kernel VERIFY_VERSION = $(jq -r '.kernelVersion' "$EXPECTED")"
  echo "  produces identical {status, reasons, fingerprint} on this run as on the"
  echo "  reference run captured at $(jq -r '.capturedAt' "$EXPECTED")."
  exit 0
else
  echo "✗ Audit failed. Either the kernel logic has drifted, the endpoint is"
  echo "  serving a different version, or the fixtures have been edited without"
  echo "  re-pinning. Investigate the specific failures above."
  exit 1
fi
