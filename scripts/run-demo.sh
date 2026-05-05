#!/usr/bin/env bash
#
# typerion preview demo — show one cross-layer inconsistency that
# is structurally invisible to every ORM in the standard stack.
#
# Software systems don't fail because code is wrong. They fail
# because parts drift out of sync. This demo shows step 2 (detect)
# of the Typerion 4-step mechanism on a real production-pattern
# fixture.
#
# Usage:
#   ./scripts/run-demo.sh                  # uses default API
#   TYPERION_API=http://localhost:4101 ./scripts/run-demo.sh
#   TYPERION_PAT=pat_<your-token> ./scripts/run-demo.sh
#

set -euo pipefail

# Default : the hosted preview endpoint with the shared token. Override
# with TYPERION_API + TYPERION_PAT if you're running the server locally.
API="${TYPERION_API:-https://typerion-v1-typerion-server-r3wh.vercel.app}"
PAT="${TYPERION_PAT:-pat_typerion_preview_demo_2026_05}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$ROOT/audit/fixtures/case-04-trigger-column-orphan.json"

if [ ! -f "$FIXTURE" ]; then
  echo "error: missing fixture at $FIXTURE" >&2
  exit 1
fi

cat <<EOF
typerion preview demo
─────────────────────

A DBA on a previous team added a 'last_seen_at' column to the
'sessions' table via an out-of-band migration with a trigger that
auto-updates it on every UPDATE. The application code was never
touched. The column lives in the database, populated by the
trigger, but it doesn't appear in the TypeScript interface.

  ALTER TABLE sessions
    ADD COLUMN last_seen_at TIMESTAMP DEFAULT now();
  CREATE TRIGGER session_touch BEFORE UPDATE ON sessions
    FOR EACH ROW EXECUTE FUNCTION touch_last_seen();

Meanwhile the TypeScript model never declared this column :

  interface Session {
    id: string;
    userId: string;
    expiresAt: Date;
    // lastSeenAt — never declared in TypeScript
  }

The migration ran. The trigger works. The TS compiler is happy.
Every ORM (Prisma / Drizzle / TypeORM) is structurally unable to
catch this — the column lives outside their view of the schema.

Typerion observes the system as a whole and sees the gap.

  fixture: audit/fixtures/case-04-trigger-column-orphan.json

POST /v1/verify with the fixture →

EOF

REQ_BODY=$(jq '{baseline: .baseline, candidate: .candidate}' "$FIXTURE")

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

A SQL column lives in the database. The application code does not
model it. Both projections are individually valid. The
cross-layer invariant is broken — and no ORM catches this, because
the column lives outside their view of the schema.

This is one of six failure-mode categories in audit/fixtures/.
The full Typerion vision extends across more projections, more
sources, and integrated PR-gate enforcement (step 4 of the
4-step mechanism).
EOF
