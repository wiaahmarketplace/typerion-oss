# Preview feedback log

One row per public reaction during the preview window. Capture
verbatim quotes, not summaries — they're the only honest record.

| Date | Source | Quote (verbatim) | Class | Action |
|---|---|---|---|---|
| <!-- e.g. 2026-05-12 --> | <!-- HN id, X handle, GH user --> | <!-- "this would have caught a bug we shipped last quarter" --> | <!-- B / C --> | <!-- "follow up: ask for redacted IR" --> |

## Signal classes

- **A** — respect technique : critique avec contre-exemple, pas
  *"interesting"*
- **B** — intention d'usage déclarée : *"I would use this on…"*,
  *"this would have caught X"*
- **C** — behavioral signal : clone, fork avec commits, issue avec
  IR concret, run du demo script, contribution code

## Kill switch triggers (any one fires → STOP build)

- ≥ 2 independent commenters: *"already solved by X"* with no
  defensible counter-argument
- 30+ comments and no one restates the problem correctly → framing
  broken
- Forks happen but none branch on real cases → curiosity ≠ need

## Counter-tracking

For every *"my ORM catches this"*, log :

| Date | ORM + version | Config used | Verified caught? | Notes |
|---|---|---|---|---|

If three people independently demonstrate the case is caught by an
existing tool with default config, the demo case has to change.
