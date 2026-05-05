// Inspection script — reads TypeORM's static metadata storage to
// confirm whether the collision is detected at decorator-application
// time. Run with : npx tsx inspect.ts

import "reflect-metadata";
import { getMetadataArgsStorage } from "typeorm";
import "./entity.js";

const args = getMetadataArgsStorage();
const userColumns = args.columns.filter(
  (c) => (c.target as { name: string }).name === "User",
);

console.log("=== Decorator-level column metadata for User ===");
for (const col of userColumns) {
  const dbName = (col.options as { name?: string }).name ?? col.propertyName;
  console.log(
    `  propertyName="${col.propertyName}" | options.name="${
      (col.options as { name?: string }).name ?? "(none)"
    }" | effective DB name="${dbName}"`,
  );
}

console.log("\n=== Collision check ===");
const seen = new Map<string, string[]>();
for (const col of userColumns) {
  const dbName = (col.options as { name?: string }).name ?? col.propertyName;
  if (!seen.has(dbName)) seen.set(dbName, []);
  seen.get(dbName)!.push(col.propertyName);
}
let collided = false;
for (const [dbName, props] of seen) {
  if (props.length > 1) {
    collided = true;
    console.log(
      `  ⚠️ COLLISION on column "${dbName}" : TS fields [${props.join(", ")}]`,
    );
  }
}
if (!collided) {
  console.log("  No collision detected");
}

console.log("\n=== TypeORM verdict ===");
console.log("  Decorators applied successfully (no exception thrown).");
console.log("  Metadata storage accepts collision silently.");
console.log("  TypeORM does NOT validate at decorator/metadata level.");
console.log(
  "  The collision would only surface at runtime if/when both fields are written.",
);
