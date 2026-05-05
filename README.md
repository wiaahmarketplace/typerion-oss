# Typerion

> **Your types are correct.**
> **Your database is correct.**
> **Your system is still broken** — in specific edge cases like the
> one below.

This is an **early preview**. One check, one pair of targets (TS ↔ SQL),
no runtime integration, no guarantees. Posted to find out whether the
core idea holds technically. Feedback that **breaks it** is the most
useful kind.

## Try it now

```bash
export TYPERION_TOKEN=pat_typerion_preview_demo_2026_05

curl -s -X POST https://typerion-v1-typerion-server-r3wh.vercel.app/v1/verify \
  -H "Authorization: Bearer $TYPERION_TOKEN" \
  -H "Content-Type: application/json" \
  -d @- <<'JSON' | jq
{
  "baseline":  {"kind":"lossy-inline","value":{"entities":[{"name":"Session","fields":[{"name":"id","type":"string"},{"name":"userId","type":"string"},{"name":"expiresAt","type":"date"}]}]}},
  "candidate": {"kind":"lossy-inline","value":{"entities":[{"name":"Session","fields":[{"name":"id","type":"string"},{"name":"userId","type":"string"},{"name":"expiresAt","type":"date"},{"name":"lastSeenAt","type":"date","excludeFromTs":true}]}]}}
}
JSON
```

Expected output :

```json
{
  "status": "fail",
  "reasons": [
    "Entity 'Session' field 'lastSeenAt' is present in SQL projection but excluded from TS — TS code cannot read or write this column, leading to silent NULLs or write failures."
  ],
  "fingerprint": "1d1527bb5278f5f4d0008a76de343b57"
}
```

The hosted endpoint is rate-limited (30 req/min) and disposable —
torn down when the preview window closes. No signup, no API key to
generate. Read on for the why.

> **Note on the shared `pat_typerion_preview_demo_2026_05`** : it's a public token for
> this demo instance only — rate-limited and isolated. Real auth
> isn't the focus of this preview ; the kernel decision is.

> **TL;DR of the case below** : a DB column exists in the database
> but isn't modeled by the application code. The migration ran. The
> TS interface compiles. Both projections of the same logical schema
> are valid in isolation — but **collectively inconsistent**, and
> no ORM can catch this case because the bug lives **outside** the
> ORM's view of the schema.

---

## The case — a DB-trigger column the application doesn't model

A DBA on a previous team added a `last_seen_at` column to the
`sessions` table via an out-of-band migration with a trigger that
auto-updates it on every UPDATE. The application code was never
touched. The column lives in the database, populated by the trigger,
but it doesn't appear in the TypeScript interface.

Six months later, a junior engineer writes a raw SQL query that
joins `sessions.last_seen_at` and the result lands in a TS variable
typed as something the column doesn't actually carry. On staging
the column exists ; on the dev tier it doesn't ; the bug surfaces
intermittently, weeks after merge.

```sql
ALTER TABLE sessions
  ADD COLUMN last_seen_at TIMESTAMP DEFAULT now();
CREATE TRIGGER session_touch BEFORE UPDATE ON sessions
  FOR EACH ROW EXECUTE FUNCTION touch_last_seen();
```

```ts
interface Session {
  id: string;
  userId: string;
  expiresAt: Date;
  // lastSeenAt — never declared in TypeScript
}
```

The migration ran. The trigger works. Every TS type-checker on
earth approves the interface. Each tool checks its own projection
against itself.

The IR for the candidate state explicitly marks the field as
SQL-only :

```json
{
  "name": "lastSeenAt",
  "type": "date",
  "excludeFromTs": true
}
```

**Output of `typerion verify` against this candidate :**

```json
{
  "status": "fail",
  "reasons": [
    "Entity 'Session' field 'lastSeenAt' is present in SQL projection but excluded from TS — TS code cannot read or write this column, leading to silent NULLs or write failures."
  ]
}
```

This case is **structurally out of every ORM's scope** by design.
Prisma / Drizzle / TypeORM all assume the schema is owned by the
ORM. A column that lives in the database but isn't part of the ORM
model is not a bug they can catch — it's a category they don't
model. Yet at the application level it's a real source of runtime
divergence : raw SQL queries pull a value the ORM doesn't know
exists, and the type system has no opinion.

## Other patterns the same primitive catches

The audit fixtures in [`audit/fixtures/`](audit/fixtures/) cover
five additional production-realistic cases. Each carries a short
`narrative` field describing the scenario it's drawn from :

| # | Pattern                       | Production scenario                                              |
|---|-------------------------------|------------------------------------------------------------------|
| 03 | virtual-property leak (TS-only) | Computed field marked TS-only, ORM upsert flow writes anyway   |
| 04 | trigger-column orphan (SQL-only) | The case above — DB-trigger column the app doesn't model      |
| 05 | i18n alias collision (TS-side) | `descriptionFr` aliased to `description`, two fields collapse  |
| 06 | half-done rename (name divergence) | SQL normalization renamed `currentPeriodEnd` → `current_period_end`, TS field never updated |
| 01 | legacy email-shim collapse     | Two TS fields land on one SQL column — *Prisma catches this specific case (`P1012`), Drizzle silently drops the field, TypeORM accepts it* |
| 02 | mid-flight rename collapse     | Same shape as 01 — ongoing deprecation that never finished       |

