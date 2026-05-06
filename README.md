# Typerion

> ## **The Control Plane for Software Reality.**
> **One layer above everything you already have.**

Modern software systems are not broken because tools are missing.
They are broken because nothing understands how everything connects.

Typerion is a governance and coherence layer above your entire
software system — making your backend, frontend, databases,
infrastructure, CI/CD and cloud consistent, explainable, and
controllable as one system.

---

## The problem

You don't have a tooling problem. You have a coherence problem.
Systems evolve faster than anyone can understand them. Every
modern organization suffers from the same failure mode :

- **F.01** Broken dependencies across services
- **F.02** Unpredictable production changes
- **F.03** Compliance as a manual burden
- **F.04** Architecture drift between teams
- **F.05** Fragile deployments
- **F.06** Loss of system-wide visibility

## Position

Typerion sits **above** your backend, frontend, databases,
infrastructure, CI/CD and cloud. It does not replace any of them.

```
                  TYPERION · COHERENCE LAYER
                  GOVERNS · VALIDATES · EXPLAINS
   ──────────────────────────────────────────────────
   Kubernetes  · AWS  · GCP  · Azure  · Terraform
   GitHub  · Postgres  · Microservices  · Legacy
```

## Source of truth

A single `.tp` file becomes the canonical system definition that
governs your backend, frontend, infrastructure and runtime
behavior — without replacing your existing stack. Everything else
remains. Nothing is allowed to drift from it.

```
system "checkout" {
  version = "2.4.1"

  service "payments-api" {
    runtime  = node22
    contract = ./contracts/payments.tp
    deploy   = k8s.cluster.prod
  }

  data "users" {
    store  = postgres.main
    schema = ./schemas/users.tp
  }

  policy "pii-egress" {
    enforce = deny
    on      = data.users.email
  }
}
```

Derived from one file : backend, frontend, database, infrastructure,
runtime behavior. All signed by a single fingerprint.

## Capability

Questions no other tool can reliably answer :

- **Q.01** What will break if we deploy this change?
- **Q.02** Why was this change allowed?
- **Q.03** Which systems are drifting from intended architecture?
- **Q.04** Are we still compliant in real time?
- **Q.05** What is the actual structure of our production system right now?

## Outcome

| Before Typerion | After Typerion |
|---|---|
| Systems evolve independently | Every change is structurally validated |
| Governance is reactive | System evolution is constrained by reality |
| Audits are expensive snapshots | Compliance is continuous and automatic |
| Architecture is inferred, not known | Architecture becomes a living object |

## Coexistence

We do not replace your stack. We do not ask you to migrate. We ask
you to make your system understandable.

Typerion overlays your existing environment — Kubernetes, AWS / GCP
/ Azure, Terraform, GitHub, existing microservices, legacy
systems — and makes them coherent as one system.

## Typerion is not

- × a framework
- × a code generator
- × a CI/CD tool
- × a cloud platform

## Typerion is

A software control plane that enforces coherence across your
entire stack — without replacing it.

---

## This repository — a public preview

This repo is an **early preview** of one slice of the Typerion
control plane. The full system spans four integrated layers (L1
System Synthesis Core, L2 Governance Engine, L3 Reality Layer, L4
Industry Control Products). This preview exposes a small, runnable
demonstration of the **detection capability** : verifying
cross-projection coherence between TypeScript and SQL on a hand-
written or extracted IR.

It is not the product. It is one piece of the product, exposed
publicly to validate the underlying primitive on real code.

### What this preview demonstrates

| Step in the system | This preview | Roadmap |
|---|---|---|
| **Represent** — extract canonical model from existing artifacts | Hand-written `SimpleIR`, plus a Cal.com-targeted Prisma parser | Generic multi-source ingestion (Prisma / OpenAPI / TypeScript / Terraform / GitHub) |
| **Detect** — find inconsistencies between layers | TS ↔ SQL pair, four detection categories | Multi-projection reconciliation across all ingested sources |
| **Explain** — trace each divergence to its source line | Human-readable reasons strings + fingerprint | Provenance to exact source line + signed decision log |
| **Block** — fail CI when uncontrolled drift would reach production | `typerion verify` exit code (CI-usable) | Integrated PR-gate hook + drift reconciliation suggestions |

