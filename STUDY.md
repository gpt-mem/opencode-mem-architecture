# STUDY research-20261024-1245

Methodology: read-only. Metrics — `mem-metrics-v2.sh` (v2 schema: `session_v2` + `session_message` in `opencode.db`, union of all `opencode*.db` channels) because the prescribed `mem-metrics.sql` still reads the frozen v1 tables; cross-checks via direct SQL on `session_message.content[]` JSON. Benchmarks — `~/.opencode/benchmarks.db` + `benchmarks/sess_*/metrics.json` + runtime log `~/.local/share/opencode/log/memory-context.log`. CI — `gh api .../check-runs` on head `4ed28ca389a0`. User feedback — CSM `sessions.db` (795 sessions, frozen at 21.10) **plus** a fresh, filtered pull of real human prompts from `session_message` (72h). Window: 24h unless stated. Verdicts are conservative: `proven` only with a number or a code line; anything with n<5 or a confounded arm is `doubtful`/`needs_proof`.

## Ranked by usefulness

1. **Retrieval path is broken at scale: `get_tool_call_details` returns truncated output 895/898 calls (99.7 %)** — high — STATUS: proven — 24h: 898 calls, 895 `metadata.truncated=1`, 887 called **without** `limit` (default path); only the 7 calls with explicit `limit` (3000–250000) escaped. The "nothing hidden" invariant does not hold: the recovery tool re-truncates its own output.

2. **Tool-output truncation is the dominant context defect: 2586 truncated tool calls across 140 sessions in 24h** — high — STATUS: proven — by tool: `shell` 1358, `get_tool_call_details` 895, `read` 211, `execute` 72; `showing lines` text appears in 2420 messages. Same 2 KiB window (`ToolOutput.MAX_BYTES = 2 * 1024`) that truncates `put_in_operational_memory` (1/5 calls truncated in 24h).

3. **Memory-context projection is *correct* but its savings are unproven** — high — STATUS: doubtful — A/B `memory-context-v2-acceptance`, model `ladder/build`, n=3 per arm, 6/6 answers byte-identical and correct (`part1..6`, `needle=CM-9f2b41`), needle-recall 100 % in both arms; provider-visible tokens baseline 164 944 / 139 214 / 208 748 vs variant 135 969 / 135 403 / 146 203 → mean −18.6 %, median −15.6 %, **but per-pair −17.6 % / −2.8 % / −30.1 %** (baseline CV 20.6 %), Welch t≈1.5, p≈0.2 ⇒ not significant. Also `min_chars=2048` while release notes demand >4000.

4. **CI `main` is green again — the previous #1 finding is closed** — high — STATUS: proven — head `4ed28ca389a0`: **21 success / 1 skipped / 0 failure** check-runs (previously 8 failing jobs, TS2719 in `llm.ts:403`). `origin/main` == installed == candidate == `4ed28ca389a0`. Remaining red is bot-only (#214: `triage` failed on `4ac826507b`, absent from head's check-runs).

5. **Selftest can report green for a binary it never ran** — high — STATUS: proven — chain order is `build → selftest → release` (`run-mem-chain.sh:146,151,161,166`); `run-selftest.sh:64-66` gates only `CAND_VER`, never compares `installed`; observed 120639: candidate `4ed28ca389a0` vs installed `49f55f2c8da5`, yet `selftest-last.json` recorded `"status":"ok"` for the unrun candidate. Gate gap is structural, not a one-off.

6. **Acceptance checks are decorative: DONE prints before checks, needle match is grep-only** — high — STATUS: proven — `run-selftest.sh:190` prints `=== SELFTEST … DONE ===` before acceptance at `:198-214`; `:205` takes the **first** marker file by `seq` and `:214` only greps `big-output-line-2999`, so a 3 106 B auxiliary fragment passed as "full output" in 120639 while the real capture was 244 889 B.

7. **Memory feature is never exercised by the acceptance path** — high — STATUS: proven — `run-mem-chain.sh` and `run-selftest.sh` contain **0** occurrences of `OPENCODE_V2_MEMORY_CONTEXT`; `grep -c 'mem:'` = 0 in 6 consecutive selftest logs. Projection *does* run in ad-hoc/bench sessions (`memory-context.log`: 66 events, 5 sessions, `compacted=1` 12×) — so the feature works, it is just outside the gate.

