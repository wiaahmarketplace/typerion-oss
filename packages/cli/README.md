# @typerion/cli

The Typerion CLI. Scaffolds projects locally, talks to the Typerion
server for everything that matters.

## Install

```bash
npm install -g @typerion/cli
# or
pnpm add -g @typerion/cli
```

(Not yet on npm. Clone the repo and run from `packages/cli/bin/typerion.mjs`
in the meantime.)

## Usage

```bash
typerion init <dir>      # scaffold a project
typerion help            # show all commands
typerion version         # print version
```

## What runs server-side

These commands are recognized but require the server release. Running
them today prints a forwarding message:

- `typerion verify` — *is this safe to ship?*
- `typerion build` — *generate every coherent target*
- `typerion enforce` — *apply policy at runtime*
- `typerion deploy-check` — *block unsafe merges at PR time*

For updates: [typerion.dev](https://typerion.dev).
