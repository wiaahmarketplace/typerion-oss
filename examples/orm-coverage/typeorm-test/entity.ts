// Canonical Typerion case-01 translated to a TypeORM entity.
//
// Two TypeScript fields :
//   - email (default mapping → SQL column "email")
//   - emailAddress with @Column({ name: "email" }) → also SQL column "email"
//
// Expected behavior (verified 2026-05-05) :
//   - The decorators apply without error.
//   - getMetadataArgsStorage().columns shows both fields with the
//     same effective database name.
//   - TypeORM does NOT validate at decorator/metadata level.
//   - The collision would surface at runtime when both fields
//     are written, with the second write overwriting the first.

import "reflect-metadata";
import { Entity, PrimaryGeneratedColumn, Column } from "typeorm";

@Entity()
export class User {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ type: "varchar" })
  email!: string;

  @Column({ type: "varchar", name: "email" })
  emailAddress!: string;
}
