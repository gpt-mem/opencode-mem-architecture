# GitHub Issue backlog — gpt-mem/opencode-mem

Target branch: `dev`. Use short branches (up to 3 words, hyphens), conventional PR titles, and separate PRs. Each issue below is a standalone work item; follow `ARCHITECTURE.md` for full contracts.

## I0 — Audit integration and baseline
Audit authoritative Session Runner, tool settlement, current SQLite event schema, output truncation/managed output files, versioned migrations and FTS5. Instrument baseline per-provider-turn breakdown: system/history/tool definitions, cache read/write, number of tool invocations and success. Collect representative coding sessions. **Acceptance:** reproducible baseline; source map and no behavior change. Dependencies: none.

## I1a — SQLite index and tool call/result ingestion
Create memory-owned SQLite schema/migrations and source-backed event index, supporting durable tool outcomes, Bash command, cwd, status, exit code, timestamps, error previews, output refs and source IDs. Incremental backfill, idempotency and redaction before indexing. **Acceptance:** retries do not duplicate events; exact linkage after restart; cross-session retrieval, no secret leaks. Dependencies: I0.

## I1b — Small-model tool overview/search/details
Native methods: `get_tool_call_overview`, `find_tool_calls`, `get_tool_call_details`. Summary groups by tool name and status, with counts and examples. Search by tool name, status, regex or text. Details connect each call and result and point to original full output. All responses bounded, paginated and source linked. **Acceptance:** find last failed Bash and full output without full session; tests for pending, unknown and deleted source. Dependencies: I1a.
**Status 2026-10-10:** `find_tool_calls` and `get_tool_call_details` shipped on `memory-context-v1` (PR #6 / commit `5b14671755`); `get_tool_call_overview` not yet implemented.

## I2a — GitHub/URL/entity reference extraction
Parse owner/repo PR and issue links, commit SHAs, branch names, normalized URL/endpoint and originating tool/message. Distinguish references/mentions from verified actions. Redact sensitive query parameters. Provide compact search and exact original refs. **Acceptance:** no invented merged status, duplicates deduped, regex search and tests. Dependencies: I1a.

## I2b — Artifact manifests and structured payload previews
Create manifests for Markdown and files: title, MIME, path, hash, headings/line ranges and code snippets. Add bounded structural previews for JSON, XML and HTML, exact source pointers, section retrieval and parser safety limits. Research existing reusable JSON compression code in adjacent repositories first. **Acceptance:** exact section search and source retrieval, large input bounded, malformed input handled, no secrets. Dependencies: I1a.

## I3a — DecisionWrite/Operational Memory typed records
Implement native DecisionWrite wrapper and batch `put_in_operational_memory`, search/get/context, type taxonomy, authority, decided_by vs recorded_by, source refs, scope and version history. Reuse TodoTable rather than shadowing existing TODO management. **Acceptance:** user/agent decisions cannot be conflated, supersedes/history and idempotent batches work, no self-elevation of authority. Dependencies: I1a.

## I3b — Memory Commit
Persist atomic task transitions with next action, blockers and linked artifacts/memory, optimistic version and idempotency. **Acceptance:** simultaneous updates conflict safely; restart can find latest checkpoint; never claim external PR/test completion without evidence. Dependencies: I3a.

## I4 — Optional embeddings/hybrid retrieval
Background embeddings for documents and historic messages, explicit semantic search plus FTS fallback and active task context for 'continue'. No mandatory model/network calls. **Acceptance:** recall quality and latency measured against deterministic baseline; privacy/scopes respected. Dependencies: I2, I3.

## I5 — Experimental memory-first context assembly
Separate opt-in feature flag modifies only provider message assembly, leaving System Context Epoch, baselineSeq, all session history and protocol-valid recent call/result continuation intact. Compare with original OpenCode on identical coding tasks, accounting for prompt caching. **Acceptance:** no material task success regression, net savings and latency documented, one-switch rollback. Dependencies: I0–I3; I4 optional.


## BUG-1 — Compacted shell output markers are not retrievable (FIXED 2026-10-10, PR #1, branch `fix-shell-marker-retrieval`)

GitHub issues are disabled on `gpt-mem/opencode-mem`, so filing here.

`MemoryContext.project` compacts large old `shell` messages (`packages/core/src/session/memory-context.ts:130-144`), but `shellMarker` (`:100-107`) emits neither `call_id=` nor a `retrieve=get_tool_call_details(...)` line — unlike `toolMarker` (`:79`, `:87`). Shell messages do carry `callID` (`SessionMessage.Shell`) and `get_tool_call_details` already resolves them (`packages/core/src/tool/get-tool-call-details.ts:50-62`), so the original is in SQLite, but the marker's only hint is `original=session ... message <id>`, which the tool does not accept as input. Result: for bash — the largest payload class in tool-heavy sessions — the "nothing hidden" invariant is broken; the LLM has no working retrieval path.

**Fix:** include `call_id=<message.callID>` and `retrieve=get_tool_call_details(call_id="<callID>")` in `shellMarker`.

**Test gap:** `memory-context-savings.test.ts:148-159` ("keeps every compacted result retrievable by call_id") filters only `[mem:compacted tool result]` markers, so shell markers are never asserted. Extend it to `[mem:compacted shell output]`.

**Acceptance:** shell marker contains unique `call_id` + retrieve line; `get_tool_call_details(call_id)` returns the original shell output for a compacted shell message; CI test covers both marker kinds.

## CI-1 — Fork CI: upstream workflows queue forever, and our workflow misses core regressions (FIXED 2026-10-10, PR #4, branch `ci-fork-runners`)

Two gaps, both surfaced while landing PR #1/#2:

1. **Blacksmith runners don't exist on the fork.** `.github/workflows/test.yml` (unit/e2e linux+windows) and `.github/workflows/pr-management.yml` (`check-duplicates`) use `runs-on: blacksmith-4vcpu-ubuntu-2404` / `blacksmith-4vcpu-windows-2025`. Without the Blacksmith app on `gpt-mem/opencode-mem` those jobs sit in `queued` forever (57+ min observed) and every PR shows permanently pending checks. No branch protection, so PRs are still mergeable — but the signal is noise. **Fix options:** guard with `if: github.repository == 'anomalyco/opencode'`, or map to `ubuntu-latest`/`windows-latest` on the fork; also cancel stale queued runs after merge.
   **Fixed in PR #4:** `test.yml` unit matrix maps runners per-repo (`github.repository == 'anomalyco/opencode' && blacksmith-* || ubuntu-latest/windows-latest`), e2e job and `pr-management/check-duplicates` skipped on the fork (`if: github.repository == 'anomalyco/opencode'` — e2e is slow Playwright noise, duplicate-check needs the upstream-only `OPENCODE_API_KEY`).
2. **Our `mem-context` workflow only runs memory-context files** (`memory-context`, `memory-context-savings`, `tool-get-call-details`, `pii`) + core typecheck. A regression in any other core test is invisible to CI — e.g. `get_tool_call_details` added to `builtins.ts` broke `location-layer.test.ts` expectations and was only caught by a local full `bun test` (fixed in PR #2). Remaining local core failures are environmental (`cross-spawn` ×15, `Npm.add`) and would fail on upstream too — CI should run the full core suite and tolerate/allowlist only those, or run it as non-blocking.
   **Fixed in PR #4:** `mem-context.yml` gains a blocking `core full suite` job — full `bun test` in `packages/core` on `ubuntu-latest` (macOS-environmental failures don't occur on Linux; failure summary greps `(fail)` lines) plus `bun run typecheck` in `packages/opencode`.

**Acceptance:** a PR on the fork shows no checks stuck in `queued`; a change to `builtins.ts` that breaks another core test fails CI. — **Verified 2026-10-10:** PR #4 checks completed (unit matrix now runs on github-hosted), PR merged into `memory-context-v1` (squash `d1435d2338`), branch deleted, `mem-context` runs on `memory-context-v1` green. CI-1 closed.

## NEW P0: Context Projection v1 — reduce old tool outputs in Build

See `CONTEXT_V1.md`. Implement a flag-gated in-memory substitution of older completed successful tool-result text at provider-turn assembly, preserving call/result envelopes, IDs, user messages, system epochs and native continuation metadata. Require retrievable originals, explicit fallback and A/B cost/quality tests. Do not replace all session history.
