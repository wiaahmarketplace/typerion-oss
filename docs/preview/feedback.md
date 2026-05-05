# Preview feedback log

One row per public reaction during the preview window. Capture
verbatim quotes, not summaries — they're the only honest record.

| Date | Source | Quote (verbatim) | Class | Action |
|---|---|---|---|---|
| 2026-05-04 | GitHub @tkersey (831 followers — Tim Kersey, Principal Context Engineer @ Artium AI, ex-Pivotal Labs / VMware Tanzu / Carbon Five, ~30 yrs in software, active on functional.cafe, holds Codex Deployment Practitioner cert) | (no quote — repo star, no message) | C-weak (surface curiosity, not yet usage) — but high-relevance profile : Artium = consultancy building enterprise agentic systems, exact ICP overlap | DM via Mastodon @tk@functional.cafe with hook on AI-generated code drift across TS+SQL projections + ask which audit fixture (if any) matches a bug he's seen in client engagements |
| 2026-05-04/05 | GitHub @DoddiC (146 followers — Chidvi Doddi, GIS Developer @ PG&E Oakland, ex-Kafka admin Fidelity, BS UCSC + currently MS Georgia Tech, stack Python / Java / Apache ecosystem / PostgreSQL — no TS↔SQL ORM in scope) | (no quote — repo star, no message). Star landed during a bulk-star session of ~20 repos in 5 minutes around 05:34–05:39 UTC, majority AI/LLM/agents trending — typerion-oss got swept up, not deliberately evaluated | C-noise (drive-by bookmark, not curated curiosity) — low ICP fit + non-deliberate event | Observe only ; no DM (he likely wouldn't remember the repo) ; deduct from active-signal accounting |
| 2026-05-05 | Vinod Jaspa (Top Rated Upwork freelancer + Ph.D. researcher NPM security, Mohali Chandigarh India, GitHub @VinodJaspa) — contacted via DM after the user reached out personally | First : screenshot showing clone+run of canonical README curl (status:fail, 2 reasons, fingerprint 578f09fce81c380cb2abb303a0d253a8). Then verbal reply : "Never seen these in practice; they seem like pretty deep edge cases compared to the usual vulnerabilities I encounter. What I see is the actual malicious codes... the patterns that you have found is just a language and (SQL) specfic. I never seen this before." + offered exchange on his NPM security research (SSRN paper attached : "Decoding Security Incidents in NPM Repositories" — F1=0.781, validated on 1.7k packages) | Signal A negative (honest "never seen this" + scope critique "TS+SQL specific") — interpretable as : domain mismatch (his terrain = NPM supply chain malware, not multi-team TS↔SQL drift) rather than universal disqualification. NOT a kill switch (no "already solved by X", correct reformulation of problem). Useful informational data : bug profile rare outside wedge ICP. | Replied with : (a) thanked him for honest "never seen this" (rare and useful), (b) accepted the "narrow scope" critique without defensive (austere by design), (c) acknowledged paper rigor specifically without committing to read, (d) closed thread cleanly with door open. Lesson for next outreach : tighten pre-filter to require "production exposure in ≥50k TS LOC + SQL ORM + multi-year migration history" — Vinod is real senior dev but wrong wedge. |
| 2026-05-05 | Vinod Jaspa (follow-up after user redirected to substantive question about bug-profile match) | Verbatim : *"Never seen these in practice; they seem like pretty deep edge cases compared to the usual vulnerabilities I encounter. What I see is the actual malicious codes, that can harm the system and compromise the server. If you want to discover some of them want to learn my thoughts and research. I mean the patterns that you have found is just a language and (SQL) specific. I never seen this before."* + shared his SSRN paper link on NPM security. | **Signal B-negative HONEST** — concrete answer ("never seen this") with concrete reason (his domain = security/malicious code, not data coherence). Plus soft-pitch of his own research detected. NOT a kill switch (single voice from adjacent domain ≠ thesis broken). Useful calibration data : NPM security researchers ≠ Typerion ICP, wedge narrowness confirmed. | Reply polite + closing-of-loop : embrace the "narrow by design" framing, don't argue, don't engage with his paper/research, don't promise to read SSRN. Then : remove NPM security / supply-chain researcher profiles from prioritized DM list. Refine targeting toward **production engineers maintaining TS+SQL codebases multi-team multi-year** (where the bug-profile actually arrives). |
| 2026-05-05 | Giorgi Makharadze (GitHub @GiorgiMakharadze, Tbilisi Georgia, full-stack Node.js/Go/SQL+NoSQL ; possible LinkedIn @giomdeveloper at CARVID NYC, Penn State 2012-2016) — DM after personal outreach | Verbatim : *"this kind of TS ↔ SQL mismatch can be a real issue, especially in larger backend systems where DTOs/entities/migrations evolve separately and the ORM does not fully protect the actual database contract. I'll check the repo/demo first and give you honest feedback: whether the case feels realistic, whether Prisma/TypeORM/Drizzle would already catch it, and where I think the tool could be useful."* | **Signal B strong** — names the bug-mechanic precisely with prod vocabulary ("DTOs/entities/migrations evolve separately", "ORM does not fully protect the actual database contract"). Pre-commits to Signal A (ORM check) + Signal C (run demo) + assessment of usefulness. NETWORK-tagged, weight 0.85-0.9 (technical precision > politeness signal). | Reply with : (a) acknowledge his precision exceeds README's wording, (b) point to audit/fixtures as better material than canonical case for "feels realistic" check, (c) echo ORM bounty positively (catch credit), (d) zero-pressure close. Then : await his actual review — could produce 1st genuine Signal A (ORM verdict) + Signal C qualifying (run on his interpretation). |
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
