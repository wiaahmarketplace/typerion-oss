#!/usr/bin/env bash
#
# Typerion demo — Intent → Generated → Broken → Caught
#
# A 4-step narrative showing the control plane in action :
#
#   1. Write intent       → 01-intent.json
#   2. Generate system    → 02-generated.json (matches intent → pass)
#   3. Break it           → 03-broken.json    (drift introduced)
#   4. Watch Typerion catch it → fail with explanation
#
# Reproducible in ~30 seconds. No setup beyond curl + jq.
#

set -uo pipefail

API="${TYPERION_API:-https://typerion-v1-typerion-server-r3wh.vercel.app}"
PAT="${TYPERION_PAT:-pat_typerion_preview_demo_2026_05}"
HERE="$(cd "$(dirname "$0")" && pwd)"

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "missing dep : $1" >&2; exit 1; }
}
require curl
require jq

heading() {
  echo
  echo "── $1 ──────────────────────────────────────"
}

verify() {
  local baseline_file="$1"
  local candidate_file="$2"
  local body
  body=$(jq -n \
    --slurpfile b "$baseline_file" \
    --slurpfile c "$candidate_file" \
    '{baseline: {kind: "lossy-inline", value: ($b[0] | del(._comment))},
      candidate: {kind: "lossy-inline", value: ($c[0] | del(._comment))}}')
  curl -fsS --max-time 10 -X POST "$API/v1/verify" \
    -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    -d "$body"
}

cat <<'EOF'

Typerion demo · The control plane for software reality
══════════════════════════════════════════════════════

A four-step narrative on a Session entity in a typical
TypeScript + Postgres backend. Each step is real : the
kernel is hosted, the inputs are JSON IRs you can read, and
the verdict at the end has a deterministic fingerprint
anyone can reproduce.

EOF

heading "1. Write intent"
cat <<'EOF'

You declare what the system should be. One canonical
definition. Every projection (TS interface, SQL table,
API contract, RBAC rule) is derived from this — without
replacing your existing tools.

EOF
jq 'del(._comment)' "$HERE/01-intent.json"

heading "2. Generate system"
cat <<'EOF'

The control plane derives the system from intent. In this
demo the generated state is hand-aligned with the intent —
the same shape Typerion would emit from the projection
engine. Each field is present in both projections.

EOF
jq 'del(._comment)' "$HERE/02-generated.json"

cat <<'EOF'

  Verifying intent ↔ generated...
EOF
RESPONSE_PASS=$(verify "$HERE/01-intent.json" "$HERE/02-generated.json")
echo "$RESPONSE_PASS" | jq

STATUS=$(echo "$RESPONSE_PASS" | jq -r '.status')
if [ "$STATUS" != "pass" ]; then
  echo "ERROR : expected status=pass on the aligned case, got $STATUS"
  exit 1
fi

heading "3. Break it"
cat <<'EOF'

A DBA on another team adds a 'last_seen_at' column to the
sessions table via an out-of-band migration. There is a
trigger that auto-updates it on every UPDATE. The TypeScript
application code is never touched. The migration runs. The
trigger works. The TS compiler is happy. Tests pass.

But the SQL projection now contains a field the TS
projection does not — a structural inconsistency between
two layers of the same logical system.

EOF
jq 'del(._comment)' "$HERE/03-broken.json"

heading "4. Watch Typerion catch it"
cat <<'EOF'

  Verifying intent ↔ broken...
EOF
RESPONSE_FAIL=$(verify "$HERE/01-intent.json" "$HERE/03-broken.json")
echo "$RESPONSE_FAIL" | jq

STATUS=$(echo "$RESPONSE_FAIL" | jq -r '.status')
REASON=$(echo "$RESPONSE_FAIL" | jq -r '.reasons[0]')
FINGERPRINT=$(echo "$RESPONSE_FAIL" | jq -r '.fingerprint')

cat <<EOF

══════════════════════════════════════════════════════

The control plane observes the system as a whole and sees
the gap. The reason is human-readable. The fingerprint is
deterministic — anyone running this demo gets the same
hash. CI gates can fail on this exit code (this script
exits with 1 below, since the verdict was 'fail').

  Status      : $STATUS
  Reason      : $REASON
  Fingerprint : $FINGERPRINT

This is one slice of what Typerion does : observe drift
between layers of the same logical system, explain it, and
fail-close when it would reach production. The full
control plane extends across multiple sources (Prisma /
OpenAPI / Terraform / GitHub) and integrates with PR gates,
audit logs, and policy enforcement.

  Typerion is not the system.
  It is what ensures your system remains one system.

EOF

# Exit code reflects the demo verdict so it can be wired into CI
if [ "$STATUS" = "fail" ]; then
  exit 1
fi
exit 0
