---
name: Preview feedback
about: Tell me what broke (or didn't)
labels: preview-feedback
---

## What did you try?

(Paste the IR or describe the mutation. The more specific, the more useful.)

```json
{
  "entities": [...]
}
```

## What did Typerion say?

(Paste the verify output, or "I couldn't run it because…")

## What did you expect?

- [ ] I expected `pass`. Typerion said `fail`. Here's why I think it should pass:
- [ ] I expected `fail`. Typerion said `pass`. Here's the case it missed:
- [ ] I expected an error and got one, but the reason wasn't readable.
- [ ] I tried to run it and the server / CLI broke before responding.

## What does your real stack catch this with?

(Or: it doesn't, which is the more interesting answer.)

```
ORM:           e.g. Drizzle 0.x / Prisma 5.x / TypeORM / SQLAlchemy / hand-written
Type-checker:  TS 5.x / strict / etc.
Migration:     drizzle-kit / prisma migrate / sqitch / atlas / hand-written
```

## Anything I should fix in the framing?

(If the README led you to expect something different from what happened, say so.)
