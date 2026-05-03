# Typerion

> **Your types are correct.**
> **Your database is correct.**
> **Your system is still broken.**

This is an **early preview**. One check, one pair of targets (TS ↔ SQL),
no runtime integration, no guarantees. Posted to find out whether the
core idea holds technically. Feedback that **breaks it** is the most
useful kind.

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

The migration runs. The column exists. Drizzle / Prisma / TypeORM
generate without complaint.

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
- **No tool in the standard stack checks both projections
  simultaneously**, with the awareness that they both derive from
  the same logical schema.

ORMs check their own schema → SQL alignment. Type-checkers check
their own type definitions. Migration tools check SQL syntax.
Nobody checks the cross-target invariant.

## What this is

A small kernel that takes two intermediate representations
(`baseline`, `candidate`) and verifies that the candidate's TS
projection and SQL projection agree on names, presence, and types
— **before** runtime.

That's it.

## Run the demo

```bash
git clone <this repo>
cd typerion-oss
pnpm install
pnpm build

# In another terminal: start the server (private repo for now —
# DM/email me for access during preview)
TYPERION_PORT=4101 node ../typerion-server/dist/index.js

# Run the demo
./scripts/run-demo.sh
```

Or hit it directly:

```bash
curl -s -X POST http://localhost:4101/v1/verify \
  -H "Authorization: Bearer pat_$(openssl rand -hex 16)" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --argjson b "$(cat examples/baseline.json)" \
    --argjson c "$(cat examples/collision-case.json)" \
    '{baseline:{kind:"lossy-inline",value:$b},candidate:{kind:"lossy-inline",value:$c}}')" \
  | jq
```

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

If your reaction is *"my ORM already catches this"*, please send
the exact ORM + version + config. I want to know where the gap
narrows or disappears.

## License

[MIT](LICENSE).
