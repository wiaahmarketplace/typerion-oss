# ORM coverage — empirical test of the canonical case

Reproducible tests of how Prisma, Drizzle, and TypeORM each handle
the canonical Typerion case-01 fixture : two TypeScript fields whose
SQL projection lands on the same column.

```ts
interface User {
  email: string;        // → SQL column "email"
  emailAddress: string; // → SQL column "email" (via @map / { name } / sqlName)
}
```

## Findings (2026-05-05)

| ORM             | Behavior on this exact case                                 | Verdict                             |
|-----------------|-------------------------------------------------------------|-------------------------------------|
| **Drizzle Kit** | `drizzle-kit check`: *"Everything's fine 🐶🔥"*. `drizzle-kit generate` produces a migration with only **one** column — second field silently dropped. | ❌ silent data loss at codegen      |
| **TypeORM**     | Decorators apply without error. Metadata storage accepts the collision. No validation pass detects it. | ❌ runtime risk, no static check    |
| **Prisma**      | `prisma validate` raises `P1012 — Field 'emailAddress' is already defined on model 'User'`. Verified across versions 4.x → 7.x. | ✅ catches **this specific case**   |

Prisma catches the SQL-column collision case via field-name
normalization. The other five Typerion fixture categories (phantom
TS-only fields, phantom SQL-only fields, projection-name divergence,
i18n alias collisions on the inverse axis, partial renames after
normalization) are not validated by any of the three at static
analysis time.

**Different ORMs catch different subsets of inconsistencies. None
provide cross-representation validation across all cases.** Typerion
checks the cross-target invariant at the IR level, before runtime,
independently of which ORM you use.

## How to reproduce

Each subdirectory is self-contained with the schema/entity/migration
required to reproduce the result. See per-test README.

```
prisma-test/    schema.prisma   + captured `prisma validate` output
drizzle-test/   schema.ts       + captured `drizzle-kit generate` output
typeorm-test/   entity.ts       + captured metadata-storage inspection
```

## Honest scope

These tests cover **only case-01** (the canonical email/emailAddress
collision). They do not test the other 5 fixtures in `audit/fixtures/`
against each ORM — that would require translating each fixture into
each ORM's schema language, which is a larger effort. If you have
time and curiosity to extend this matrix, the contribution would be
valuable — open an issue with your findings.
