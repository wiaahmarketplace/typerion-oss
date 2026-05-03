#!/usr/bin/env bash
#
# typerion preview demo — show one cross-target inconsistency that
# passes local validation but corrupts data at runtime.
#
# Usage:
#   ./scripts/run-demo.sh                  # uses default API
#   TYPERION_API=http://localhost:4101 ./scripts/run-demo.sh
#   TYPERION_PAT=pat_<your-token> ./scripts/run-demo.sh
#

set -euo pipefail

API="${TYPERION_API:-http://localhost:4101}"
PAT="${TYPERION_PAT:-pat_$(openssl rand -hex 16 2>/dev/null || echo placeholdertoken123456)}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASELINE="$ROOT/examples/baseline.json"
CANDIDATE="$ROOT/examples/collision-case.json"

if [ ! -f "$BASELINE" ] || [ ! -f "$CANDIDATE" ]; then
  echo "error: missing example fixtures at $BASELINE / $CANDIDATE" >&2
  exit 1
fi

cat <<EOF
typerion preview demo
─────────────────────

The TS code below compiles. Each field is a string. Every type-checker
on earth will say it's fine:

  interface User {
    email: string;
    emailAddress: string;
  }

The SQL migration below also runs cleanly. Both columns are valid:

  ALTER TABLE users
    ADD COLUMN email_address VARCHAR;        -- "emailAddress" in TS

Except: the new field 'emailAddress' was annotated to map back to the
existing 'email' column (legacy migration shim that never got removed).
The IR for both states:

  baseline:  examples/baseline.json
  candidate: examples/collision-case.json

POST /v1/verify with both files →

EOF

REQ_BODY=$(jq -n \
  --argjson baseline "$(cat "$BASELINE")" \
  --argjson candidate "$(cat "$CANDIDATE")" \
  '{baseline:{kind:"lossy-inline",value:$baseline},candidate:{kind:"lossy-inline",value:$candidate}}')

RESPONSE=$(curl -fsS -X POST "$API/v1/verify" \
  -H "Authorization: Bearer $PAT" \
  -H "Content-Type: application/json" \
  -d "$REQ_BODY") || {
    echo
    echo "error: could not reach $API/v1/verify"
    echo "       run typerion-server locally first, or set TYPERION_API"
    exit 1
  }

echo "$RESPONSE" | jq

echo
cat <<'EOF'
─────────────────────

Two TS fields collapse onto one SQL column. At runtime, writing to
user.emailAddress overwrites user.email. Type-checker said yes.
Migration ran clean. The system is broken.

This is an early preview. Only TS ↔ SQL. No runtime integration.
Feedback that breaks it is the most useful kind.
EOF
