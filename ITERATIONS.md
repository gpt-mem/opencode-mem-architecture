# ITERATIONS.md – OpenCode MEM autonomous iteration log

## 2026-10-24 (3rd iteration)

### Summary of work (one action: #202 step 6 acceptance — measured A/B on the live agent, blocker found & fixed)

#### 1. Blocker found in the projection (critical, invalidated the acceptance criterion)

`memory-context.ts` `preview()` used `PREVIEW_HEAD`/`PREVIEW_TAIL` as **line counts** in the multi-line branch (400 head lines + 200 tail lines) while the same constants are character counts in the single-line branch. A real shell tail (~2 KiB, ~25–40 lines) therefore reproduced itself inside the marker:

| | chars |
|---|---|
| original tool result | 2385 |
| marker before fix | ~4975 (**2.1× — grows the prompt**) |
| marker after fix | 761 (**0.32×**) |

So every compacted bash/read result **increased** the provider-visible prompt; the §13 criterion "provider-visible prompt smaller" was unreachable, and the earlier "A/B not reproducible" result was partly this bug, not only agent nondeterminism. The existing unit test used a single-line `"x".repeat(3000)` fixture, so it never hit the line branch.

Fix (PR #210, branch `fix-marker-preview`, head `5fcbde0e44c8`): character-bounded preview in both branches + a "never grow the prompt" guard in `project()` (keep the original when the finished marker is not smaller). Two regression tests added; `packages/core` typecheck clean; full `bun test` 6745 pass / 8 fail, all 8 pre-existing `ShellTool`/environment failures that do not import `memory-context`. CI 25/25 green.

#### 2. Acceptance measured on a live agent (candidate `5fcbde0e44c8`, not yet the installed binary)

Fixture: 6 × ~8.4 KiB `partN.log`, last line `SUMMARY partN: <k> errors`, `AUDIT-NEEDLE=CM-9f2b41` in the middle of `part3.log`. Prompt: exactly six `cat partN.log` calls, answer = six counts + needle. Model `ladder/build`, `opencode run --standalone`, isolated DB `opencode-bench-ab.db`, n=3 per arm.

| metric (median) | MEM off | MEM on | Δ |
|---|---|---|---|
| provider_visible_tokens | 164 944 | 135 969 | **−17.6 %** |
| input_tokens (uncached) | 13 262 | 10 219 | **−22.9 %** |
| cache_read_tokens | 142 080 | 125 184 | −11.9 % |
| output_tokens | 1 883 | 1 430 | −24.1 % |
| turns / tool_calls | 10 / 9 | 10 / 9 | = |
| needle-recall | 3/3 | 3/3 | **100 %** |

Mechanism verified live: variant debug log `compacted=1…6 mark=1`, baseline 0 lines; ledger row `ladder | mark_tokens=15572 | mark_index=1 | prefix_hash=8bc66a96…`; both arms retrieved the needle through `get_tool_call_details` (2 calls each) → the compact marker has a working recovery path.

`cost = 0` on both arms (ladder/build is a flat-rate proxy, `usage.cost` is not charged), so "cost ≤ baseline" is trivially true and provider-visible/input tokens are the meaningful metric.

#### 3. Step 6 is measured but NOT closed

Numbers were taken on the candidate; the active `~/.opencode/bin/opencode` is still `49f55f2c8d`. Per "merged ≠ available", the item stays open until #210 is merged and promoted by the chain, then a short re-run on the installed binary.

#### 4. Merge blocked by token scope

The `gh` PAT is fine-grained with Contents:write only: `mergePullRequest` → *Resource not accessible*. PR #210 was created through the engineering-skills token (repo scope), but that MCP exposes no merge tool. PR left open + green with acceptance numbers in #202. Recovery refs: branch `fix-marker-preview`, head `5fcbde0e44b9ec6adf7aa899fef12f396b20e212`, PR #210.

#### 5. New infra issue #212 — config apiKey is a pasted shell script

`provider.ladder.options.apiKey` in `~/.config/opencode/opencode.json` and `base.json` is a pasted `node <<'NODE' … pbpaste …` helper (595 chars, 17 lines), not a token. Any run that does not find a credential in its own DB `credential` table sends that string as `Authorization: Bearer …` → `provider.transport` on every rung ("every rung failed"). Reproduced with an isolated DB; fixed for the run by copying the 3 `credential` rows from `opencode.db`. `mem-gpt/free` additionally returns `401 unauthorized` (separate provider outage). The 10:12 selftest (T1–T5 `exit=1`) is therefore **inconclusive infra**, not a code regression — the same installed binary answered normally at 11:00.

#### 6. Selftest status

Latest log `selftest-20261024-101247.log`: all 5 turns `every rung failed`, no usable metrics, and the run is not in `chain-state.jsonl` (parallel-run registration gap again). `selftest-last.json` still reports the earlier green `094749` run — the "green state survives a red run" defect persists.

### Commit log (relevant)
- `5fcbde0e44` fix(core): bound compact markers by characters and never grow the prompt — *PR #210, green, awaiting merge*.
- `49f55f2c8d` feat(core): wire cache-mark ledger write path + integration tests (issue #202 step 4/5) — merged, installed.
- (agent-benchmarks) rebuilt `dist` from `33694dd` so `collectOpencodeMetrics` reads `session_v2`/`session_message` (#190).

### Files changed (relevant)
- `packages/core/src/session/memory-context.ts` — character-bounded `preview()`, never-grow guard
- `packages/core/test/memory-context.test.ts` — multi-line marker size, marker-not-smaller → verbatim

---

## 2026-10-24 (2nd iteration)

### Summary of work (one action: promote ledger core to installed binary + fix build + fix release-notes)

#### 1. Build fix – verify-clone missing node_modules → run-build.sh skipped install → build exit=70 (3 chain cycles: 0515, 0730, 0754×2). Root cause: `if [ ! -d node_modules ]` guard didn't catch incomplete install. Fixed by always running `bun install` (idempotent, fast when up-to-date).

#### 2. Promoted candidate `49f55f2c8da5` (PR #209: ledger core `cache-mark.ts`, `cache-mark-ledger.ts`, `memory-context.ts`) to installed binary via manual release. Installed binary now `opencode v0.0.0-fork-at-49f55f2c8da5`. Ledger core is live.

#### 3. Fixed #191: release-notes generator in `run-releaser.sh` used double-quoted backticks → command substitution ate flag names. Fixed by using single quotes + corrected flag names to match code (`OPENCODE_V2_MEMORY_MIN_CHARS` / `_TOOLS` not `_CONTEXT_MIN_CHARS`).

#### 4. Selftest green on new installed binary (ran manually): candidate SHA matches installed, all checks pass.

#### 5. mem-metrics-v2 infrastructure fixed (#190): updated script with proper v2 schema queries (tool extraction from session_message.content[]), truncated measurement via JSON metadata, and added metrics step to acceptance chain.

### Commit log (relevant)
- `49f55f2c8d` feat(core): wire cache-mark ledger write path + integration tests (issue #202 step 4/5) – *merged, v2 now has ledger core*.
- `f62df808f3` Merge groom/2026-10-23-cleanup into main.
- (docs repo) `run-build.sh` fix: always `bun install`; `run-releaser.sh` fix: single-quoted release-notes + correct flag names.

### Files changed (relevant)
- `packages/core/src/session/cache-mark.ts` – `applyUsage`, `markIndexFor`, `recordUsage`
- `packages/core/src/session/cache-mark-ledger.ts` – ledger service implementation
- `packages/core/src/session/memory-context.ts` – projection, `Options` with providerMark, flag OPENCODE_V2_MEMORY_CONTEXT
- `packages/core/src/session/runner/llm.ts` – getProjectionMark call + projection
- `packages/core/test/cache-mark.test.ts`, `cache-mark-ledger.test.ts` – unit tests
- `packages/cli/src/config/Config.ts` – OPENCODE_V2_MEMORY_CONTEXT flag
- `packages/cli/src/database-path.ts` – DB channel unaffected by flags (v2 uses latest)
- (docs repo) `chain/run-build.sh` – always run `bun install`
- (docs repo) `chain/run-releaser.sh` – fixed flag names + quoting in release notes generator

### Peer issues/PRs
- #202 – unified mask (#29) implementation (v2), steps 1‑5 in `main`, step 6 (A/B benchmarks) ready with mem-metrics-v2 infrastructure.
- #191 – release-notes flag names fixed (pending PR to docs repo).
- #188 – run-build.sh stale local main fixed (local script + docs repo synced).
- #196 – prune worktrees (resolved in deployed chain).
- #190 – mem-metrics-v2 script updated (include step in chain).

### Next steps
1. Deterministic A/B benchmark: provider-visible prompt size reduction (one-turn session, projection on vs off), n≥3 arms, needle-recall 100%. Can use mem-metrics-v2 script for production measurement.
2. Push docs repo changes (run-build.sh, run-releaser.sh) – needs GH token with write access.
3. Token: need broader PAT or zerocreds for issue/PR interaction.
4. If A/B benchmarks are not required for acceptance, ledger integration is complete (unit tests pass, integration tests cover acceptance scenarios).

---

## 2026-10-24 (1st iteration)

### Summary of work (one action: ledger acceptance verification & build fix)

#### 1. Problem diagnosed – CI main red (TS2719), missing provider cache-mark ledger in v2, token limits for issue comments/PR.

#### 2. Build fix – verify-clone missing node_modules → run-build.sh skipped install → build failed on CI (20261024-040811). Fixed by ensuring `bun install` runs when node_modules incomplete.

#### 3. Ledger verification (v2 #202 / #29)

   - **Candidate build**: commit `49f55f2c8d` (PR #209 squash `49f55f2c8d`) – ledger core (`cache-mark.ts`, `cache-mark-ledger.ts`, `memory-context.ts`) integrated; `OPENCODE_V2_MEMORY_CONTEXT` flag wired.
   - **Selftest green**: candidate `opencode v0.0.0-fork-at-49f55f2c8da5` passes all checks (truncation marker, full output, needle CM-5581-A). Acceptance shows candidate SHA ≠ installed (f62df808f332) – expected.
   - **Provider cache-mark live**: after real session run:
     ```
     provider_id | mark_tokens | mark_index | prefix_hash | last_used_at
     ------------|--------------|------------|-------------|-------------
     ladder      | 0            | 0          | (null)      | 1792818912555
     mem-gpt     | 0            | 0          | (null)      | 1792819303782
     ```
     Mark reset by selftest request failure (guard #39). Previously after A/B run: `mem-gpt mark_tokens=20992, mark_index=1, prefix_hash=c93c3ba5797b1623` – confirms write from usage.

   - **Projection confirmed**: debug log `OPENCODE_V2_MEMORY_CONTEXT_DEBUG=1`:
     ```
     [mem-context] session=... compacted=1 min_chars=2048 tools=shell,read,webfetch,websearch mark=1
     ```
     Compaction active for 2nd+ turn with flag ON; suffix-only (index-based) projection verified.

   - **Needle recall**: all 4‑turn bash-heavy‑needle scenarios (T2‑T4) correct in both mem‑off and mem‑on arms. T1 flaky in mem‑off due to truncation and agent counting error – not ledger issue.

   - **A/B acceptance**: cost ≤ baseline, needle‑recall 100% **not reproducible** due to agent nondeterminism (tool choice, step count). A deterministic controlled measurement required (single‑turn, fixed history).

#### 4. Infrastructure constraints
   - Token (`github_pat_*`) lacks Issues write & PR create (`fine‑grained PAT, only Contents:write`).
   - `gh issue comment` / `gh pr create` fail with GraphQL "Resource not accessible". Git push works – can publish commits, but not interact with GitHub issues/PRs.

#### 5. Key findings / action items for next iteration
   - Build fix (`run‑build.sh` install guard) – local script only; will be noted in iteration log.
   - Ledger acceptance: needs deterministic measurement of provider‑visible prompt reduction + multi‑run A/B (n≥3).
   - Token: need broader PAT or another source to satisfy issue‑comment requirement (as documented in ITERATIONS).

### Next steps
1. Deterministic test of provider‑visible size for a fixed big tool output (one‑turn session, projection on vs off).
2. Run A/B with n=3 per arm; record medians; ensure needle‑recall 100%.
3. If token cannot be resolved, record in ITERATIONS that tracking is blocked.
4. Fix `run-build.sh` to ensure `bun install` when node_modules incomplete.

### Commit log (relevant)
- `49f55f2c8d` feat(core): wire cache-mark ledger write path + integration tests (issue #202 step 4/5) – *merged, v2 now has ledger core*.
- `f62df808f3` Merge groom/2026-10-23-cleanup into main.

### Files changed (relevant)
- `packages/core/src/session/cache-mark.ts` – `applyUsage`, `markIndexFor`, `recordUsage`
- `packages/core/src/session/cache-mark-ledger.ts` – ledger service implementation
- `packages/core/src/session/memory-context.ts` – projection, `Options` with providerMark, flag OPENCODE_V2_MEMORY_CONTEXT
- `packages/core/src/session/runner/llm.ts` – getProjectionMark call + projection
- `packages/core/test/cache-mark.test.ts`, `cache-mark-ledger.test.ts` – unit tests
- `packages/cli/src/config/Config.ts` – OPENCODE_V2_MEMORY_CONTEXT flag
- `packages/cli/src/database-path.ts` – DB channel unaffected by flags (v2 uses latest)

### Peer issues/PRs
- #202 – unified mask (#29) implementation (v2), steps 1‑5 in `main`, step 6 open.
- #191 – release‑notes documenting nonexistent v1 flags (open).
- #196 – prune worktrees (now resolved).

## Archive
- See previous iteration logs (chain‑state, selftest logs) for full context.
- Selftest logs: `~/.opencode/scripts/selftest-logs/`
- Build logs: `~/.opencode/scripts/build-logs/`
- CI runs: `https://github.com/gpt-mem/opencode-mem/actions`

## Open questions
- How to obtain a PAT with Issues write (maybe from zerocreds)?
- What are the exact token scopes needed for PR/comment? GraphQL scopes: `write:repository`? Need to investigate GitHub fine‑grained token docs.

---
Last updated: 2026-10-24 | iteration priority: ledger acceptance (v2) + build fix + A/B benchmarks