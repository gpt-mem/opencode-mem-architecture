# OpenCode MEM — Operational Memory Architecture

Status: proposed, implementation-ready roadmap (2026-10-09)
Architecture home: `gpt-mem/opencode-mem-architecture`; implementation: `gpt-mem/opencode-mem` (`dev`).

## 1. Goal and scope

Build a built-in, deterministic-first Operational Memory for coding workflows. Preserve original OpenCode sessions as the source of truth. Index tool calls and outcomes, Bash executions, files, PR/issues/commits, URLs, JSON/XML/HTML structure, code snippets, explicit decisions and constraints. Offer compact discovery and exact retrieval via native tools, CLI and MCP-compatible API. In the first release, implement a narrowly scoped, opt-in reduction of **old successful tool-result payloads** at provider request assembly, alongside tool-call indexing and overview. Keep all source history, system-context epochs and protocol envelopes intact. Full memory-first history replacement is deferred.

This product is optimized first for small/cheap coding agents that need straightforward tool names and simple inputs. It must work offline without embeddings or LLM calls. Embeddings are optional after the deterministic baseline works; semantic retrieval must not silently replace exact/regex.

## 2. Existing OpenCode components to reuse (verified on `dev`)

- `packages/core/src/session/history.ts`: `entriesForRunner` selects persisted history after last compaction plus applicable mid-conversation system messages; do not change for iteration 1.
- `packages/core/src/session/runner/llm.ts`: prepares Context Epoch, loads history, builds provider request, publishes tool outcomes. No modification to provider message assembly for iteration 1.
- `packages/core/src/session/context-epoch.ts`: baseline/system snapshot and baseline sequence. Keep independent; never promote retrieved untrusted memory to system authority.
- `packages/core/src/tool-output-store.ts` and `CONTEXT.md`: managed output files already preserve bounded tool results. Index their refs rather than duplicating large bytes.
- OpenCode SQLite database, session message/event tables, Todo table and existing built-in tool registrations. Add memory-owned tables using existing migrations/service; no separate SQLite file in fork.

Before implementation verify exact event schemas, managed-output retention, and whether current `dev` already includes equivalent indexes. Do not rely on legacy `packages/opencode` internals if new core is authoritative.

## 3. Architecture

```
OpenCode session events / tool outputs / TODO / files
                 |
         Event/Artifact Indexer
     (deterministic, idempotent, redacted)
                 |
       SQLite Operational Memory
 [tool_calls, tool_results, artifacts, artifact_sections,
  memory_records, memory_versions, memory_refs, index_cursor,
  FTS5 index, optional embedding chunks]
                 |
       Memory Query / Retrieval Core
              /       \
       Native tools   CLI/MCP adapter
```

Ingestion must happen at durable tool-settlement/event boundaries, not only from model-visible truncated strings. Store source IDs/pointers and short indexable snippets; original session/events/managed output remain authoritative. Backfill already persisted sessions incrementally with cursor and stable dedupe keys. All writes transactionally bound to index cursor. Files get content hash/version and manifest; large raw content is not copied to the memory table. Missing source must be explicitly reported.

## 4. Data model (logical)

- `mem_tool_call`: `id`, `session_id`, `assistant_message_id`, `call_id`, `tool_name`, `args_redacted`, `started_at`, `completed_at`, `status`, `error_code`, `exit_code`, `duration_ms`, `cwd`, `output_ref`, `output_preview`, `source_seq`, `source_hash`; unique source tuple, indexes on `(session_id, tool_name, status, started_at)`.
- `mem_artifact`: `artifact_id`, `kind`, `uri/path`, `title`, `mime`, `content_hash`, `version`, `created_at`, `source_session_id`, `source_call_id`, `metadata_redacted`, `availability`.
- `mem_artifact_section`: `artifact_id`, `section_id`, `heading`, `line_start`, `line_end`, `snippet_redacted`, `content_hash`; FTS5 for searchable content.
- `mem_entity_ref`: typed relationship from event/artifact to canonical GitHub PR/issue/commit, URL, file, endpoint or code snippet; original text and normalized identifier. No guessed PR status; optionally enrich via explicit GitHub connector later.
- `mem_record`: `memory_id`, `type` (`decision`, `constraint`, `evidence`, `artifact`, `user_signal`, `work_state`, `failed_approach`, `rationale`), `subject`, `content_redacted`, `status`, `scope`, `authority`, `recorded_by`, `decided_by` where applicable, `created_at`, `updated_at`, `current_version`.
- `mem_record_version` + `mem_evidence_link`: append-only changes with source refs, reason and supersession.
- `mem_index_cursor`: source, cursor/seq, schema/extractor version, last indexed, failure state.
- `mem_fts`: FTS5 text index on redacted searchable previews, paths, headings, titles, commands. Regex on bounded filtered candidate sets using a safe implementation; exact and substring accessible separately.