8. **`tools.opencode.list_mcp_resources` is advertised but not callable — 319 hard failures in 24h** — high — STATUS: proven — all 319 calls returned `No tool named "tools.opencode.list_mcp_resources" is currently available`; the name appears in 618 messages. Same class: `opencode.worktree_list` 7+4, `opencode.list_mcp_resources` 5+2, `search` 6. This is a scheme↔runtime mismatch, not model hallucination.

9. **Tool errors are under-reported by `state.status` alone** — high — STATUS: proven — 437 error tool calls / 7399 total (5.9 %); 319 of them are the single phantom MCP name; `edit` 51, `read` 10, `cloudflare_execute` 7. The earlier "124 execute calls / 1 structural error" picture hid the dominant failure mode.

10. **Money and intent detectors are dead** — high — STATUS: proven — `cost > 0` sessions in 7d: **0** (last ever 2026-10-12 07:51); `intent_signal` table: **0 rows, max(ts)=NULL**. Digest sections 1/4/7 of `mem-metrics.sql` and §4 of the v2 wrapper are structurally empty.

11. **CSM scanner is still stood** — high — STATUS: proven — `max(last_scanned_at)=2026-10-21T11:43:24Z`, newest session 2026-10-21T07:27; `issues`=0, `issues.jsonl`=1 line (2026-03-14), `reports/` from 09.10. 3 days of feedback channel lost; fresh signals had to be re-derived from `session_message`.

