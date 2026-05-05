/**
 * @typerion/cli — entry point.
 *
 * Preview scope :
 *   init     scaffold a new Typerion project (local)
 *   verify   verify an IR pair against the kernel (thin wrapper
 *            around the hosted endpoint — kernel still runs
 *            server-side ; local-mode CLI with the kernel binary
 *            on your machine is the most-requested next step
 *            and not in this preview)
 *
 * The rest of the surface (build, enforce, deploy-check) lands
 * post-preview.
 */

import { runInit } from "./commands/init.js";
import { runVerify } from "./commands/verify.js";

const PACKAGE_VERSION = "0.0.1";

const HELP = `typerion ${PACKAGE_VERSION} — cross-target coherence verifier

Usage:
  typerion <command> [options]

Available commands:
  init <dir>           Scaffold a new Typerion project in <dir>
  verify <file.json>   Verify an IR pair against the kernel
  help                 Show this message
  version              Print the CLI version

Server-bound commands (coming up):
  build           Generate coherent targets from one source
  enforce         Apply policy at runtime
  deploy-check    Block unsafe merges at PR time

Quick try :
  typerion verify ./audit/fixtures/case-04-trigger-column-orphan.json

Decisions live on the kernel ; the CLI is the door.
`;

export async function run(argv: readonly string[]): Promise<number> {
  const [command, ...rest] = argv;

  if (!command || command === "help" || command === "--help" || command === "-h") {
    process.stdout.write(HELP);
    return 0;
  }

  if (command === "version" || command === "--version" || command === "-v") {
    process.stdout.write(`${PACKAGE_VERSION}\n`);
    return 0;
  }

  if (command === "init") {
    return runInit(rest);
  }

  if (command === "verify") {
    return runVerify(rest);
  }

  // Forward-stub for upcoming server-bound commands. They print a
  // helpful message rather than an obscure "unknown command" error.
  const SERVER_COMMANDS: ReadonlySet<string> = new Set([
    "build",
    "enforce",
    "deploy-check",
    "login",
    "logout",
    "whoami",
  ]);
  if (SERVER_COMMANDS.has(command)) {
    process.stderr.write(
      `typerion: \`${command}\` lands post-preview. Server release in progress.\n` +
        `For updates: https://typerion.dev\n`,
    );
    return 2;
  }

  process.stderr.write(`typerion: unknown command \`${command}\`\n\n${HELP}`);
  return 64; // sysexits EX_USAGE
}
