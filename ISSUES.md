# GitHub Issue backlog — gpt-mem/opencode-mem

Target branch: `dev`. Use short branches (up to 3 words, hyphens), conventional PR titles, and separate PRs. Each issue below is a standalone work item; follow `ARCHITECTURE.md` for full contracts.

## I0 — Audit integration and baseline
Audit authoritative Session Runner, tool settlement, current SQLite event schema, output truncation/managed output files, versioned migrations and FTS5. Instrument baseline per-provider-turn breakdown: system/history/tool definitions, cache read/write, number of tool invocations and success. Collect representative coding sessions. **Acceptance:** reproducible baseline; source map and no behavior change. Dependencies: none.

## I1a — SQLite index and tool call/result ingestion
Create memory-owned SQLite schema/migrations and source-backed event index, supporting durable tool outcomes, Bash command, cwd, status, exit code, timestamps, error previews, output refs and source IDs. Incremental backfill, idempotency and redaction before indexing. **Acceptance:** retries do not duplicate events; exact linkage after restart; cross-session retrieval, no secret leaks. Dependencies: I0.

## I1b — Small-model tool overview/search/details
Native methods: `get_tool_call_overview`, `find_tool_calls`, `get_tool_call_details`. Summary groups by tool name and status, with counts and examples. Search by tool name, status, regex or text. Details connect each call and result and point to original full output. All responses bounded, paginated and source linked. **Acceptance:** find last failed Bash and full output without full session; tests for pending, unknown and deleted source. Dependencies: I1a.

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

## NEW P0: Context Projection v1 — reduce old tool outputs in Build

See `CONTEXT_V1.md`. Implement a flag-gated in-memory substitution of older completed successful tool-result text at provider-turn assembly, preserving call/result envelopes, IDs, user messages, system epochs and native continuation metadata. Require retrievable originals, explicit fallback and A/B cost/quality tests. Do not replace all session history.