12. **`mem-metrics.sql` (#190) is still the wrong script for v2** — medium — STATUS: proven — the prescribed file reads `opencode-memory-context-v1.db` (frozen 2026-10-12); its 24h sections return empty. `mem-metrics-v2.sh` works (`sessions_24h=163`). #190 was closed on the wrapper, but the prompt still points at the dead file.

13. **Compaction never sets the session flag** — medium — STATUS: proven — `time_compacting IS NOT NULL` = **0 of 1212** sessions (7d) while compaction messages exist (2/24h, 160/7d) ⇒ `mem-metrics.sql §8` cannot compare compacted vs full, and no cost/latency verdict on compaction is possible.

14. **`mem_record` writes are correct but organic use is thin** — medium — STATUS: proven — 275 total / 250 active / 25 superseded; **7 new in 24h**; types decision 123 / constraint 83 / failed_approach 46 / user_signal 23; authority agent 163 / user 112; empty scope 93. No duplicates observed. `put_in_operational_memory` 5 calls, `search_operational_memory` 4 — both marginal.

15. **`get_tool_call_overview` and `find_tool_calls` are never called** — medium — STATUS: needs_proof — 0 calls in 24h (and 0 in total v2 history), although both tools exist in source (`packages/opencode/src/tool/get-tool-call-overview.ts`, `find-tool-calls.ts`). Unknown whether they are unregistered, hidden from the scheme, or simply unused — needs a registry/scheme dump.

16. **Disk healthy, but headroom halved in 24h** — medium — STATUS: proven — `/` 27 GiB free / 31 % used (previous STUDY: 44 GiB / 22 %); `~/.worktrees` 0 B / 0 worktrees; prune step still writes `prune-detail` (`freed_kb:0`, `mode:apply`).

17. **Build reads a fork checkout on the wrong branch (#188)** — medium — STATUS: doubtful — `run-build.sh:17` `FORK=…/opencode-mem-work`, which sits on `memory-context-v1` @ `1961017693bb` (**90 ahead / 4782 behind** `origin/main`), but the script then does `git fetch $REPO main` + `reset --hard FETCH_HEAD`, so the candidate SHA came out correct (`4ed28ca389a0`). Latent hazard, not an active defect — needs the branch to be asserted in the script.

18. **Release notes now document the real v2 flags** — medium — STATUS: proven — `release-current.md` lists `OPENCODE_V2_MEMORY_CONTEXT`, `_MIN_CHARS`, `_TOOLS`, `_CONTEXT_DEBUG` with correct names (previous generator bug fixed, #191 closed). Residual: no values policy (`MIN_CHARS` default 2048 contradicts the ">4000" recommendation in the same file).

19. **`#198` read ceiling: description still promises 2000 lines, code caps at 50 KiB** — medium — STATUS: proven — `packages/opencode/src/tool/read.txt:5` "up to 2000 lines" vs `read.ts` `MAX_BYTES = 50 * 1024` (≈624 lines). Issue is valid and still open; the earlier "fixed in code" note referred to a plugin, not the tool description.

20. **Compaction/`mem:` markers absent from every acceptance log** — medium — STATUS: proven — `grep -c 'mem:'` = 0 in 120639, 101247, 094749, 091054, 060824, 040811; `mem-context|compacted=` = 0 in the same logs. Consequence of p.7, not a separate bug.

21. **Selftest is brittle to infra failure, but recovery is proven** — medium — STATUS: proven — series: 130047 `500` → 205059 3F → 214529 1F → 234346/020107/021315/094749/120639 green → 101247 `every rung failed` → 122304 running; 040811 was 5×`unauthorized`. Cause of 101247 was a broken `apiKey` (#212), i.e. infra. No retry/backoff, no infra-vs-product split in the verdict.

22. **ITERATIONS.md still normalises the candidate/installed gap** — medium — STATUS: proven — 3 entries for 24.10 exist (1st/2nd/3rd iteration), but the 1st says "Acceptance shows candidate SHA ≠ installed (f62df808f332) – expected", i.e. a P0 gate gap recorded as normal. No entry covers 120639 (false-positive acceptance) or #212/#214.

23. **Open backlog: 22 issues, 0 PRs** — medium — STATUS: proven — open: #202 (P0 unified mask), #214, #212, #198, #188, #207, #197, #195, #189, #185, #174, #142, #139, #130, #121, #120, #119, #118, #108, #107, #42, #15. No PR in flight; all recent work landed directly on `main`.

24. **Fork plugins still log WARN, counters not comparable** — medium — STATUS: doubtful — `opencode.log` shows the "configured plugin path must be a directory" WARN repeatedly, but the log compacts in place (29 MB now, 49.5 MB / 92k lines before), so cross-cycle counts are meaningless. Needs a rotated, append-only log before any claim.

25. **NL search: regex first, no morphology, OR fallback** — medium — STATUS: doubtful — code path `mem-record-store.ts:236-243` unchanged; cannot be judged live because no acceptance run enables memory. Active-filter behaviour unverified.

26. **Cross-project memory lookup returns `found:false`** — medium — STATUS: needs_proof — previously observed: `get_operational_memory` by id from another project answers "No memory … in this project" for an active record. Not re-tested this cycle; no counter in metrics.

27. **`question` tool / `self-review` blind spots** — low — STATUS: needs_proof — `question` 0 calls in 24h (previous cycle: 4 calls, 1 error); self-review sessions still claim "no edits" while scheduled-iteration performs retrieval-only work. No new evidence either way.

28. **`"<tool_call>"` in data line, 0644 API keys in logs, long-running old-code processes** — low — STATUS: needs_proof — none reproduced this cycle: no fresh `"<tool_call>"` sample, no key material found in current logs (0644 risk on `selftest-logs/` not cleared), `opencode serve` processes not re-inventoried.

29. **Cross-memory resume is still the only real upgrade, and still thin** — low — STATUS: doubtful — the bench A/B (p.3) is the first clean measurement, and it measures *projection*, not *resume*; no independent user-ad-hoc observation of "memory helped" separated from "memory paraphrased".

### Classification summary

- **Proven (stable, metrics or code confirm):** 1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 18, 19, 20, 21, 22, 23.
- **Doubtful (evidence exists, but n/arms/definition do not carry it):** 3, 17, 24, 25, 29.
- **Needs proof (no fresh measurement):** 15, 26, 27, 28.

## Metrics digest (24h)

- **Sessions: 163** (scheduled 95, chain 28, ad-hoc 40), **Total tokens: in 48 714 186 / out 1 344 514**, **Cache read: 316 571 496 (86.7 %)**, cache_write 0, **Cost: $0.00** (detector dead; last `cost>0` 2026-10-12)
- **Cache hit by kind:** scheduled 87.8 %, chain 83.5 %, ad-hoc 46.8 % (ad-hoc is 40 sessions but only 3.2 M input — cache reuse there is inherently low)
- **Memory tools: overview=0, find=0, detail=903 calls** (24h) — of which `get_tool_call_details` 898 / 895 truncated / 887 without `limit`; plus `put_in_operational_memory`=5 (1 truncated), `search_operational_memory`=4
- **Memory-tool share of all tool calls: 12.3 %** (912 / 7399) — but ~98 % of that volume is truncation recovery, not memory retrieval
- **Intent signals: cosine_avg = N/A, acted% = N/A** (`intent_signal` = 0 rows, `max(ts)` = NULL)
- **Truncation: 2586 tool calls / 140 sessions** (shell 1358, details 895, read 211, execute 72, grep 12); `showing lines` in 2420 messages
- **Tool errors: 437 / 7399 (5.9 %)** — `tools.opencode.list_mcp_resources` 319, `edit` 51, `read` 10, `cloudflare_execute` 7, `search` 6
- **Memory records: 275 total / 250 active / 25 superseded, 7 new in 24h; decision 123 / constraint 83 / failed_approach 46 / user_signal 23; authority agent 163 / user 112; empty scope 93**
- **Compaction: 0 sessions with `time_compacting` out of 1212 (7d)**; compaction messages 2 (24h) / 160 (7d)
- **Provider cache-mark ledger:** `ladder | 12729 tokens | idx 4 | 2026-10-24 12:23:40`; `mem-gpt | 2560 | idx 0 | 2026-10-24 12:10:22`
- **A/B benchmark (memory-context-v2-acceptance, n=3+3):** needle-recall 6/6 = 100 %, answers identical; provider-visible mean 170 969 → 139 192 (**−18.6 %**), median −15.6 %, per-pair spread 2.8–30.1 %, p≈0.2
- **Chain (24.10):** `0947` selftest ok 127 s → release ok → bug-reporter ok → researcher ok → release **withheld (exit=77)**; `1206` prune → build ok 8 s → selftest ok 223 s → metrics ok → release ok 18 s → bug-reporter ok 754 s
- **Selftest:** latest recorded green `120639` on `4ed28ca389a0` with **candidate ≠ installed at run time**; `122304` running now; no `OPENCODE_V2_MEMORY_CONTEXT` in the script
- **Disk:** `/` **27 GiB free / 31 % used** (was 44 GiB / 22 %); `~/.worktrees` 0 B / 0 worktrees
- **GitHub `gpt-mem/opencode-mem`:** 22 open issues / 0 open PR; `main` head `4ed28ca389a0` — 21 success / 1 skipped / 0 failure; local `opencode-mem-work` on `memory-context-v1` (90 ahead / 4782 behind)
- **CSM:** 795 sessions (opencode 721 / codex 74), `last_scanned_at` 2026-10-21T11:43:24Z; `issues`=0; `reports/` from 09.10

## User feedback top

Methodology: CSM `sessions.db` (795 sessions, frozen 21.10) classified over `first_prompt + summary + generated_title + last_message`, overlapping categories. Fresh arm: `session_message` user prompts, 72h, filtered to **227 genuine human prompts** (dropped >600 chars, automation headers, selftest/T2 needle prompts — the raw filter gives 1206 and is unusable, as in the previous STUDY). Severity = user-visible breakage if true.

| # | Pattern | CSM (to 21.10) | fresh 72h | severity |
|---|---|---|---|---|
| 1 | CI / tests / flaky / red workflow | 394 | 0 | high |
| 2 | fork / memory / acceptance | 213 | 0 (55 before filtering — all selftest) | high |
| 3 | tools / MCP / Code Mode broken | 185 | 3 | high |
| 4 | sandbox / provisioning | 152 | 0 | medium |
| 5 | provider / models / Ladder / Zen | 107 | **15** | high |
| 6 | agent hung / crashed / empty reply | 96 | 2 | high |
| 7 | cost / instances / billing / limits | 83 | 4 | low |
| 8 | session-manager / lost sessions | 49 | **5** | high |
| 9 | ZeroCreds / tunnel / credential sharing | 41 | 1 | medium |
| 10 | worktree / `Location not found` | 25 | 2 | high |
| 11 | GH tokens / merge rights | 20 | 0 | medium |
| 12 | wrong answer / discrepancy | 13 | 0 | high |

Representative fresh quotes (verbatim, trimmed):

1. **provider / ladder** — "скажи какой путь ты выбрал и как он обходит то что у меня ограничение провайдера и я не могу порт открыть?"; "Кольцо zen выключается флагом `zen_ring: false` в `config/ladders.json`" — 15 hits, still the top *human* complaint after automation is filtered out.
2. **session-manager** — "вчера куча сессий OpenCode у меня оборвалось посреди незаконченных и они в session manager не отображаются"; "Failed to switch model: Location not found: /Users/vova/.worktrees/exhibition-catalog-review/session-ses-…" — 5 + 2 hits.
3. **tools / Code Mode** — "наш тул по написанию кода … выдает ошибки: ✗execute ↳ ReferenceError: Unknown identifier 'require'"; "вчера все хорошо коннектились mcp engineering чек-лист, engineering skills, search skills, web navigation, а сегодня все сломалось" — 3 hits, matches the 319 phantom-tool failures.
4. **cost / limits** — "баланс аккаунта 97 (−0.20 свободно), порог 100: дальше бесплатные ступени OpenRouter" — 4 hits; note the product's own `cost` column is $0, so users track spend by hand.

Cross-check: the two dominant fresh categories (provider 15, sessions 5) are exactly the ones CSM cannot see anymore (scanner stood since 21.10) — the feedback loop is degraded, not the signal.

## Judge comments

- **P.1 Retrieval truncated 895/898** — **Real:** 898 calls, 895 `truncated`, 887 without `limit`; the 7 calls with an explicit large `limit` succeeded. **Doubtful:** nothing — the failure is measured, not inferred. **Needs:** make `get_tool_call_details` exempt from the 2 KiB delivery window (or make the default `limit` large enough for one chunk), and add a `check:` that asserts a retrieval call returned non-truncated content.
- **P.2 Truncation volume 2586/140** — **Real:** metadata-based count, tool breakdown above. **Doubtful:** whether the 2 KiB cap is a product decision or an accident — `ToolOutput.MAX_BYTES = 2 * 1024` looks like a safety default applied to every surface. **Needs:** separate the *storage* cap from the *delivery* cap; a marker must never point at content the delivery path will truncate again.
- **P.3 Projection A/B** — **Real:** 6/6 correct, needle 100 %, identical answers; variant sessions genuinely compacted (`compacted=4..6`, `mark=1..4`), baselines have 0 events. **Doubtful:** −18.6 % mean is carried by one pair (−30.1 %); the other two are −17.6 % and −2.8 %; baseline CV 20.6 %, p≈0.2; `tool_calls` differ (11 vs 9 in r3) so part of the delta is fewer turns. **Needs:** n≥10 per arm, fixed tool-call count, `min_chars>4000` (log shows 2048), and a cost column that is not $0.
- **P.4 CI green** — **Real:** 21 success / 1 skipped / 0 failure on `4ed28ca389a0`. **Doubtful:** #214 (bot workflows) can still paint `main` red on issue events — `triage` failed on `4ac826507b` and is absent from head's check-runs. **Needs:** close #214 by pinning a valid model id in the bot workflows, or exclude bot workflows from the branch verdict.
- **P.5 Selftest green for an unrun binary** — **Real:** `run-selftest.sh:64-66` checks only `CAND_VER`; chain runs selftest *before* release; 120639 recorded `ok` for `4ed28ca389a0` while installed was `49f55f2c8da5`. **Doubtful:** whether it is intentional (test the artifact before promotion) — it is not, because the report claims acceptance of the candidate. **Needs:** hard `installed == candidate` gate, or run the acceptance on the candidate binary explicitly and record both SHAs in `chain-state.jsonl`.
- **P.6 Acceptance decorative** — **Real:** DONE at `:190`, checks at `:198-214`; `:205` picks the first marker file by `seq`; `:214` greps one needle line, so a 3 106 B fragment passed as a 244 889 B capture. **Needs:** move DONE after checks, bind the check to the `cat big.txt` marker (not the first marker), assert size/line-count, and log `get_tool_call_details` as a distinct `check:`.
- **P.7 Memory never exercised by the gate** — **Real:** 0 flag mentions in `run-mem-chain.sh` / `run-selftest.sh`; `mem:` markers 0 in 6 logs; but the feature demonstrably runs elsewhere (`memory-context.log`). **Needs:** set `OPENCODE_V2_MEMORY_CONTEXT=1` (and `MIN_CHARS>4000`) in the acceptance run, otherwise every green result says nothing about the fork's only feature.
- **P.8 Phantom MCP tool name** — **Real:** 319/319 calls failed; name present in the scheme. **Doubtful:** none — it is a scheme↔runtime mismatch. **Needs:** alias `tools.opencode.list_mcp_resources` → the native `list_mcp_resources`, or strip the `tools.<ns>.` form from the Code Mode catalog. Same fix covers `opencode.worktree_list` and `search`.
- **P.9 Error under-reporting** — **Real:** 437 error calls (5.9 %), 319 from one phantom name. **Needs:** count errors per tool name in the digest; the single "structural error" metric hid the dominant failure.
- **P.10 Dead detectors** — **Real:** `cost>0` = 0 (last 2026-10-12), `intent_signal` = 0 rows. **Needs:** either repair or delete §1/§4/§7 from the digest — a permanently empty section trains readers to skip the digest.
- **P.11 CSM stood** — **Real:** `last_scanned_at` 21.10, `issues`=0, `reports/` from 09.10. **Needs:** watchdog (`last_scanned_at` older than 2h → alert), and stop presenting CSM counts as current.
- **P.12 Wrong metrics script** — **Real:** prescribed `mem-metrics.sql` reads the frozen v1 DB; the wrapper works. **Needs:** repoint the researcher prompt at `mem-metrics-v2.sh` (or port the SQL to v2 and delete the wrapper) — #190 was closed on the wrapper, not on the prompt.
- **P.13 Compaction flag never set** — **Real:** 0/1212 sessions, 160 compaction messages/7d. **Needs:** write `time_compacting` when compaction fires, otherwise §8 can never produce a verdict.
- **P.14 `mem_record`** — **Real:** 275/250/25, 7 new in 24h, no duplicates. **Doubtful:** "correct but thin" — 7 writes/day with 163 sessions is 4 %. **Needs:** decide whether memory is meant to grow organically or only on explicit user signals; today it is neither.
- **P.15 overview/find never called** — **Real:** 0 calls in the whole v2 history. **Doubtful:** the tools exist in source, so this is either a registration gap or a discovery gap — cannot tell from metrics. **Needs:** dump the effective tool registry and the scheme the model receives.
- **P.16 Disk** — **Real:** 27 GiB / 31 % (was 44 GiB / 22 %); prune runs with `freed_kb:0`. **Doubtful:** the 17 GiB drop in 24h is unexplained (logs? builds?). **Needs:** attribute the growth before the 5 GiB build guard starts skipping builds.
- **P.17 Build branch** — **Real:** `FORK` is on `memory-context-v1` 90 ahead / 4782 behind; **Doubtful:** candidate SHA is still correct because of `fetch`+`reset --hard FETCH_HEAD`. **Needs:** assert branch and SHA in the script, or point `FORK` at a clean `main` checkout.
- **P.18 Release notes** — **Real:** 4 flags with correct names, #191 closed. **Doubtful:** the same file recommends `MIN_CHARS>4000` while the runtime default is 2048. **Needs:** align default and recommendation.
- **P.19 #198 read ceiling** — **Real:** `read.txt:5` says 2000 lines, code caps at 50 KiB. **Needs:** fix the description (one-line change) or raise the cap; close the issue with a test that reads a 1000-line/60 KiB file.
- **P.20-21 Selftest brittleness / ITERATIONS** — **Real:** infra failures nullify a run (101247 → #212), recovery is proven (094749/120639 green on unchanged binaries), ITERATIONS records the candidate/installed gap as "expected". **Needs:** retry/backoff on 500/unauthorized, split infra vs product verdict, and stop normalising the gate gap in ITERATIONS.
- **P.24-29 (doubtful/needs_proof cluster)** — **Real:** code paths unchanged, observations not reproduced. **Doubtful:** no fresh measurement, and several previous numbers came from compacted logs or self-review sessions. **Needs:** rotated append-only log, a live registry dump, and one deterministic test per claim before any of these move to `proven`.

---

## Next research priorities

1. **Fix the retrieval path** (P.1): exemption from the 2 KiB delivery window + default `limit` sized to one chunk + a `check:` that fails on truncated retrieval. This is the invariant the whole product is sold on.
2. **Make acceptance real** (P.5/P.6): `installed == candidate` hard gate, DONE after checks, size/line-count assertion, bind to the `cat big.txt` marker.
3. **Turn the memory flag on in the gate** (P.7) with `MIN_CHARS>4000`, so green means something.
4. **Re-run the A/B with n≥10 and fixed tool-call count** (P.3) before quoting any savings number; add a cost column that is not $0.
5. **Kill the phantom tool names** (P.8): alias or strip `tools.<ns>.*` from the Code Mode catalog; add a scheme↔registry consistency test.
6. **Revive or delete the dead digest sections** (P.10): `cost`, `intent_signal`, and `time_compacting`.
7. **Watchdog on CSM** (`last_scanned_at` > 2h) — otherwise the only user-feedback channel is dead and every "fresh" number is hand-derived.
8. **Repoint the researcher prompt to `mem-metrics-v2.sh`** (P.12) and keep `mem-metrics.sql` only as a v1 archive.
9. **Attribute the 17 GiB disk drop** (P.16) before the build guard starts skipping.
10. **Fix `#198` description and close it**; **close `#214`** by pinning a valid bot model id.
11. **Dump the effective tool registry** (P.15) — `get_tool_call_overview` / `find_tool_calls` at 0 calls needs an explanation, not a guess.

---

Commit change: git add STUDY.md && commit -m "research: research-20261024-1245" && push
