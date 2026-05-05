# @typerion/cli

The Typerion CLI. Verifies cross-target coherence on an IR pair.

## Install

```bash
npm install -g @typerion/cli
# or
pnpm add -g @typerion/cli
```

(Not yet on npm. Clone the repo and run from
`packages/cli/bin/typerion.mjs` in the meantime.)

## Usage

```bash
typerion init <dir>           # scaffold a project
typerion verify <file.json>   # verify an IR pair against the kernel
typerion help                 # show all commands
typerion version              # print version
```

## `typerion verify`

Reads a JSON file with shape `{ baseline, candidate }` (each in the
`lossy-inline` IRRef form) and posts it to the kernel. The verdict
prints to stdout and the exit code reflects the status :

| Exit | Status      | Meaning                                              |
|------|-------------|------------------------------------------------------|
| 0    | `pass`      | Cross-target coherence check passed                  |
| 1    | `fail`      | At least one inconsistency detected (reasons listed) |
| 2    | `uncertain` | Kernel could not decide — malformed IR               |
| 64   | usage error | Wrong/missing argument                               |
| 74   | IO error    | Cannot read the file                                 |
| 75   | network     | Cannot reach the endpoint                            |

Quick try against a bundled fixture :

```bash
node bin/typerion.mjs verify \
  ../../audit/fixtures/case-04-trigger-column-orphan.json
```

### Environment

- `TYPERION_API` — override the endpoint (default : the preview
  instance at `typerion-v1-typerion-server-r3wh.vercel.app`)
- `TYPERION_TOKEN` — override the auth token (default : the public
  preview token `pat_typerion_preview_demo_2026_05`)

## Scope honesty

This is a thin wrapper around the preview's hosted kernel. The
kernel still runs server-side ; the CLI just removes the friction
of crafting curl JSON by hand.

A real local mode that runs the kernel binary on your machine is
the most-requested next step (so production schemas don't have
to leave your environment to be checked). It's not in this
preview. **Do not send production schema data to the hosted
endpoint** — only test with the bundled fixtures or
hand-written IRs.

## Server-bound commands (post-preview)

These commands print a forwarding message today :

- `typerion build` — generate coherent targets from one source
- `typerion enforce` — apply policy at runtime
- `typerion deploy-check` — block unsafe merges at PR time

For updates : [typerion.dev](https://typerion.dev).