### Run the 4-step demo (30 seconds, end-to-end)

The cleanest entry point. Walks through intent → generated →
broken → caught, on a small Session entity, with a real
production-pattern drift introduced. Shows the control plane
observing, explaining, and blocking in CI.

```bash
git clone https://github.com/wiaahmarketplace/typerion-oss
cd typerion-oss
./examples/demo-system/run-demo.sh
```

Reproducible. Deterministic fingerprint. Exits with code 1 on
caught drift — wire it into CI as-is. See
[`examples/demo-system/`](examples/demo-system/) for the four
input files and the walkthrough.

### Try it now (raw API)

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

The case : a SQL column lives in the database (added via an
out-of-band DBA migration with a trigger) but is not modeled by
the TypeScript application code. Both projections are individually
valid. The cross-projection invariant is broken — and **no ORM
catches this**, because the column lives outside their view of
the schema.

> **Note on the shared `pat_typerion_preview_demo_2026_05`** : public token for
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
`2` = uncertain) — usable in CI scripts.

### Multi-source reconcile (Phase 04 extension)

The kernel preview also exposes a multi-source reconciler. Send
N tagged IRs (typically `prisma` + `openapi` + `typescript`) and
receive the unified IR + every cross-source divergence + ranked
fix suggestions in one round-trip.

```bash
curl -s -X POST https://preview.typerion.dev/v1/reconcile \
  -H "Authorization: Bearer $TYPERION_TOKEN" \
  -H "Content-Type: application/json" \
  -d @- <<'JSON' | jq
{
  "sources": [
    {"source": "prisma",  "ir": {"entities":[{"name":"User","fields":[{"name":"id","type":"number"},{"name":"email","type":"string"},{"name":"age","type":"number"}]}]}},
    {"source": "openapi", "ir": {"entities":[{"name":"User","fields":[{"name":"id","type":"number"},{"name":"email","type":"string"}]}]}}
  ]
}
JSON
```

Six divergence kinds detected : `entity-missing`, `field-missing`,
`type-mismatch`, `nullability-mismatch`, `name-rename-conflict`,
`composite-key-mismatch`. Reasons are human-readable strings ;
the response includes per-source provenance for every divergence.

Generate the IRs with the standalone extractors (no auth required) :

```bash
typerion-extract-prisma  schema.prisma  > /tmp/prisma.json
typerion-extract-openapi spec.yaml      > /tmp/openapi.json
typerion-extract-typescript src/types.ts > /tmp/ts.json
# Then POST a sources[] envelope built from .candidate.value of each.
```