The empirical ORM coverage test for case 01 is in
[`examples/orm-coverage/`](examples/orm-coverage/) — reproducible,
each output captured.

## Why no existing tool catches this

- TypeScript sees the fields in the interface. They have distinct
  names. They are independent values.
- The SQL migration sees the columns. They have names. They accept
  writes. They may even have triggers.
- Different ORMs catch different subsets of inconsistencies, but
  the broader class — field exclusion asymmetry, projection-name
  divergence on either axis, trigger columns the application
  doesn't model, i18n alias collisions, partial renames after
  normalization — is **not** validated by any of them. They each
  check their own projection against itself.

Type-checkers check their own type definitions. Migration tools
check SQL syntax. ORMs check their own schema → SQL alignment with
varying coverage. Nobody systematically verifies the cross-target
invariant — that the TS view and the SQL view of the same logical
schema agree on names, presence, and types.

## What this is

A small kernel that takes two intermediate representations
(`baseline`, `candidate`) and verifies that the candidate's TS
projection and SQL projection agree on names, presence, and types
— **before** runtime.

That's it.

## Run the demo

The kernel is hosted at `https://typerion-v1-typerion-server-r3wh.vercel.app` during the preview.
A shared preview token is built into the script — no signup, no API key
to generate, just curl:

```bash
git clone <this repo>
cd typerion-oss
./scripts/run-demo.sh                      # hits the hosted preview endpoint
```

Or hit it directly:

```bash
curl -s -X POST https://typerion-v1-typerion-server-r3wh.vercel.app/v1/verify \
  -H "Authorization: Bearer pat_typerion_preview_demo_2026_05" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --argjson b "$(cat examples/baseline.json)" \
    --argjson c "$(cat examples/collision-case.json)" \
    '{baseline:{kind:"lossy-inline",value:$b},candidate:{kind:"lossy-inline",value:$c}}')" \
  | jq
```

The hosted endpoint is rate-limited (30 req/min) and will be torn down
when the preview window closes. Don't build anything against it — try
the demo and tell me what you find.

## Reproducible audit

The preview ships with a fixture set and an audit script that re-runs
the kernel against every fixture and asserts each output matches a
pinned `{status, reasons, fingerprint}`.

```bash
pnpm audit
# or
./audit/run-audit.sh
```

The 10 fixtures cover real classes of cross-system inconsistency
commonly observed in production codebases : legacy schema-shim
collapses, mid-flight renames that never finished, virtual-property
leaks, DB-trigger columns the application doesn't model, i18n field
aliasing collisions, and partial column renames after normalization
migrations. Each fixture carries a short `narrative` describing the
production scenario it's drawn from.

The audit verifies a precise determinism claim :

> Given identical inputs and a versioned kernel execution
> (VERIFY_VERSION = `v15.5-austere-1`), the kernel produces the
> same `status`, the same `reasons`, and the same `fingerprint` on
> every run, on every machine.

This is **not** a claim of determinism across kernel versions, across
different inputs, or under network failure. The audit script fails
loudly if any pinned ground truth drifts — that's the entire point.

## Limits (read first)

- One pair of targets only: **TS ↔ SQL**. No GraphQL, OpenAPI,
  RBAC, RLS in this preview.
- The IR shape (`SimpleIR`) is a deliberate subset, not the
  production form.
- **No extractors yet.** The IR has to be hand-written. That makes
  this preview a verification of the kernel decision logic, not a
  ready-to-run tool against your real codebase. Extractors for
  Prisma / TypeORM / Drizzle / raw SQL are the most-requested next
  step ; they're not in this preview.
- **Hosted-API trust.** The kernel decision logic is private and
  served from a hosted endpoint. Senior engineers reviewing
  production schemas have rightly flagged that no real codebase
  should be sent to a closed-source hosted API ; a local CLI mode
  that runs the kernel binary on your machine is the right answer.
  It's not in this preview either. **For now, only test with the
  bundled fixtures or hand-written IRs.**
- Server is private. The kernel logic that makes the verify
  decision is not open. Only the CLI surface and the public IR
  shape are MIT-licensed in this repo.
- No claim of completeness, no SLO, no guarantees of any kind. If
  you find a mutation this preview misses, that's the feedback I
  want most.

## What I'm asking for

If you try this on a case from your codebase — real or remembered —
**tell me what broke**. Open an issue with the failing IR. The
[issue template](.github/ISSUE_TEMPLATE/preview-feedback.md) asks
the right questions.

**If your ORM catches this reliably, please send me the config —
I'll add it as a passing case** and credit you in the README. I'd
rather know that gap exists than argue about it. Particularly
interested in : Drizzle (`drizzle-kit check`), Prisma (`prisma
validate`), TypeORM, Kysely, MikroORM, plain `pg` + `tsc` + a
linter. Exact version + tsconfig + schema config, please.

## License

[MIT](LICENSE).
