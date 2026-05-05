# Typerion

> **Software systems don't fail because code is wrong.**
> **They fail because parts drift out of sync.**
> **Typerion makes that drift visible, explainable, and controllable.**

A coherence layer above modern software stacks. Typerion doesn't
replace your tools — it makes sure they behave like one system.

**When your system drifts, Typerion shows you where and why.**

---

## What Typerion is (and isn't)

| Typerion is | Typerion is not |
|---|---|
| A coherence layer above your existing stack | An ORM |
| An observer of cross-layer consistency | A backend framework |
| A drift detector + explainer + gate | A replacement for Prisma / OpenAPI / Terraform |
| A control surface humans use to enforce coherence | A platform that asks you to throw away your stack |

You keep your tools. Typerion sits above them and ensures the
projections of your logical schema (TS interfaces, SQL columns,
API contracts, infra configs, RBAC rules) **stay aligned over time**.

## How Typerion works — the 4-step mechanism

```
1. Represent  →  extract a canonical model from your existing artifacts
                 (Prisma schema, OpenAPI spec, TypeScript types, ...)

2. Detect     →  find inconsistencies between layers
                 (field collapsed, asymmetric exclusion, name divergence)

3. Explain    →  trace each divergence to its source line
                 (provenance, fingerprint, human-readable reason)

4. Block      →  fail CI when uncontrolled drift would reach production
                 (exit codes for CI scripts, PR-gate hook coming)
```

The full Typerion vision spans all four steps across many source
projections. **This early preview demonstrates step 2 (detect)**
on a single pair of projections (TS ↔ SQL), with partial support
for step 3 (human-readable reasons) and step 4 (CLI exit code).
Multi-source ingestion (step 1 generalized) and full PR-gate
(step 4 generalized) are the roadmap.

## Try it now (proof of step 2 on a small case)

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

This case illustrates the pattern : a SQL column exists in the
database (added via an out-of-band DBA migration with a trigger)
but is not modeled by the TypeScript application code. Both
projections are individually valid. The cross-projection
invariant is broken — and **no ORM catches this**, because the
column lives outside their view of the schema.

> **Note on the shared `pat_typerion_preview_demo_2026_05`** : it's a public token for
> this demo instance only — rate-limited and isolated. Real auth
> isn't the focus of this preview ; the kernel decision is.

### Or via the CLI

```bash
git clone https://github.com/wiaahmarketplace/typerion-oss
cd typerion-oss && pnpm install
pnpm --filter @typerion/cli build

node packages/cli/bin/typerion.mjs verify \
  ./audit/fixtures/case-04-trigger-column-orphan.json
```

Same result. Exit code reflects verdict (`0` = pass, `1` = fail,
`2` = uncertain) — usable in CI scripts (step 4 in the small).

## Why this matters — the industry already documents 5 patterns

The community has named **five patterns of schema drift** that
break production :

- **Type Shift** — a field silently changes type (`number` → `string`)
- **Silent Disappearance** — a field vanishes from the serializer
- **Nullable Surprise** — a non-null assumption fails on a null value
- **Structural Reshape** — `response.x` moves to `response.data.x`
- **Phantom Addition** — a field appears unintentionally (e.g. unmasked SSN)

(Source : *Anatomy of a Schema Drift Incident — 5 Real Patterns That
Break Production*, DEV.to / QA Leaders, March 2026.)

The Typerion audit fixtures cover **four additional failure modes**
that are not categorized in mainstream drift literature :

| Pattern                              | Why no existing tool catches it                                       |
|--------------------------------------|------------------------------------------------------------------------|
| TS-only virtual property leak (case-03) | ORM upsert flow returns the written object, masking the write failure |
| SQL-only trigger column orphan (case-04) | The column lives outside the ORM's view of the schema                |
| Half-done rename (case-06)              | ORM mapping config bridges the divergence ; raw SQL queries break    |
| Mapping-shim collision (case-01)        | Two TS fields collapse onto one SQL column ; only Prisma catches this specific shape |

The unifying property : these bugs are **known locally** (every
senior dev has seen one) but **not mastered globally** (no tool
validates the cross-target invariant). They share four
characteristics that make them hard to detect :

- **Invisible** — no crash, plausible values, the app continues to run
- **Delayed** — surface weeks or months after the merge that
  introduced them, typically after a partial migration
- **Distributed** — the API says A, the DB does B, the code assumes C ;
  each layer is internally correct, the system as a whole is broken
- **Test-blind** — *"the test will catch it"* only holds if the test
  verifies actual database state, not the response object that the
  ORM returns

Schema drift is a well-documented problem in production systems.
In one published audit, **23 of 47 endpoints had structural drift
while the test suite reported 100% passing for six months
straight**. In another reported incident, a simple type change
(`number` → `string` on `user_id` after a routine migration)
passed every test and broke roughly **30% of mobile users in
production**. (Source : *Your API Tests Are Lying to You — The
Schema Drift Problem Nobody Talks About*, DEV.to.)

These bugs are hard to detect because the system remains
operational while silently diverging. The most expensive bugs
are not the ones that crash. They are the ones that look correct.

## Case study — Cal.com (real codebase)

