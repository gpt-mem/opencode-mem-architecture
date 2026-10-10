# OpenCode MEM — Context Projection v1 (implementation draft)

Status: proposed for first implementation; feature flag, default off until smoke tests. Target: `gpt-mem/opencode-mem` branch `dev`. Architecture: `gpt-mem/opencode-mem-architecture`.

## Goal

Deliver measurable first-release input-context reduction **and** a usable tool-call overview. Keep complete original OpenCode SQLite history, system-context epoch, original tool outputs and provider semantics. Reduce only the *model-visible projection* of older completed tool results. This is deterministic projection, not an LLM summary. Do not require embeddings, LLM extraction or external services in v1.

## Verified integration points

- `packages/core/src/session/runner/llm.ts`: `SessionContextEpoch.initialize/prepare` -> `SessionHistory.entriesForRunner(db, session.id, system.baselineSeq)` -> `toLLMMessages(context, model)` -> `LLM.request` -> `compaction.compactIfNeeded` -> `llm.stream(request)`.
- `packages/core/src/session/history.ts`: `entriesForRunner` selects rows after last compaction plus eligible system messages; it does not rank relevance. Do not change its SQL semantics.
- `packages/core/src/session/context-epoch.ts`: immutable baseline, snapshot, `baselineSeq` and mid-conversation system updates. Preserve unchanged.
- `packages/core/src/tool-output-store.ts`: existing managed output files for large tool outputs; use source refs instead of duplicating raw output.
- `CONTEXT.md`: context epochs, provider-turn boundaries, native continuation metadata, bounded tool output semantics.

## Minimal v1 design

At the provider-turn assembly boundary, read `entriesForRunner` as before. Before `toLLMMessages`, call `MemoryContext.project(entries, options)` on an **in-memory copy**. Index all completed tool call/results asynchronously/idempotently from durable source events. Project only **old completed tool-result text** whose original is retrievable. Replace with a small stable marker containing `call_id`, `tool_name`, `status`, `source_ref`, `preview` and explicit `get_tool_call_details` instruction. Never rewrite or reorder user instructions, assistant prose, system messages, tool call IDs/arguments, current in-flight calls, pending results, tool protocol envelopes, model-native reasoning/continuation metadata, or messages after the latest user turn. No blanket deletion of tool calls. Avoid reducing exact code or files in the most recent work turn.

Eligibility: completed + settled + older than the current user turn + raw source confirmed retrievable + not a protected tool/output + above `min_output_chars` (proposed 2000) + context feature enabled. Preserve the most recent 2 user turns completely initially; if uncertain, preserve more. Protect latest failed command and test result until subsequent successful remediation; for v1 simplest policy: never shrink failed tool results. Protect memory-tool results. No arbitrary semantic classification required.

For the first implementation, preserve provider-protocol-valid tool call/result pairs by **substituting only textual content inside a settled tool-result envelope**, never deleting either side. Ensure tool output is not changed during an unfinished provider continuation. Exact compatibility validation is mandatory for all model routes in use; on unsupported message shapes fall back to original projection.

Example (illustrative):

```
[tool-result: compacted]
tool=bash; call_id=call_104; status=success
preview="Tests passed (32/32)."
source_ref=ocmem://session/ses_1/tool/call_104
For full output use get_tool_call_details(call_id="call_104").
```

This is a tool-result payload, **not** a new system instruction. Use existing tool-output metadata where available; don't invent success or counts from arbitrary stdout.

## First agent-facing methods

1. `get_tool_call_overview(session_id?, limit?)` -> grouped tool counts, status breakdown, recent call IDs, compact examples, unknown/pending separate.
2. `find_tool_calls(tool_name?, status?, text?, regex?, session_id?, limit?)` -> bounded compact results with source IDs, timestamps, outcome and output preview.
3. `get_tool_call_details(call_id, max_chars?, include_output?)` -> original call+result (bounded), source URI for full retrieval, `truncated` flag and `source_available`.

Keep tool schema simple for cheap models. One underlying query service for all three. Every call/result has stable source refs and redacted indexed fields. Tool overview must be callable without an LLM and return useful results on existing sessions.

## Context projection algorithm (pseudocode)

```
entries = SessionHistory.entriesForRunner(db, session.id, baselineSeq)
// do not change entries or database
indexer.enqueueDurableSources(session.id)
if (!flagEnabledFor(session, agent)) return originalRequest(entries)
projected = entries.map(clone)
for each settled tool result in projected:
    if eligible(result) && index.hasRetrievableOriginal(result.source):
        result.modelVisibleText = compactMarker(result)
request = buildRequest(toLLMMessages(projected, model))
if (!validateProviderMessages(request)) return originalRequest(entries)
return request
```

Prefer a single, explicit `project()` hook between history load and `toLLMMessages`, without modifying `entriesForRunner`, `toLLMMessages`, compaction, tool execution, or the System Context Epoch. Preserve message order and IDs. Indexer is separate and non-blocking; projection may only compact a result when its original is confirmed available.

## Measurement and acceptance

Log metadata only: provider turn ID, model/agent, total bytes and estimated tokens before/after, number of projected outputs, actual billed input/cache-read/cache-write tokens, latency, and fallback reason. No raw secrets or user content in telemetry. Report cache-adjusted cost, not just raw bytes. Set a **hypothesis** of 20–40% reduction in input bytes for tool-heavy long Build turns; not a guaranteed target. First acceptance is measurable reduction in a real tool-heavy fixture with zero loss of source access, zero invalid provider messages and no regression in a minimal edit/test/continue workflow.

Tests: baseline parity when flag off; no compaction of current turn, pending/error calls, missing-source output, native continuation metadata; correct tool-result pairing and order; idempotent ingestion; regex invalid-input handling; redaction; concurrent sessions; restart; fallback on DB/index errors; OpenCode compaction still works; context epoch updates remain correct; cache cost reported; native Build/Explore tool access unaffected.

## First development sequence

1. Trace actual fork `dev` code and add read-only request-size metrics (no behavior changes).
2. Add memory SQLite tables/indexing cursor + durable tool-result ingestion and backfill.
3. Implement overview/search/details and integration fixtures.
4. Add `MemoryContext.project()` behind `memory_context_v1` flag (off by default); narrow eligibility to old successful tool-result payloads.
5. Run Build smoke tasks and A/B: flag off/on; validate cost, context integrity, tool results, recovery; then opt-in to self-hosted development sessions.
6. Only after results, add URL/GitHub/Markdown manifest, JSON/XML/HTML structural previews, decisions and embeddings. The index can evolve without changing original session storage.

## Explicit non-goals

No vector search in first context reduction, no LLM reranker, no rewriting all user/assistant messages, no global compaction removal, no new credential store, no direct deletion of SQLite history, no unbounded regex scans, no default-on rollout before tests.
