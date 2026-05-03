/**
 * @typerion/cli — entry point.
 *
 * Phase 3 scope (typerion-oss minimal): one command, `init`. The rest
 * of the surface (parse, dev, generate, verify, build, enforce) lands
 * after Phase 4 — once the upstream private repo is locked down.
 *
 * Decisions about a system live server-side. The CLI is the door.
 */

import { runInit } from "./commands/init.js";

const PACKAGE_VERSION = "0.0.1";

const HELP = `typerion ${PACKAGE_VERSION} — control plane for software in the age of AI

Usage:
  typerion <command> [options]

Available commands:
  init <dir>      Scaffold a new Typerion project in <dir>
  help            Show this message
  version         Print the CLI version

Server-bound commands (coming with the server release):
  verify          Is this change safe to ship?
  build           Generate every coherent target from one source
  enforce         Apply policy at runtime
  deploy-check    Block unsafe merges at PR time

Run \`typerion init my-app\` to start. Decisions live on the server.
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

  // Forward-stub for upcoming server-bound commands. They print a
  // helpful message rather than an obscure "unknown command" error,
  // so a user discovering the surface understands what's coming.
  const SERVER_COMMANDS: ReadonlySet<string> = new Set([
    "verify",
    "build",
    "enforce",
    "deploy-check",
    "login",
    "logout",
    "whoami",
  ]);
  if (SERVER_COMMANDS.has(command)) {
    process.stderr.write(
      `typerion: \`${command}\` runs on the Typerion server. Server release coming up.\n` +
        `For updates: https://typerion.dev\n`,
    );
    return 2;
  }

  process.stderr.write(`typerion: unknown command \`${command}\`\n\n${HELP}`);
  return 64; // sysexits EX_USAGE
}
