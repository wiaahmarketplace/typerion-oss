# Demo system — intent → generated → broken → caught

A 30-second walkthrough of the Typerion control plane on a small
Session entity. Four steps, end-to-end, reproducible.

```bash
./run-demo.sh
```

## What the demo shows

| Step | File | What happens |
|---|---|---|
| 1. **Write intent** | `01-intent.json` | One canonical declaration of the Session entity — the source of truth. |
| 2. **Generate system** | `02-generated.json` | The system as it should look, derived from intent. Verify : **pass**. |
| 3. **Break it** | `03-broken.json` | A DBA adds `last_seen_at` via an out-of-band migration. The TS code is never updated. The system is now silently inconsistent. |
| 4. **Watch Typerion catch it** | (kernel verdict) | Verify : **fail**. The drift is detected, explained, and the script exits with code 1 (CI gate signal). |

## What this demonstrates

- **Represent** : `01-intent.json` is the canonical model
- **Detect** : kernel finds the divergence between intent and the broken state
- **Explain** : human-readable reason on the affected field
- **Block** : non-zero exit code from the demo script — usable in CI

This is one slice of the full Typerion control plane. The complete
system extends across multiple sources (Prisma / OpenAPI /
Terraform / GitHub) and integrates with PR gates, audit logs, and
policy enforcement. This demo demonstrates the underlying primitive
on a hand-written IR. Run it on your own intent + drift to see
how it behaves on shapes that are realistic for your stack.

## Reproducibility

The kernel produces the same `fingerprint` for the same input on
every machine and every run, given the pinned `VERIFY_VERSION`. The
demo script exits with the kernel verdict — `0` on pass, `1` on
fail — so it's CI-usable as-is.

```bash
./run-demo.sh > /dev/null 2>&1
echo "exit code : $?"
```

## Files

```
README.md          this walkthrough
run-demo.sh        4-step orchestration
01-intent.json     canonical declaration
02-generated.json  generated system aligned with intent
03-broken.json     system with a SQL-side drift introduced
```

## Limits

- The "generated" state in step 2 is hand-aligned with the intent,
  not produced by a generator. The full Typerion projection engine
  (which derives backend / frontend / schema / API / infra from
  one `.tp` file) is not exposed in this preview. This demo
  validates that the verifier kernel correctly distinguishes
  aligned vs broken cases.
- The "broken" case is one drift pattern out of six the audit
  fixtures cover. See [`audit/fixtures/`](../../audit/fixtures/)
  for the others.
- This demo runs against the hosted preview endpoint. Don't send
  production schema data — only the bundled examples or
  hand-written IRs.

## What to do next

If the demo lands for you, the question we're calibrating is :

> Would you want this kind of cross-layer drift detection in your
> CI pipeline, or does it feel like noise ?

Open an issue with your verdict — sharp critique and counter-
examples especially welcome.
