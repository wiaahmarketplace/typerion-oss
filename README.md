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
  "baseline":  {"kind":"lossy-inline","value":{"entities":[{"name":"User","fields":[{"name":"email","type":"string"}]}]}},
  "candidate": {"kind":"lossy-inline","value":{"entities":[{"name":"User","fields":[{"name":"email","type":"string"},{"name":"emailAddress","type":"string","sqlName":"email"}]}]}}
}
JSON
```

Expected output :

```json
{
  "status": "fail",
  "reasons": [
    "Entity 'User' field 'emailAddress' projects to TS name 'emailAddress' but SQL name 'email' — runtime writes to TS field 'emailAddress' will not reach SQL column 'email'.",
    "Entity 'User' has multiple fields collapsing into SQL name 'email' (logical fields: 'email', 'emailAddress') — only one survives at runtime, causing silent data loss."
  ],
  "fingerprint": "578f09fce81c380cb2abb303a0d253a8"
}
```

The hosted endpoint is rate-limited (30 req/min) and disposable —
torn down when the preview window closes. No signup, no API key to
generate. Read on for the why.

> **Note on the shared `pat_typerion_preview_demo_2026_05`** : it's a public token for
> this demo instance only — rate-limited and isolated. Real auth
> isn't the focus of this preview ; the kernel decision is.

> **TL;DR of the case below** : the TS compiler says OK. The SQL
> migration runs OK. **Individually valid, collectively
> inconsistent.** Nothing in the standard stack checks the
> cross-projection invariant.

---

## The case

```ts
interface User {
  email: string;
  emailAddress: string;
}
```

Both fields type-check. Both are non-null strings. Every TS
type-checker on earth approves.

```sql
CREATE TABLE users (
  email VARCHAR NOT NULL
);
```

The migration runs. The column exists.

What the popular ORMs actually do with this exact case (empirical
test — see [examples/orm-coverage/](examples/orm-coverage/) for the
reproducible setup) :

- **Drizzle Kit** : `drizzle-kit check` reports *"Everything's fine
  🐶🔥"*. The generated migration silently contains **only one
  column** — `emailAddress` is dropped from the SQL output without
  any warning. **Silent data loss at codegen time.**
- **TypeORM** : decorators apply without error. Metadata storage
  accepts the collision silently. The bug surfaces only at runtime
  when both fields are written.
- **Prisma** : `prisma validate` (versions 4.x → 7.x) raises
  `P1012 — Field 'emailAddress' is already defined on model
  'User'`. Prisma catches **this specific case** through field-name
  normalization, but the broader class of cross-projection
  inconsistency (asymmetric exclusions, projection-name divergence
  in the inverse direction, virtual properties, trigger columns)
  is not validated by any of the three.

The IR says the second field maps back to `email`:

```json
{
  "name": "emailAddress",
  "type": "string",
  "sqlName": "email"
}
```

(A legacy migration shim that survived. It happens.)

**Output of `typerion verify` against this candidate:**

```json
{
  "status": "fail",
  "reasons": [
    "Entity 'User' field 'emailAddress' projects to TS name 'emailAddress' but SQL name 'email' — runtime writes to TS field 'emailAddress' will not reach SQL column 'email'.",
    "Entity 'User' has multiple fields collapsing into SQL name 'email' (logical fields: 'email', 'emailAddress') — only one survives at runtime, causing silent data loss."
  ]
}
```

Two TS fields collapse onto one SQL column. At runtime, writes to
`user.emailAddress` overwrite `user.email`. The TypeScript compiler
saw nothing wrong. The migration ran clean. The system is silently
corrupting data.

## Why this happens

- TypeScript sees two fields in the interface. They have distinct
  names. They are independent values.
- The SQL migration sees one column. It has a name. It accepts
  writes.
- Different ORMs catch different subsets of inconsistencies. None
  of them validate cross-representation across the full surface
  (field exclusion asymmetry, projection-name divergence on either
  axis, trigger columns the application doesn't model, i18n alias
  collisions, partial renames after normalization). Each tool
  checks its own projection against itself.

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