To anchor the wedge in real code rather than synthetic fixtures,
we ran Typerion against [Cal.com](https://github.com/calcom/cal.com)
— an open-source scheduling app, actively maintained, several
years of schema history, TypeScript + Prisma + PostgreSQL.

Reproducible end-to-end via
[`examples/case-studies/calcom/run-case-study.sh`](examples/case-studies/calcom/).

> Out of 1096 fields across 100 models, Typerion found **1
> cross-layer inconsistency**. Rare, but real — and not caught by
> tests or ORM validation.

| Metric                      | Value |
|-----------------------------|-------|
| Models analyzed             | 100   |
| Scalar fields analyzed      | 1096  |
| Cross-projection findings   | 1     |

The single finding : `User.createdDate` (TypeScript field) maps via
`@map(name: "created")` to the SQL column `created`. This
divergence is **benign under Prisma's ORM usage** — the runtime
translates the field name on every query, every test in the
repository passes, the application path is correct. But it
introduces inconsistency between application-level naming and
database-level representation, which **can lead to errors in
cross-layer contexts** : raw-SQL queries written against the
TypeScript field name, custom migrations that reference the field
from the TS model, analytics or BI dashboards that read directly
from the database.

This is one empirical anchor for the Typerion thesis : **even in
disciplined production-grade codebases, cross-projection
inconsistencies persist that are not modeled by tests or ORM
validation**. Not a high-frequency pain. A high-uncertainty,
low-visibility risk. Typerion makes the latent surface
observable — the value is calibration, not bug-counting.

Full analysis :
[`examples/case-studies/calcom/README.md`](examples/case-studies/calcom/README.md).

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
commonly observed in production codebases. Each fixture carries
a short `narrative` describing the production scenario it's
drawn from.

The audit verifies a precise determinism claim :

> Given identical inputs and a versioned kernel execution
> (VERIFY_VERSION = `v15.5-austere-1`), the kernel produces the
> same `status`, the same `reasons`, and the same `fingerprint` on
> every run, on every machine.

This is **not** a claim of determinism across kernel versions, across
different inputs, or under network failure. The audit script fails
loudly if any pinned ground truth drifts — that's the entire point.

## Empirical ORM coverage

How do mainstream ORMs handle the same case ? Reproducible test
in [`examples/orm-coverage/`](examples/orm-coverage/).

| ORM | Behavior on the canonical collision case |
|---|---|
| Drizzle Kit | reports *"Everything's fine 🐶🔥"*, generates SQL with one field silently dropped |
| TypeORM | accepts the collision in metadata, no static check |
| Prisma | catches this specific shape via `P1012` field-name normalization |

None of the three catch the broader class of inconsistencies the
Typerion audit fixtures cover. **Different tools optimize their
own layer's correctness — none observe the cross-layer
invariant.** That's where Typerion sits.

## What's in this preview vs what's roadmap

| 4-step mechanism | This preview | Roadmap |
|---|---|---|
| 1. **Represent** | Hand-written `SimpleIR` JSON, plus a Cal.com-targeted Prisma parser | Generic multi-source ingestion (Prisma / OpenAPI / TypeScript / Terraform) |
| 2. **Detect** | TS ↔ SQL pair, four detection categories | Multi-projection reconciliation across all ingested sources |
| 3. **Explain** | Human-readable reasons strings | Provenance to exact source line + fingerprint trail |
| 4. **Block** | `typerion verify` exit code (CI-usable) | Integrated PR-gate hook + drift reconciliation suggestions |

This preview is a **slice** of the full system. It demonstrates
that the cross-projection invariant is computable and
inconsistencies are detectable on real code — Cal.com is the
empirical anchor. The full coherence layer extends across more
projections, more sources, and more enforcement points.

## Limits (read first)

- **One pair of targets only in this preview** : TS ↔ SQL.
  GraphQL, OpenAPI, Terraform, RBAC, RLS are roadmap.
- **The IR shape (`SimpleIR`)** is a deliberate subset, not
  the production form.
- **No extractors yet** for arbitrary stacks. The IR has to be
  hand-written or generated by a stack-specific parser. The
  Cal.com case study uses a hacky-targeted Prisma parser, not
  a generic extractor.
- **Hosted-API only.** The kernel runs on a closed-source hosted
  endpoint. Senior engineers reviewing real schemas should not
  send production code to this preview — only test with the
  bundled fixtures or hand-written IRs. A local CLI mode that
  runs the kernel binary on your machine is the most-requested
  next step.
- **Server is private.** The kernel logic that makes the verify
  decision is not open. Only the CLI surface and the public IR
  shape are MIT-licensed in this repo.
- **No SLO, no guarantees.** This is a preview, not a product.
  If you find a mutation this preview misses, that's the
  feedback I want most.

## What I'm asking for

If you try this on a case from your codebase — real or remembered
— **tell me what broke**. Open an issue with the failing IR. The
[issue template](.github/ISSUE_TEMPLATE/preview-feedback.md) asks
the right questions.

The honest question I'm calibrating : **is the kind of cross-layer
drift Typerion catches something you'd want to catch automatically,
or does it feel like noise ?**

Sharp critique, counter-examples, and *"my stack already handles
this"* with a reproducible test are all welcome.

## License

[MIT](LICENSE) for the public surface.
