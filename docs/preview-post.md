# Show HN draft — preview post

Two title options. Pick one before submitting.

## Title — Option A (safe, factual)  — 70 chars

> Show HN: Catching TS/SQL drift that compilers and migrations both miss

## Title — Option B (sharper, recommended)  — 62 chars

> Show HN: Types correct. Database correct. System still broken.

---

## Body (paste this verbatim into the HN submission)

Hi HN,

This is an early preview of one piece of a system I'm building. Posting
because I'd rather know now if the idea is wrong than spend six months
proving it. There's a hosted endpoint and a shared preview token so you
can try it in 30 seconds without signup :

```bash
curl -s -X POST https://typerion-v1-typerion-server-r3wh.vercel.app/v1/verify \
  -H "Authorization: Bearer pat_typerion_preview_demo_2026_05" \
  -H "Content-Type: application/json" \
  -d @- <<'JSON' | jq
{
  "baseline":  {"kind":"lossy-inline","value":{"entities":[{"name":"Session","fields":[{"name":"id","type":"string"},{"name":"userId","type":"string"},{"name":"expiresAt","type":"date"}]}]}},
  "candidate": {"kind":"lossy-inline","value":{"entities":[{"name":"Session","fields":[{"name":"id","type":"string"},{"name":"userId","type":"string"},{"name":"expiresAt","type":"date"},{"name":"lastSeenAt","type":"date","excludeFromTs":true}]}]}}
}
JSON
```

The case — a DB-trigger column the application doesn't model :

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

A DBA on a previous team added the column via an out-of-band
migration with a trigger. The application code was never updated.
The migration ran. The trigger works. Every TS type-checker on
earth approves the interface. Every ORM (Prisma / Drizzle /
TypeORM) is structurally **unable** to catch this, because the
column isn't part of the ORM's view of the schema — it's a
category they don't model.

Six months later, a junior writes a raw SQL query that reads
`sessions.last_seen_at` and the result lands in a TS variable
typed as something the column doesn't actually carry. On staging
the column exists ; on dev it doesn't ; the bug surfaces
intermittently, weeks after merge.

The framing that matters : **individually valid, collectively
inconsistent**. The TS interface is valid. The SQL migration is
valid. Each tool checks its own projection against itself. Nothing
in the standard stack checks the cross-projection invariant.

I built a small kernel that takes a baseline IR and a candidate IR
and verifies the candidate's TS projection agrees with its SQL
projection on names, presence, and types. The output for the case
above :

```
status: fail
reasons:
  - Entity 'Session' field 'lastSeenAt' is present in SQL projection
    but excluded from TS — TS code cannot read or write this column,
    leading to silent NULLs or write failures.
```

