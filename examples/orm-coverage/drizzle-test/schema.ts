// Canonical Typerion case-01 translated to a Drizzle schema.
//
// Two TypeScript fields whose Drizzle column-name argument is "email" :
//   - email
//   - emailAddress (also mapped to "email")
//
// Expected behavior (verified 2026-05-05) :
//   - `drizzle-kit check` reports : "Everything's fine 🐶🔥"
//   - `drizzle-kit generate` produces a migration with only ONE column
//     (the second field is silently dropped from the SQL output)
//
// This is silent data loss at codegen time : the TypeScript schema
// declares 2 fields, but the database will only ever have 1 column.
// Writes to user.emailAddress will not generate a corresponding
// SQL column at all.

import { pgTable, serial, varchar } from "drizzle-orm/pg-core";

export const user = pgTable("user", {
  id: serial("id").primaryKey(),
  email: varchar("email", { length: 255 }).notNull(),
  emailAddress: varchar("email", { length: 255 }).notNull(),
});