For automated CI integration, see the
[`@typerion/github-action-typerion-reconcile`](https://github.com/wiaahmarketplace/Typerion_V1/tree/main/packages/github-action-typerion-reconcile)
action — runs the full pipeline on every PR and posts a Markdown
comment with grouped divergences.

## Empirical anchor — Cal.com case study

Typerion run against [Cal.com](https://github.com/calcom/cal.com)
— actively maintained TypeScript + Prisma + PostgreSQL codebase,
several years of schema history. Reproducible end-to-end via
[`examples/case-studies/calcom/run-case-study.sh`](examples/case-studies/calcom/).

> Out of 1096 fields across 100 models, Typerion found **1
> cross-layer inconsistency**. Rare, but real — and not caught by
> tests or ORM validation.

The single finding : `User.createdDate` (TypeScript field) maps via
`@map(name: "created")` to the SQL column `created`. The divergence
is benign under Prisma's ORM usage, but introduces inconsistency
between application-level naming and database-level representation,
which can lead to errors in cross-layer contexts (raw SQL queries,
custom migrations, analytics or BI dashboards).

This is one empirical anchor for the Typerion thesis : **even in
disciplined production-grade codebases, cross-projection
inconsistencies persist that are not modeled by tests or ORM
validation**.

Full analysis :
[`examples/case-studies/calcom/README.md`](examples/case-studies/calcom/README.md).

## Empirical anchor — ORM coverage

How do mainstream ORMs handle the canonical collision case ?
Reproducible test in [`examples/orm-coverage/`](examples/orm-coverage/).

| ORM | Behavior |
|---|---|
| Drizzle Kit | reports *"Everything's fine 🐶🔥"*, generates SQL with one field silently dropped |
| TypeORM | accepts the collision in metadata, no static check |
| Prisma | catches this specific shape via `P1012` field-name normalization |

None of the three catch the broader class of inconsistencies the
Typerion audit fixtures cover. **Different tools optimize their
own layer's correctness — none observe the cross-layer invariant.**
That's where Typerion sits.

## Why this matters — five documented patterns + four more

The community has named **five patterns of schema drift** that
break production : Type Shift / Silent Disappearance / Nullable
Surprise / Structural Reshape / Phantom Addition.
(Source : *Anatomy of a Schema Drift Incident*, DEV.to / QA Leaders, March 2026.)

The Typerion audit fixtures cover **four additional failure modes**
that are not categorized in mainstream drift literature :

| Pattern                              | Why no existing tool catches it                                       |
|--------------------------------------|------------------------------------------------------------------------|
| TS-only virtual property leak        | ORM upsert flow returns the written object, masking the write failure |
| SQL-only trigger column orphan       | The column lives outside the ORM's view of the schema                |
| Half-done rename                     | ORM mapping config bridges the divergence ; raw SQL queries break    |
| Mapping-shim collision               | Two TS fields collapse onto one SQL column ; only Prisma catches this specific shape |

These bugs are **known locally** (every senior dev has seen one)
but **not mastered globally**. They share four characteristics that
make them hard to detect : invisible, delayed, distributed,
test-blind.

In one published audit, **23 of 47 endpoints had structural drift
while the test suite reported 100% passing for six months
straight**. In another reported incident, a simple type change
(`number` → `string` on `user_id`) passed every test and broke
roughly **30% of mobile users in production**.
(Source : *Your API Tests Are Lying to You*, DEV.to.)

The most expensive bugs are not the ones that crash. They are the
ones that look correct.

## Reproducible audit

The preview ships with a fixture set and an audit script that
re-runs the kernel against every fixture and asserts each output
matches a pinned `{status, reasons, fingerprint}`.

```bash
pnpm audit
# or
./audit/run-audit.sh
```

Determinism claim :

> Given identical inputs and a versioned kernel execution
> (VERIFY_VERSION = `v15.5-austere-1`), the kernel produces the
> same `status`, the same `reasons`, and the same `fingerprint` on
> every run, on every machine.

This is **not** a claim of determinism across kernel versions, across
different inputs, or under network failure.

## Limits (read first)

- **One pair of targets only in this preview** : TS ↔ SQL.
  GraphQL, OpenAPI, Terraform, RBAC, RLS are roadmap.
- **The IR shape (`SimpleIR`)** is a deliberate subset, not
  the production form.
- **No generic extractors yet** for arbitrary stacks. The IR has
  to be hand-written or generated by a stack-specific parser.
  The Cal.com case study uses a Cal.com-targeted Prisma parser,
  not a generic extractor.
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

The honest question being calibrated : **is the kind of cross-layer
drift Typerion catches something you'd want to catch automatically,
or does it feel like noise ?**

Sharp critique, counter-examples, and *"my stack already handles
this"* with a reproducible test are all welcome.

---

> **Typerion is not the system.**
> **It is what ensures your system remains one system.**

## License

[MIT](LICENSE) for the public surface.
