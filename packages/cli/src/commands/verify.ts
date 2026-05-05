/**
 * `typerion verify <file>` — verify an IR pair against the kernel.
 *
 * Reads a JSON file containing `{ baseline, candidate }` (each in
 * the lossy-inline IRRef form) and posts it to the Typerion verify
 * endpoint. Exit code reflects the verdict so the command is usable
 * in CI scripts :
 *   0  status = pass
 *   1  status = fail
 *   2  status = uncertain (kernel could not decide — malformed IR)
 *  64  argv usage error
 *  74  IO error reading the file
 *  75  network/transport error
 *
 * **Scope honesty (preview window) :** this is a thin wrapper around
 * the hosted endpoint. The kernel still runs server-side. A real
 * local mode that runs the kernel binary on your machine is the
 * most-requested next step ; it's not in this preview. Do not send
 * production schema data to the hosted endpoint — only test with
 * fixture files or hand-written IRs.
 */

import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const DEFAULT_API = "https://typerion-v1-typerion-server-r3wh.vercel.app";
const DEFAULT_TOKEN = "pat_typerion_preview_demo_2026_05";

interface VerifyOutput {
  readonly status: "pass" | "fail" | "uncertain";
  readonly reasons: readonly string[];
  readonly fingerprint: string;
}

function usage(): string {
  return (
    "Usage: typerion verify <file.json>\n" +
    "\n" +
    "  <file.json>  JSON file with shape { baseline: IRRef, candidate: IRRef }\n" +
    "               where each IRRef is { kind: \"lossy-inline\", value: { entities: [...] } }\n" +
    "\n" +
    "Environment variables :\n" +
    "  TYPERION_API     Override the hosted endpoint (default : the preview instance)\n" +
    "  TYPERION_TOKEN   Override the auth token     (default : the public preview token)\n" +
    "\n" +
    "Exit codes :\n" +
    "  0  pass        Cross-target coherence check passed\n" +
    "  1  fail        At least one inconsistency detected (reasons printed)\n" +
    "  2  uncertain   Kernel could not decide (malformed IR — message printed)\n" +
    "\n" +
    "Scope : this is a thin wrapper around the preview's hosted kernel. The\n" +
    "kernel runs server-side. Local-mode CLI (kernel binary on your machine)\n" +
    "is the most-requested next step ; it is not in this preview. Do not send\n" +
    "production schema data to the hosted endpoint — only fixtures or\n" +
    "hand-written IRs.\n"
  );
}

function readJsonFile(path: string): unknown {
  const absolute = resolve(process.cwd(), path);
  const raw = readFileSync(absolute, "utf8");
  return JSON.parse(raw);
}

function isVerifyInput(value: unknown): boolean {
  if (typeof value !== "object" || value === null) return false;
  const v = value as Record<string, unknown>;
  return "baseline" in v && "candidate" in v;
}

function colorize(s: string, code: number): string {
  if (!process.stdout.isTTY) return s;
  return `\x1b[${code}m${s}\x1b[0m`;
}

function formatStatus(status: VerifyOutput["status"]): string {
  switch (status) {
    case "pass":
      return colorize("pass", 32);
    case "fail":
      return colorize("fail", 31);
    case "uncertain":
      return colorize("uncertain", 33);
  }
}

export async function runVerify(argv: readonly string[]): Promise<number> {
  const fileArg = argv[0];
  if (!fileArg || fileArg.startsWith("-")) {
    process.stderr.write(usage());
    return 64;
  }

  let parsed: unknown;
  try {
    parsed = readJsonFile(fileArg);
  } catch (err) {
    process.stderr.write(
      `typerion verify: cannot read ${fileArg}: ${(err as Error).message}\n`,
    );
    return 74;
  }

  if (!isVerifyInput(parsed)) {
    process.stderr.write(
      `typerion verify: ${fileArg} is not a valid input. Expected an object with both 'baseline' and 'candidate' fields.\n`,
    );
    return 64;
  }

  const api = process.env["TYPERION_API"] ?? DEFAULT_API;
  const token = process.env["TYPERION_TOKEN"] ?? DEFAULT_TOKEN;

  let response: Response;
  try {
    response = await fetch(`${api}/v1/verify`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(parsed),
    });
  } catch (err) {
    process.stderr.write(
      `typerion verify: network error calling ${api}: ${(err as Error).message}\n`,
    );
    return 75;
  }

  if (!response.ok) {
    const text = await response.text().catch(() => "(no body)");
    process.stderr.write(
      `typerion verify: HTTP ${response.status} from ${api}: ${text}\n`,
    );
    return 75;
  }

  let result: VerifyOutput;
  try {
    result = (await response.json()) as VerifyOutput;
  } catch (err) {
    process.stderr.write(
      `typerion verify: invalid JSON in response: ${(err as Error).message}\n`,
    );
    return 75;
  }

  process.stdout.write(`status: ${formatStatus(result.status)}\n`);
  if (result.reasons.length > 0) {
    process.stdout.write("reasons:\n");
    for (const reason of result.reasons) {
      process.stdout.write(`  - ${reason}\n`);
    }
  }
  process.stdout.write(`fingerprint: ${result.fingerprint}\n`);

  switch (result.status) {
    case "pass":
      return 0;
    case "fail":
      return 1;
    case "uncertain":
      return 2;
  }
}
