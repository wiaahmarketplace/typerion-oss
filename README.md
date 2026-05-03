# Typerion

> Software systems are no longer written. They are generated. And they
> drift in silence — across types, schemas, policies, infrastructure,
> and runtime — faster than anyone can review.
>
> **Typerion is a control plane that decides whether a system is safe
> to ship.**

---

## What this repo is

`typerion-oss` is the open-source **client surface** of Typerion: the
parser, the public IR types, a small set of single-target codegens,
and a CLI to drive them.

It is **explicitly not the whole product**.

The interesting decisions — *can I ship this? is this safe? does v2
break v1? what will break in 14 days?* — happen on the Typerion
server. The server consumes signals the client cannot reproduce
offline: cross-tenant drift patterns, signed historical decisions,
live infrastructure state, an independent cryptographic verifier.

Run the CLI locally to explore. Run `typerion login` to get answers.

---

## Quick start

```bash
npm install -g @typerion/cli       # not yet on npm — clone for now
typerion init my-app
cd my-app
cat main.tp
```

That's everything that runs locally today.

The full surface — `verify`, `build`, `enforce`, `deploy-check` —
talks to the server. Those commands are wired in upcoming releases.

---

## What you get from the OSS

- **`typerion init <dir>`** — scaffold a new project with a `main.tp`
  declaration file and `typerion.json` config.

That's it. By design.

## What you get from the server

- **`verify`** — does this change preserve coherence? Verdict + audit
  fingerprint, backed by an independent Rust kernel.
- **`build`** — generate every coherent target (TS, SQL, GraphQL,
  RBAC, RLS, OpenAPI, infrastructure) from one source.
- **`enforce`** — apply policy at runtime against live state.
- **`deploy-check`** — block unsafe merges before they hit prod.

Each of these depends on signals the client doesn't have. That's
not a limitation; that's the product.

---

## Why this split?

Modern stacks fail because **every layer is correct in isolation and
incoherent together**. Adding more codegens or running more local
checks doesn't help — if anything, it accelerates the divergence.

The fix is structural: a single canonical representation, an engine
that knows the cross-target invariants, and verifiers that observe
real systems in production. None of that fits in a CLI on your
laptop. All of it fits behind a stable API.

The OSS lets you read, parse, and explore. The server tells you
whether to ship.

---

## License

MIT. Use it, fork it, study it. The CLI and parser stay open
forever. The kernel, the verifier, the connectors, the heuristics
do not.

See [LICENSE](./LICENSE).

---

## Status

Early. The 1.0 surface is being designed in the open and will land
in `packages/` over the coming weeks. This README is the contract
for what the OSS will and will not do.

For updates: [typerion.dev](https://typerion.dev).