Never persist raw credentials or secret-bearing tool args to FTS, logs, embeddings, error previews, or traces. PII indexed only when permitted; redact before indexing. `tenant/scope` must be validated server-side in multiuser operation.

## 5. Deterministic extractors, priority

1. Tool-call envelopes: calls/results, tool name, args metadata, status, durations, exit/error, full output pointer. A tool overview must report counts by tool, successes/errors, recency and source IDs.
2. Bash: command, cwd, exit, stderr preview and file/path/URL observations. Treat exit code as authoritative; a string containing 'error' is not proof of failure.
3. Git/GitHub: canonical PR/issue URLs and `owner/repo#N`, SHA, branch, git CLI operations. Distinguish mere mention vs actual observed action vs verified GitHub state.
4. URLs/endpoints: normalized URL (strip/redact sensitive query params), HTTP method, response status, origin call.
5. Artifacts: manifests for Markdown/HTML/JSON/XML/structured reports, file titles, headings, section spans, code fences, code snippet locations. Preserve text/code exactness; no LLM rewriting.
6. Structured large output: parse JSON/XML/HTML and provide shape preview (top-level keys, counts, path/section summaries, truncation flags), with exact source retrievable. Include YAML and CSV in parser feasibility tests, not mandatory initial support.
7. Todo references and agent-authored decisions/constraints: do not shadow OpenCode TODO truth; explicit DecisionWrite wrapper on generic memory put, with provenance and validation.

## 6. Agent-facing tools (small-model friendly)

MVP discovery/detail split:

- `get_tool_call_overview(session_id?, project_id?, limit?)`: tool names, call counts, success/failure counts, recent activity, sample ids.
- `find_tool_calls(tool_name?, status?, text?, regex?, session_id?, limit?)`: compact rows with call ID, status, time, command preview and evidence ref. `status` supports success, failure, pending, unknown.
- `get_tool_call_details(call_id, include_output?, max_chars?)`: exact call+result, bounded preview, full-source/file ref.
- `find_agent_artifacts(kind?, query?, match?, limit?)`: PRs, issues, URLs, documents, snippets, structured data manifests.
- `get_agent_artifact(artifact_id, section_id?, max_chars?)`: exact original fragment + path/line references and truncation indicator.
- `put_in_operational_memory(entries[], idempotency_key?)`: typed explicit memories, batch all-or-nothing; never allow model to self-assert system authority.
- `search_operational_memory(query?, type?, match?, scope?, limit?)`: exact/substring/FTS5/regex; no model required.
- `get_operational_memory(memory_id)`: provenance, revisions, evidence refs.
- `get_operational_memory_context(task_id?, session_id?, max_chars?)`: bounded operational overview, current TODO/work state, decisions, constraints, recent failures. This is on-demand; not automatically added to prompt in MVP.
- `commit_operational_memory_state(task_id, expected_version, next_action, memory_refs, idempotency_key)`: atomic work-state checkpoint; no external side effects implied.

Return concise JSON by default. Every list is pageable/bounded with total (when cheap), `has_more`, continuation cursor and source references. Full outputs on demand only; support grep/regex filtering by exact source.

## 7. Context changes (explicitly later, gated)

