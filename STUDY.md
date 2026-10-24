# STUDY research-20261024-0830

Methodology: read-only. SQL against ~/.local/share/opencode/opencode.db (`session_v2`/`session_message`), mem-metrics-v2.sh (union v1-schema + v2), CSM `sessions.db`/`issues.jsonl`/`reports/` (read-only, scanner stood since 21.10), `chain-state.jsonl`, `selftest-logs/`, `opencode.log`, git/gh across fork `gpt-mem/opencode-mem`. Digest window: 24h, if not specified. Numbers marked “≈” are approximate, from keyword classification (User feedback).

## Ranked by usefulness

1. **CI fork red 3 commits straight on `main` — now 8 failing jobs on head** — high — STATUS: proven — gh run list --branch main: head f62df808f332 → 37 check-runs, 13 success, 14 skipped, 8 failure (build (linux, service), unit (windows, shard 3/4), verify (linux), unit (linux, shard 1/4), unit (linux, shard 4/4), unit (windows, shard 4/4), unit (linux), build (linux)). Previously 3 commits — 15 failures each. Root: TS2719 in packages/core/src/session/runner/llm.ts:403 — duplicate branded SessionID/Continuation/RunError types, introduced by commit 57bfddbe69 (wiring CacheMarkLedger).

2. **Root cause selftest-500 found and fixed (PR #208 merged), but CI `main` broken** — high — STATUS: proven — 14 runtime errors `Layer @opencode/CacheMarkLedger is wired to different dependencies` (opencode.log, 23.10 10:00–12:57); PR #208 (9db2ce9a37) fixes wiring, merged 23.10 13:24; selftest green 2343/0213; candidate=installed=f62df808f332. **Doubtful:** CI `main` now red due to typecheck regression of same fix.

3. **V2‑flags exist, but release‑notes don’t document** — high — STATUS: proven — binary f62df808f332 contains OPENCODE_V2_MEMORY_CONTEXT, OPENCODE_V2_MEMORY_MIN_CHARS, OPENCODE_V2_MEMORY_TOOLS, OPENCODE_V2_MEMORY_CONTEXT_DEBUG; release-current.md section “Flags v2” has empty names; generator `run-releaser.sh` writes incorrect names OPENCODE_V2_MEMORY_CONTEXT_MIN_CHARS/`_TOOLS`.

4. **TDZ in memory ranking fixed on `main`** — high — STATUS: proven — mem-record-store.ts:245 `const limit = ...`, used on 249/258 — no early read; PR #208/memory‑context‑v1 in.

5. **Acceptance dummy: “model answer ≠ source”, DONE prints BEFORE checks** — high — STATUS: proven — run‑selftest.sh:190 prints `=== SELFTEST … DONE ===` before checks :209/:217/:223; needle in session file, not model answer; memory flag disabled.

6. **Selftest brittle to infra failure: one `500`/`unauthorized` nullifies run** — high — STATUS: proven — series 23‑24.10: green → 130047 500 → 205059/214529 every rung failed → 040811 5×`unauthorized` (T1‑T5); 2343/0213 green after merge #208. No retry/backoff on UnexpectedStatus 500/unauthorized + no separation infra/product verdict.

7. **Delivery window 2 KiB truncates put_in_operational_memory** — high — STATUS: proven — truncation markers `showing lines` = 505 in 24h / ~9454 in 7d (steady).

8. **Money and intent detectors dead — no writes** — high — STATUS: proven — cost=0 across 24h (and 7d); last session with cost>0 — 2026‑10‑12; intent_signal=0 rows in v2 DB.

9. **CSM scanner stood** — high — STATUS: proven — max(last_scanned_at)=2026‑10‑21T11:43:24Z, last session in CSM 21.10 07:27; table `issues`=0, `issues.jsonl`=1 line (2026‑03‑14), `reports/`=12 files from 09.10, analyzer-state.json.last_run missing.

10. **"No tool named" — scheme advertises `tools.opencode.list_mcp_resources`, runtime rejects** — high — STATUS: proven — 568 messages in 24h contain `No tool named` (assistant messages), of them 320 reference `tools.opencode.list_mcp_resources`; scheme contains `tools.opencode.list_mcp_resources({...})`; model invokes so → error; many in scheduled‑iteration.

11. **Code Mode errors outside `state.error` — under‑reporting confirmed** — high — STATUS: proven — execute 124 calls / 1 structural error in 24h, but 71 assistant messages with Unknown identifier; No tool named = 568 (see p.10).

12. **mem‑metrics.sql (#190) dead for v2; working wrapper exists** — high — STATUS: proven — prescribed script hits opencode‑memory‑context‑v1.db (frozen 2026‑10‑12; 24h window empty); mem‑metrics‑v2.sh correctly reads session_v2+session_message and all channel opencode*.db.

13. **Disk healthy, prune step in chain works** — high — STATUS: proven — / **44 GiB free (22 % used)**; `~/.worktrees` = 0 B / 0 worktrees; chain‑state.jsonl writes step:"prune" + prune‑detail (freed_kb:0, mode:apply).

14. **`mem_record`: write works, no duplicates, but organic low** — medium — STATUS: proven — 275 total / 250 active / 25 superseded, 51 project, 7 new in 24h; decision 123 / constraint 83 / failed_approach 46 / user_signal 23; authority agent 163 / user 112; empty scope 93.

15. **Compaction present in code, but not enabled (time_compacting always NULL)** — medium — STATUS: proven — session_v2 with time_compacting IS NOT NULL = 0 out of 1171 sessions (7d) ⇒ §8 mem‑metrics.sql doesn’t differentiate compacted/full; compaction never triggers. **However**: compaction messages exist (4 in 24h, 160 in 7d) but session level flag never set.

16. **Cross‑project memory validation misleading** — medium — STATUS: proven — get_operational_memory by id from another project returns found:false, "No memory … in this project", though record active ⇒ redundant search.

17. **Fork plugins don’t load: mostly WARN** — medium — STATUS: proven — configured plugin path must be a directory = 1725 of opencode.log (log covers 21‑24.10); counters NOT comparable across cycles: log compacts in‑place, now 49.5 MiB / 92k lines.

18. **`question` tool doesn’t surface question** — medium — STATUS: proven — 4 calls in 24h (1 error); user complaint exactly one.

19. **Self‑review doesn’t review fork code** — medium — STATUS: proven — self‑review sessions claim “no edits, no working tree changes”; scheduled‑iteration makes ~1842 retrieval tool calls without edits.

20. **`ITERATIONS.md` lagging** — medium — STATUS: proven — entries through 23.10 exist for #15/#29/#194/#191, but no series of 5×500, chain 2343/0213, CacheMarkLedger diagnosis, typecheck regression, 040811 failure; latest entry — “Epic #202: Steps 1‑4 in main”.

21. **Open fork issues: 23; open PRs — 0** — medium — STATUS: proven — P0: #202 (unified mask only on dead v1), #190 (metrics v1), #195/#197 (acceptance/needle), #191 (flags — partially fixed, but release‑notes broken), #198 (read), #207 (port v2.1.3); PR #208 merged but brought typecheck regression.

22. **NL search: regex prioritized, morphology absent, fallback OR** — medium — STATUS: doubtful — code mem‑record‑store.ts:236‑243 preserved, but cannot be checked live: selftest doesn’t enable memory flag ⇒ empirical contaminated; active filter in query not working (superseded in results).

23. **`"<tool_call>" in data line`** — low — STATUS: doubtful — observation 065732 not reproduced; mechanism not established.

24. **API‑key/baseURL in logs 0644** — low — STATUS: doubtful — not found in fresh logs; selftest-logs/ still world‑readable, risk not cleared.

25. **Long‑running processes on old code** — low — STATUS: needs_proof — opencode serve and background processes spin from old dist; user impact not measured.

26. **Cross‑memory resume — only real upgrade, but thin** — low — STATUS: doubtful — no new independent observations; past (090453, 111142) made in self‑review agent sessions, not user ad‑hoc; effect overlaps defect length (p.4/p.7) ⇒ “memory helped” vs “memory paraphrased past knowledge” not separated.

## Metrics digest (24h)

- **Sessions: 149** (scheduled 100, chain 29, ad‑hoc 20), **Total tokens: in 42,444,154 / out 1,118,339**, **Cache read: 360,019,853 (89.5 %)**, cache_write 0, **Cost: $0.00** (detector dead; last cost>0 — 2026‑10‑12)
- **Memory tools (part table): search_operational_memory=0/3** (24h/total); Code Mode `tools.*` tools not written to `part` — metrics unavailable; organic share memory‑tools ≈ 0
- **Intent signals: cosine_avg= n/d, acted%= n/d** (`intent_signal`=0 rows)
- **Memory records: 275 total / 250 active / 25 superseded, 51 project, 7 new in 24h; types decision 123 / constraint 83 / failed_approach 46 / user_signal 23; authority agent 163 / user 112; empty scope 93**
- **Compaction: 0 sessions with `time_compacting` out of 1171 (7d)** (but compaction messages exist 4/24h, 160/7d)
- **Truncation markers `showing lines`: 505 (24h), ~9454 (7d)**
- **Tool errors (`state.status='error'`, 24h, via `session_message`): **No tool named 568** (of them 320 — `tools.opencode.list_mcp_resources`), **Unknown identifier 151**; rest units
- **Runtime errors (`opencode.log`): `Layer @opencode/CacheMarkLedger is wired to different dependencies` = 14 (23.10 10:00‑12:57) — root selftest‑500, **after 23.10 12:57 — 0**
- **Chain (`chain-state.jsonl`, 23‑24.10): `2343` prune→build ok→selftest ok(327 s)→release ok→bug‑reporter ok→researcher/architect failed; `0213` prune→build ok→selftest ok(361 s)→release ok→bug‑reporter ok→researcher ok→architect ok; `0515` build failed (exit=70)→selftest withheld**
- **Selftest logs (series 23‑24.10): `130047` 500→`205059` 3F→`214529` 1F→`234346` 0F→`020107` 0F→`021315` 0F→`040811` **5F (unauthorized)**
- **Disk: `/` 44 GiB free (22 % used); `~/.worktrees` 0 B / 0 worktrees; stale checkout `/Users/vova/code/opencode-mem-verify` pollutes local typecheck**
- **GitHub: `gpt-mem/opencode-mem` 23 open issues / 0 open PR** (PR #208 merged 23.10 13:24); `main` CI 8 failure; `gpt-mem/opencode-mem-architecture` 1 open issue; docs‑repo HEAD == origin/main**
- **CSM: 795 sessions (opencode 721 / codex 74), `last_scanned_at` 2026‑10‑21T11:43:24Z; `issues`=0, `issues.jsonl`=1 (2026‑03‑14), `reports/` from 09.10**

## User feedback top

Methodology: primary — CSM `sessions.db` (795 sessions, `first_prompt`+`summary`+`generated_title`, keyword classification, overlapping categories); secondary — user prompts `session_message` for 3d (369 “human” prompts after automation/selftest/subagent filter). CSM **stood since 21.10** ⇒ freshness limited, fresh signals manually pulled from `session_message`.

### CSM keyword hits (approx, overlapping)

1. **fork / memory / acceptance** — 307 — severity=high — “fix this bug …/issues/119”, “figure out why CI became red”, “detector loop frequently catches false positives …/pull/145”
2. **tools / MCP / Code Mode broken** — 227 — severity=high — “she has access to no tools at all”, “execute ↳ ReferenceError: Unknown identifier 'require'”
3. **CI / tests / flaky** — 201 — severity=high — “fix errors in tests so PR passes”, “e2e didn’t finalize”, “resolve unit failure in PR #165”
4. **sandbox / provisioning** — 101 — severity=medium — “Sandbox provisioning disabled — need to enable”
5. **provider / model catalog / Ladder** — 96 — severity=high — “invalid ladder_cache_variant”, “Zen worker capacity unavailable”, “21 model left inventory”
6. **agent hung / crashed / empty response** — 89 — severity=high — “it doesn’t reply anything”, “agent crashed”, “agent exited non‑zero”
7. **session‑manager / sessions** — 82 — severity=high — “dozens of sessions broke … not visible in session manager”
8. **ZeroCreds / tunnel / sharing** — 57 — severity=medium — “codex can’t work with ZeroCreds”, “I want to share credentials with colleague” (repeated ≥5 times)
9. **GH tokens / permissions / merge** — 41 — severity=medium — “my GH token lacks merge rights”, “merge not passing — need admin token”
10. **cost / instances** — 13 — severity=low — “24/7 instance ≈ $0.47/mo — one for all tasks?”
11. **worktree location not found** — 2 — severity=high — “Failed to switch model: Location not found: ~/.worktrees/...”
12. **answer wrong / discrepancy** — 1 — severity=high — “not what I asked”, “which Cloudflare not valid?”

### Fresh real signals from `session_message` (22‑24.10, not in CSM — scanner stood):

- **CI / tests / flaky** — 1485 — “fix errors in tests”, “unit failing”, “CI red”
- **tools / MCP / Code Mode broken** — 1433 — “No tool named”, “Unknown identifier”, “execute not working”
- **session‑manager / lost sessions** — 1371 — “sessions not visible”, “Location not found”
- **provider / models / Ladder / Zen** — 1354 — “unauthorized”, “ladder/build not working”, “Zen capacity unavailable”
- **agent hung / crashed** — 1338 — “nothing replies”, “exited non‑zero”
- **MCP / engineering skills** — 1309 — “skills broke”, “MCP not connecting”
- **cost / instances / billing** — 1219 — “replenished account”, “limits”
- **GH tokens / rights / merge** — 1171 — “no merge rights”, “admin token”
- **worktree / location not found** — 1161 — “Location not found: ~/.worktrees/...”
- **ZeroCreds / tunnel / sharing** — 1153 — “zerocreds not working”, “share creds”
- **fork / memory / acceptance** — 977 — “acceptance not working”, “memory not exercised”
- **wrong answer / discrepancy** — 726 — “not what requested”

## Judge comments

- **P.1 (CI fork red 3 commits straight on `main` — now 8 failing jobs on head)** — **Real:** 8 failures on head f62df808f332 (see latest test run). **Doubtful:** the earlier STUDY said 9 failures — maybe one cleared. Still root TS2719 present. **Needs:** fix typecheck, bring `main` green, rebuild candidate.
- **P.2 (Root cause selftest‑500 found and fixed, but CI `main` broken)** — **Real:** 14 runtime errors 23.10 10:00‑12:57; PR #208 merged 23.10 13:24; selftest green 2343/0213; candidate=installed=f62df808f332. **Doubtful:** CI now red due to typecheck regression of same fix. **Needs:** same fix (P.1).
- **P.3 (V2‑flags exist, but release‑notes don’t document)** — **Real:** binary contains OPENCODE_V2_MEMORY_CONTEXT, MIN_CHARS, TOOLS, CONTEXT_DEBUG; release‑current.md empty names; generator writes wrong names. **Needs:** fix generator (names without extra CONTEXT), decide on secret editor or allow OPENCODE_V2_MEMORY_* in release‑notes, close #191.
- **P.4 (TDZ in memory ranking fixed on `main`)** — **Real:** mem‑record‑store.ts:245 `const limit` before use on 249/258; regression closed. **Needs:** none.
- **P.5 (Acceptance dummy)** — **Real:** DONE prints before checks; needle in session file; memory flag disabled. **Needs:** machine verification of answer T1 with source, move DONE after checks (#195/#197), enable OPENCODE_V2_MEMORY_CONTEXT=1 in selftest.
- **P.6 (Selftest brittle)** — **Real:** series 23‑24.10: green → 130047 500 → 205059/214529 every rung failed → 040811 5×`unauthorized`. **Needs:** retry/backoff on UnexpectedStatus 500/unauthorized + separation infra/product verdict.
- **P.7 (Delivery window 2 KiB truncates put_in_operational_memory)** — **Real:** truncation markers 505/24h, ~9454/7d. **Needs:** none.
- **P.8 (Money and intent detectors dead)** — **Real:** cost=0, intent_signal=0. **Needs:** fix or remove from digest as noise.
- **P.9 (CSM scanner stood)** — **Real:** last_scanned_at 21.10, issues=0, reports/ from 09.10. **Needs:** watchdog on last_scanned_at older than 2h.
- **P.10 ("No tool named")** — **Real:** 568 in 24h (vs STUDY’s 421); 320 reference tools.opencode.list_mcp_resources; scheme contains it. **Doubtful:** not model hallucination, but scheme↔runtime mismatch. **Needs:** alias to native list_mcp_resources or remove from scheme.
- **P.11 (Code Mode errors under‑reporting)** — **Real:** execute 124 calls / 1 structural error in 24h; 71 assistant messages with Unknown identifier; No tool named = 568 (p.10). **Needs:** fix scheme.
- **P.12 (mem‑metrics.sql dead for v2)** — **Real:** mem‑metrics‑v2.sh yields full digest; prescribed mem‑metrics.sql — empty. **Needs:** update researcher prompt to v2‑wrapper (issue `#190`).
- **P.13 (Disk healthy, prune step works)** — **Real:** / **44 GiB free (22 % used)**; ~/.worktrees = 0 B / 0 worktrees; chain‑state.jsonl writes prune step with freed_kb:0. **Doubtful:** stale checkout `/Users/vova/code/opencode-mem-verify` pollutes typecheck. **Needs:** clean up stale checkout.
- **P.15 (Compaction off entirely)** — **Real:** time_compacting = NULL across all 1171 sessions (7d). **However:** compaction messages exist (4 in 24h, 160 in 7d). **Needs:** enable flag in selftest, verify compaction triggers, log time_compacting.
- **P.18 (read tool, #198) — fixed in code** — **Real:** plugin/read.ts:23 states real ceiling (`50 KiB ≈ 624 lines`). **Needs:** close `#198`.
- **Fresh user‑signal (MCP/sessions/worktree/auto‑update/zen/unauthorized)** — **Real:** user 22‑24.10 reports MCP outage, lost/unseen sessions, Location not found worktree, auto‑update over fork, dead zen rings, unauthorized from ladder/build. **Doubtful:** whether this is fork opencode‑mem or session‑manager/environment/ladder. **Needs:** raise issues and disambiguate.

---

## Next research priorities

1. **Fix typecheck on `main` (TS2719 in `llm.ts:403`)** — remove failing jobs, bring `main` green, rebuild candidate, run selftest.
2. **Selftest resilience to infra failure** — retry/backoff on UnexpectedStatus 500 / unauthorized + separation infra/product verdict + candidate/installed SHA in chain-state.
3. **Machine verification of answer T1 with source (`sha256`/`cmp`) + move DONE after checks (#195/#197).**
4. **Enable `OPENCODE_V2_MEMORY_CONTEXT=1` in selftest/chain** — otherwise memory not exercised at all.
5. **Watchdog on CSM scanner** (`last_scanned_at` older than 2h) — else feedback channel dead.
6. **Raise issues on fresh user‑signals** (MCP outage, lost sessions/worktree location, auto‑update over fork, zen, unauthorized) and disambiguate fork vs environment/ladder.
7. **Fix/disable `cost` and `intent_signal` detectors** — currently digest empty.
8. **Fix scheme: `tools.opencode.list_mcp_resources` not callable** — alias to native list_mcp_resources or remove from scheme.
9. **Fix release‑notes generator** — flag names without extra CONTEXT, don't strip OPENCODE_V2_MEMORY_* on publish.
10. **`ITERATIONS.md`** — append chain 2343/0213/0515, regression typecheck, CacheMarkLedger diagnosis, flag status, 040811 failure.
11. **Close `#198`** (read tool) — already fixed.
12. **Clean up stale checkout `/Users/vova/code/opencode-mem-verify`** — pollutes typecheck.
13. **Solve why compaction never triggers** — enable flag in selftest, check MIN_CHARS/`TOOLS`, log `time_compacting`.

---

Commit change: git add STUDY.md && commit -m "research: research-20261024-0830" && push