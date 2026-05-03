/**
 * `typerion init <dir>` — scaffold a new Typerion project.
 *
 * Writes:
 *   <dir>/typerion.json   minimal config
 *   <dir>/main.tp         starter declaration
 *
 * That's the entire local surface. Verification, codegen, enforcement
 * happen server-side. The success message points there.
 */

import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { basename, join, resolve } from "node:path";

const STARTER_TP = `// Typerion starter — declare entities, APIs, and policies.
// Server-side compilation generates types, schemas, and runtime
// guards from this single source.

entity User {
  id: string
  email: string
  createdAt: timestamp
}

api getUser(id: string) -> User
api createUser(email: string) -> User
`;

const STARTER_CONFIG = {
  name: "",
  schemaVersion: "0.1",
  main: "main.tp",
  // Server-side targets and policies are configured at typerion.dev.
  // This config stays minimal on purpose.
  comment: "Targets and policies are configured server-side at typerion.dev",
};

function usage(): string {
  return (
    "Usage: typerion init <dir>\n" +
    "\n" +
    "  <dir>   Directory to create. Must not already contain a typerion.json.\n"
  );
}

export async function runInit(argv: readonly string[]): Promise<number> {
  const dirArg = argv[0];
  if (!dirArg || dirArg.startsWith("-")) {
    process.stderr.write(usage());
    return 64;
  }

  const dir = resolve(process.cwd(), dirArg);
  const configPath = join(dir, "typerion.json");
  const tpPath = join(dir, "main.tp");

  if (existsSync(configPath)) {
    process.stderr.write(
      `typerion: ${configPath} already exists. Refusing to overwrite.\n`,
    );
    return 73; // sysexits EX_CANTCREAT
  }

  try {
    mkdirSync(dir, { recursive: true });
    const config = { ...STARTER_CONFIG, name: basename(dir) };
    writeFileSync(configPath, JSON.stringify(config, null, 2) + "\n", "utf8");
    writeFileSync(tpPath, STARTER_TP, "utf8");
  } catch (err) {
    process.stderr.write(
      `typerion: failed to scaffold ${dir}: ${(err as Error).message}\n`,
    );
    return 74; // sysexits EX_IOERR
  }

  process.stdout.write(
    `Initialized ${dirArg}/\n` +
      `  ${dirArg}/typerion.json\n` +
      `  ${dirArg}/main.tp\n` +
      `\n` +
      `Edit main.tp to declare your system.\n` +
      `\n` +
      `Server-side commands (coming up):\n` +
      `  typerion verify    — is this safe to ship?\n` +
      `  typerion build     — generate coherent targets\n` +
      `  typerion enforce   — apply policy at runtime\n` +
      `\n` +
      `Decisions live on the server. Stay tuned: https://typerion.dev\n`,
  );
  return 0;
}
