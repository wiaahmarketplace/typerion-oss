# Case study — Cal.com

Reproducible run of Typerion against [Cal.com](https://github.com/calcom/cal.com)
— an open-source scheduling app, ~30k stars on GitHub, multiple
full-time engineers, TypeScript + Prisma + PostgreSQL stack with
several years of schema history.

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
is `created`. Both projections are individually valid : Prisma's
mapping handles the divergence at runtime, every test in the
repository passes, and a developer using only the Prisma client
will never see a problem.

The latent risk surfaces in the **raw-SQL path** :

- Any analytics or BI query that joins or filters on
  `users.createdDate` — written by someone reading the TypeScript
  type rather than the SQL schema — will fail. The SQL parser
  will report the column does not exist, and the dashboard /
  report / pipeline will silently break (or produce wrong
  numbers, depending on how the calling code handles the error).

- Any custom migration that references the field name from the
  TypeScript model rather than from the SQL schema will not apply.

This is the *half-done rename* pattern (see
[`audit/fixtures/case-06-half-done-rename.json`](../../../audit/fixtures/case-06-half-done-rename.json))
in the canonical Typerion fixture set : a SQL column named one
way, a TypeScript field named another, the ORM bridges the
divergence at one layer, and any code that bypasses the ORM hits
the unbridged surface.

## What this calibrates

Cal.com is one of the most-actively-maintained TypeScript +
Prisma open-source applications in 2026. The codebase has
multiple full-time maintainers, a CI pipeline that runs full
type-checks plus tests, and a reasonably-disciplined schema
discipline. A senior-engineer review *should* and likely does
catch most schema drift in normal review.

Yet **one latent name-divergence persists in the schema** :
`User.createdDate ↔ users.created`. The base rate is low — 1 in
1096 scalar fields, or roughly 0.09% — but non-zero, and the
affected field is a user-creation timestamp typically used in
analytics queries.

This is the cost calibration the Typerion thesis predicts :

- The bug class is real (verified at one instance on a
  high-quality codebase).
- It survives despite tests, type-checks, and ORM coverage —
  Prisma's `@map` handles the runtime translation, so the
  application path is correct.
- It surfaces only in raw-SQL contexts that bypass the ORM.
- It's the kind of bug that *looks correct* — every individual
  layer is internally consistent, only the cross-projection
  invariant is broken.

The alternative formulation : *Cal.com's schema is
**known locally** (each field is correctly defined for its own
projection) but **not validated globally** (no tool checks
that the same logical field's TS view and SQL view agree on
names).*

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
