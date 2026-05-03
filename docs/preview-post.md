# Show HN draft — preview post

Two title options. Pick one before submitting.

## Title — Option A (safe, factual)

> Show HN: Detecting cross-target data inconsistencies before they hit production

## Title — Option B (sharper, recommended)

> Show HN: Your types are correct. Your database is correct. Your system is still broken.

---

## Body (paste this verbatim into the HN submission)

Hi HN,

This is an early preview of one piece of a system I'm building. Posting
because I'd rather know now if the idea is wrong than spend six months
proving it. There's a hosted endpoint and a shared preview token so you
can try it in 30 seconds without signup :

```bash
curl -s -X POST https://preview.typerion.dev/v1/verify \
  -H "Authorization: Bearer preview-token" \
  -H "Content-Type: application/json" \
  -d @- <<'JSON' | jq
{
  "baseline":  {"kind":"lossy-inline","value":{"entities":[{"name":"User","fields":[{"name":"email","type":"string"}]}]}},
  "candidate": {"kind":"lossy-inline","value":{"entities":[{"name":"User","fields":[{"name":"email","type":"string"},{"name":"emailAddress","type":"string","sqlName":"email"}]}]}}
}
JSON
```

The case:

```ts
interface User {
  email: string;
  emailAddress: string;
}
```

```sql
CREATE TABLE users (email VARCHAR NOT NULL);
```

The TypeScript compiles. The migration runs. Drizzle / Prisma /
TypeORM are all happy.

But the IR says the second field was annotated to map back to the
existing `email` column (legacy migration shim that never got
removed):

```json
{ "name": "emailAddress", "type": "string", "sqlName": "email" }
```

Two TS fields silently collapse onto one SQL column. At runtime, a
write to `user.emailAddress` overwrites `user.email`. Nothing in the
standard stack catches this — the type-checker sees two names, the
migration tool sees one column, neither checks the cross-projection
invariant.

I built a small kernel that takes a baseline IR and a candidate IR
and verifies the candidate's TS projection agrees with its SQL
projection on names, presence, and types. The output for the case
above:

```
status: fail
reasons:
  - Entity 'User' field 'emailAddress' projects to TS name 'emailAddress'
    but SQL name 'email' — runtime writes to TS field 'emailAddress'
    will not reach SQL column 'email'.
  - Entity 'User' has multiple fields collapsing into SQL name 'email'
    (logical fields: 'email', 'emailAddress') — only one survives at
    runtime, causing silent data loss.
```

That's it. One check, one pair of targets.

Limits, up front:

- TS ↔ SQL only. No GraphQL / OpenAPI / RBAC / RLS in this preview.
- The IR shape is a deliberate subset.
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

  https://github.com/<org>/typerion-oss

If you try it on a case from your codebase and something breaks (the
demo, the framing, your assumptions), please file an issue with the
failing IR. That feedback is the entire reason for posting.

Thanks for reading.

— [name]

---

## Pre-submission checklist

- [ ] Title chosen (A or B)
- [ ] Public URL of typerion-oss inserted (replace `<org>`)
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

If kill-switch trips: stop. Do not push back. Document what you saw.
Decide whether to address or pivot in writing, then proceed.
