# Case study — Cal.com

Reproducible run of Typerion against [Cal.com](https://github.com/calcom/cal.com)
— an open-source scheduling app, actively maintained, several
years of schema history, TypeScript + Prisma + PostgreSQL stack.

> **What this case study proves** : the Typerion thesis on a real
> production codebase, not a synthetic fixture. *Modern software
> systems are not broken because tools are missing. They are
> broken because nothing understands how everything connects.*
> This run shows a real drift, present in real production code,
> that no existing tool catches.

This case study demonstrates the **detection** capability of the
Typerion control plane (one slice of the full system : represent
the system → detect inconsistencies → explain why → block in CI).
The parser used here is Cal.com-targeted ; generic extractors
across more sources are roadmap.

| Step | Demonstrated here ? |
|---|---|
| 1. Represent (extract canonical model from existing artifacts) | ✅ via the Cal.com-specific parser ; generic multi-source extractor is roadmap |
| 2. Detect (find inconsistencies between layers) | ✅ kernel verify TS ↔ SQL pair |
| 3. Explain (trace divergence to source line) | ✅ human-readable reason strings ; provenance-to-exact-line is roadmap |
| 4. Block (CI-usable enforcement) | ⚠️ via `typerion verify` exit code ; integrated PR-gate is roadmap |

> **Reproducibility** : `./run-case-study.sh` fetches the pinned Cal.com
> schema, parses it to a Typerion IR, and posts it to the kernel. All
> three steps are deterministic given the pinned SHA.

## Run it

```bash
./run-case-study.sh
```

Output (verbatim) :

```
── Cal.com schema fetch ──────────────────────────────
Pinned SHA : a4a01a0
Bytes : 101057
Lines : 2851
Models : 100
Enums  : 46

── Parse to SimpleIR ─────────────────────────────────
Parsed 100 entities, 1096 scalar fields total, 1 with @map (sqlName divergence).

── Submit to Typerion verify ─────────────────────────
Verdict :
{
  "status": "fail",
  "reasonsCount": 1,
  "fingerprint": "da0fbedd80848ecf17c1c36ebd177531"
}

Reasons :
  - Entity 'User' field 'createdDate' projects to TS name 'createdDate' but SQL name 'created' — runtime writes to TS field 'createdDate' will not reach SQL column 'created'.
```

## Numbers

| Metric                      | Value |
|-----------------------------|-------|
| Models analyzed             | 100   |
| Scalar fields analyzed      | 1096  |
| Cross-projection findings   | 1     |
| Asymmetric exclusions       | 0     |
| Field-name collisions       | 0     |
| Field-level @map divergences| 1     |

## The single finding

The `User` model has 49 scalar fields. One of them carries a
field-level `@map` :

```prisma
createdDate         DateTime             @default(now()) @map(name: "created")
```

The TypeScript-side projection of this field is `createdDate`. The
SQL-side projection (the actual column name in the `users` table)
is `created`. Both projections are individually valid.

This divergence is **benign under Prisma's ORM usage** : the
runtime translates the field name on every query, every test in
the repository passes, and a developer using only the Prisma
client will never see a problem.

What it introduces is **inconsistency between application-level
naming and database-level representation**. That can lead to
errors in cross-layer contexts where the TypeScript-side name is
referenced against the actual database :

- Raw-SQL queries written from the TypeScript model (analytics,
  BI dashboards, custom reports) reference `users.createdDate`
  while the column is actually named `created`.
- Custom migrations or ad-hoc data-fix scripts that read the
  field name from the TypeScript schema rather than the SQL
  schema may not match real columns.
- Tooling that introspects the TypeScript types to generate
  cross-system contracts (OpenAPI specs, GraphQL schemas, data-
  warehouse mappings) inherits the application-level name and
  drifts from the database-level name.

The pattern matches *half-done rename* (see
[`audit/fixtures/case-06-half-done-rename.json`](../../../audit/fixtures/case-06-half-done-rename.json))
in the canonical Typerion fixture set : a SQL column named one
way, a TypeScript field named another, the ORM bridges the
divergence at one layer, and any code that bypasses the ORM hits
the unbridged surface.

## What this calibrates

Cal.com is an actively-maintained TypeScript + Prisma open-source
application. The codebase has multiple maintainers, a CI pipeline
that runs full type-checks plus tests, and reasonably-disciplined
schema management.

Yet **one latent name-divergence persists in the schema** :
`User.createdDate ↔ users.created`. The base rate is low — 1 in
1096 scalar fields, or roughly 0.09% — but non-zero, and the
affected field is a user-creation timestamp typically used in
analytics queries.

This is the cost calibration the Typerion thesis predicts :

- The bug class is real (verified at one instance on a real
  codebase, not a synthetic fixture).
- It survives despite tests, type-checks, and ORM coverage —
  Prisma's `@map` handles the runtime translation, so the
  application path is correct.
- It is silent in the ORM-only path and only becomes visible in
  cross-layer contexts (raw SQL, migrations, analytics queries).
- It's the kind of inconsistency that *looks correct* — every
  individual layer is internally consistent, only the cross-
  projection invariant is broken.

The alternative formulation : *Cal.com's schema is
**known locally** (each field is correctly defined for its own
projection) but **not validated globally** (no tool checks
that the same logical field's TS view and SQL view agree on
names).*

Single-codebase, single-finding. We don't claim this proves the
problem is universal or quantifies its prevalence at scale. We
claim it makes the bug class **observable on real code** rather
than only on synthetic fixtures. The next step would be running
the same pipeline against other large Prisma schemas to build a
base-rate estimate — that's not in this case study.

## Limits of this case study

A few honest caveats :

- **Parser is hacky and Cal.com-targeted.** It's not a general
  Prisma extractor. It handles the patterns that appear in
  Cal.com's schema. Other Prisma schemas may use features
  (composite keys, MongoDB types, multi-schema, custom views)
  that this parser ignores. It's good enough to demonstrate the
  Typerion analysis but not good enough to ship as a generic
  tool.
- **Relations and arrays skipped.** A Prisma relation field is
  TypeScript-only by construction (no SQL column corresponds to
  it directly ; the SQL side has the foreign-key column instead).
  Including relations in the IR would flood the asymmetric-
  exclusion check with noise. The parser keeps the foreign-key
  scalar and skips the relation-typed sibling.
- **Enums collapsed to `string`.** The Typerion `SimpleIR`
  doesn't model enum types ; Cal.com's 46 enums are all mapped
  to `string` in the IR. This loses some structural information
  but doesn't change the cross-projection check at the field
  level.
- **Single fixture per finding.** The 1 finding is a real
  divergence in production code, but a sample size of 1 doesn't
  let us extrapolate prevalence across the OSS ecosystem. The
  next step would be running the same pipeline on other large
  Prisma schemas (Documenso, Plane, Twenty CRM, Formbricks) to
  build a base-rate estimate. That's not in this case study.
- **No causal claim about Cal.com's history.** The `@map(name:
  "created")` likely comes from a normalization-style rename
  applied to the SQL column at some point in Cal.com's history,
  with the TypeScript field name preserved for source-level
  backwards-compatibility. We have not traced the git history
  to confirm this — the structural conclusion stands either
  way.

## Files

```
README.md            this analysis
parse-prisma.py      hacky Cal.com-targeted Prisma → SimpleIR parser
run-case-study.sh    end-to-end reproducibility script
```

## Context

The Typerion thesis : different ORMs catch different subsets of
cross-projection inconsistencies, but none validate the full
surface (asymmetric exclusion, projection-name divergence,
trigger columns, alias collisions, half-done renames). This case
study is one empirical anchor for that claim — a real codebase
with real reviewer-disciplined maintainers has a real divergence
that Prisma cannot flag at validation time.

For the canonical fixtures and the cross-target coherence
primitive, see the [repo root README](../../../README.md). For
the empirical ORM-coverage tests on the canonical
`email`/`emailAddress` collision, see
[`examples/orm-coverage/`](../../orm-coverage/).