Iteration 1 keeps `SessionHistory.entriesForRunner`, `SessionContextEpoch`, Build/Explore prompts and compaction intact, but adds an opt-in in-memory projection of older settled successful tool-result text immediately before model-message conversion. See `CONTEXT_V1.md`. Instrument actual token usage, cache reads/writes, tool schemas bytes, message/history bytes and assistant success metrics. Future feature `memory_context` experiments with keeping valid recent conversation/tool protocol plus a compact memory selection. New behavior must be reversible per session. Context Epoch baseline and trust boundaries must stay intact. Never drop unmatched tool call/result or provider continuation metadata. Compare against identical-session baseline and cost/quality, including prompt-cache impact.

## 8. Security, recovery, nonfunctional

- Secrets: redaction at ingestion; fail closed for unsafe previews, never index auth headers/tokens; credential metadata separate later. No memory tool returns plaintext credentials.
- Data isolation: per user/project/session scoping and ACL, local file permissions; external source refs validated before dereference.
- Reliability: ingestion idempotent, crash/resume backfill via cursor, transactionally consistent indexes, migration rollback/backups, schema versioning, non-blocking write queue where safe.
- Performance: exact & FTS search interactive at reasonable corpus size; benchmark with 100k+ tool events and large outputs, report P50/P95 and DB size.
- Failure mode: memory index failure must not break coding tools/Session Runner; structured degraded status, repair/reindex command.
- Regex limits and safe parser bounds; no unbounded scans or billion-byte parsing.
- Tests offline: synthetic tool events, real-shaped fixtures, nested JSON/XML/HTML, escaped URLs, duplicate/retried events, redaction, PII, GitHub mentions vs confirmed actions, compaction/pruning, missing/deleted sources, concurrent writes.

## 9. Iterations and gates

**I0 — Audit + baseline (no behavior change)**: confirm current fork's authoritative event schema and tool lifecycle, existing truncation/managed-output behavior, migrations, source refs; add payload metrics and representative fixtures. Gate: reproducible baseline measurements and source map.

**I1 — Index tools first**: native SQLite schema, migration, ingestion+backfill for tool calls/results and Bash; `get_tool_call_overview`, `find_tool_calls`, `get_tool_call_details`. Gate: accurate call/result pairs, error statuses, cross-session search, dedupe, secret redaction, restart/rebuild.

**I2 — Artifact indexes**: URLs, GitHub references, documents, snippets, Markdown manifest/sections and JSON/XML/HTML structural previews; search/get artifact APIs. Gate: links and source ranges exact, no false verified status, large outputs bounded and retrievable.

**I3 — Typed writable memory**: decisions, constraints, failed approaches, work_state, user signals, Memory Commit, versioning, source authority; native tools + MCP/CLI parity. Gate: decisions provenance, supersession, TODO not duplicated, simple LLM can select tool.

**I4 — Semantic experiment (optional)**: embedding chunks for historical text/sections, vector index + hybrid query; query using active task state rather than only 'continue'. Gate: semantic quality/cost/latency measured, deterministic fallback.

**I5 — Context assembly experiment (separate PR)**: behind feature flag, compare compact SQL projection + recent protocol-safe tail against original full history. Gate: task success not materially degraded, measurable net provider cost/latency improvement (including caching), instant rollback.

Never merge an iteration on token saving alone without functional correctness tests. Use issue → short branch → PR (draft acceptable) → CI; production behavior unchanged by default.

## 10. Open questions for implementation audit

- V2 event schema: exact point for tool-result persistence before bounded model projection?
- Actual managed output retention/cleanup and whether document artifacts are stable across sessions?
- Existing parser from prior work for JSON normalization: find and reuse rather than reimplement; test path and license.
- FTS5 and regex extension availability in runtime SQLite on macOS/Windows/Linux.
- Direct SQL integration migration impacts on upstream fork updates.
- Whether `build` is current agent ID and whether custom subagent names differ in this fork.

## 11. First-release context projection amendment (2026-10-10)

See `CONTEXT_V1.md` for eligibility rules, source-reference guarantees, fallback, metrics and A/B tests. The full-history replacement is not in MVP; initial savings come from old successful tool outputs only.