That's one of six failure modes the audit fixtures cover. Five
others — virtual-property leak (TS-only), i18n alias collision
(TS-side), partial rename (`currentPeriodEnd ↔ current_period_end`),
legacy field-collision after migration shim, mid-flight rename —
are in [audit/fixtures/](https://github.com/wiaahmarketplace/typerion-oss/tree/main/audit/fixtures)
with narratives describing the production scenario each one is
drawn from.

Empirical tests of how Prisma / Drizzle / TypeORM handle the
collision case are in [examples/orm-coverage/](https://github.com/wiaahmarketplace/typerion-oss/tree/main/examples/orm-coverage)
— Prisma catches it (`P1012`), Drizzle silently drops the field,
TypeORM accepts it. None of the three catch the other five
fixtures.

That's it. One check, one pair of targets.

Limits, up front:

- TS ↔ SQL only. No GraphQL / OpenAPI / RBAC / RLS in this preview.
- The IR shape is a deliberate subset.
- **No extractors.** The IR has to be hand-written. That makes
  this preview a verification of the kernel decision logic, not
  a tool you can run against your real codebase yet.
- **Hosted-API only.** The kernel runs on a closed-source hosted
  endpoint. Senior engineers reviewing real schemas should not
  send production code to this preview — only test with the
  bundled fixtures or hand-written IRs. A local CLI mode is
  the most-requested next step.
- The kernel server is private. CLI and public IR types are MIT in
  the public repo; the verify logic itself isn't.
- No SLO, no guarantees. This is a preview, not a product.

What I'm trying to find out:

1. Whether *"my ORM already catches this"* is universally true or
   has gaps. If you can show me the exact ORM + version + config
   that catches the case above without manual schema review, I'd
   like to know.
2. Whether the *kind* of mutation that triggers a `fail` actually
   matches mutations engineers make in real codebases. If you've
   ever introduced a regression of this shape and shipped it, I'd
   like to read the post-mortem.
3. Whether the framing — *"types correct + database correct + system
   broken"* — lands or feels manufactured.

The repo with the example, the run script, and an issue template
that asks the right questions:

  https://github.com/wiaahmarketplace/typerion-oss

If you try it on a case from your codebase and something breaks (the
demo, the framing, your assumptions), please file an issue with the
failing IR. That feedback is the entire reason for posting.

Thanks for reading.

— [name]

---

## Pre-submission checklist

- [ ] Title chosen (A or B)
- [ ] Public URL of typerion-oss inserted (replace `wiaahmarketplace`)
- [ ] `typerion-server` deployed somewhere reachable, OR README clearly states "DM for access" path
- [ ] Issue template visible at `.github/ISSUE_TEMPLATE/preview-feedback.md`
- [ ] No claims I can't substantiate within 30 seconds
- [ ] Disclaimer ("early preview, no guarantees") visible above the fold
- [ ] No marketing terms ("platform", "engine", "infrastructure", "future of")
- [ ] No pricing, no signup, no waitlist

## Within 24-72h after submission — capture loop

Watch for these in comments and capture each in `docs/preview/feedback.md`:

| Signal class | Example |
|---|---|
| **A — respect** | *"X is wrong because Y, here's a counter-example"* |
| **B — usage intent** | *"I would use this on my project"*, *"this would have caught X"* |
| **C — behavioral** | clone in stars, fork with commits, issue with concrete IR |
| **Kill switch** | *"already solved by X"* (≥ 2 independent), 30+ comments without correct restatement, forks without usage |

Do not engage with *"interesting"*, *"cool idea"*, *"impressive"* —
those are noise. Engage with concrete counter-examples and concrete
proposed cases.

## Response patterns (use these verbatim or close)

For each comment class, one canonical response. Do **not** improvise
under pressure — improvising is how a thread becomes a debate
instead of a discovery.

| Comment class | Canonical response |
|---|---|
| *"My ORM catches this"* | *"Nice — which ORM + version + config? I'd love to add it as a passing case in the README and credit you."* |
| *"This is just schema validation / already solved"* | *"Do you have a concrete example or tool that checks TS ↔ SQL coherence on this exact case? I'd want to run the same fixture through it and compare."* |
| *"Interesting / cool idea"* | *"Do you have a concrete case from your codebase? I can try to run it through the verifier and show you what it returns."* |
| *"What about \<other target\> ?"* | *"Out of scope for this preview by design — only TS ↔ SQL. If the cross-target principle holds, \<other target\> is the next pair to support."* |
| *"Why a hardcoded preview token / where's auth?"* | *"This is a public preview token for the demo instance only — rate-limited and isolated. Real auth isn't the focus of this preview ; the kernel decision is."* |
| *"This won't scale / I see a perf issue"* | *"Agreed for this preview — single-region Fly.io machine, 256MB. Phase 6 chooses the runtime. Right now I'm testing whether the decision logic is correct, not whether it's fast."* |

Three rules for replying :

1. **Always pivot to a concrete case.** "Send me the IR / config /
   repo and I'll run it" beats every abstract debate.
2. **Never defend the architecture.** This is a preview to test ONE
   primitive. If someone debates infra / auth / pricing, redirect
   to the kernel question.
3. **Engage failure honestly.** If a counter-example breaks the
   demo, *"good catch — issue opened, will reply with what I find"*
   is infinitely stronger than *"actually that's by design"*.

If kill-switch trips: stop. Do not push back. Document what you saw.
Decide whether to address or pivot in writing, then proceed.
