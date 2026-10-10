# OpenCode MEM — Implementation Roadmap

Canonical architecture: `ARCHITECTURE.md`. Target implementation: `gpt-mem/opencode-mem` branch `memory-context-v1` (base `dev`).

**Статус 2026-10-11:** I1 выполнен (тулы overview/find/details влиты). Проекция контекста `MemoryContext` включается флагом `OPENCODE_MEMORY_CONTEXT`, delivery-режим B0 — `OPENCODE_MEMORY_FIRST_DELIVERY` (acceptance GO, −48.5%/−92.3% cost). Cache-stable граница (PR #21/#22), IntentTracker (PR #26/#28), UNIFIED-MASK ledger — issue #29 (см. ARCHITECTURE §13). CI: `mem-context.yml` зелёный.

| Iteration | Deliverable | Must not change | Acceptance | Статус |
|---|---|---|---|---|
| I0 | Trace active runner + event schema; measure request sizes | Session/LLM behavior | Reproducible measurements | ✅ |
| I1 | SQLite tool-event index + overview/search/details | Prompt assembly | Exact result linkage, redaction, backfill | ✅ (PR #6/#17/#24) |
| I2 | GitHub/URL/files/MD + JSON/XML/HTML manifests | Source content | Exact search, safe previews, original refs | ⬜ |
| I3 | DecisionWrite + typed memory + Memory Commit | OpenCode Todo authority | Provenance, versions, conflicts | ⬜ |
| I4 | Optional embeddings/hybrid search | Deterministic retrieval | Quality/latency evaluation | ⬜ |
| I5 | Flagged memory-first LLM context experiment | System Context Epoch | No protocol loss, rollback and A/B baseline | 🟡 (проекция за флагом, B0 GO) |

Recommended first user journey: install fork, run `npm test` and a GitHub CLI call, restart, then use `get_tool_call_overview` to discover previous tool use and `get_tool_call_details` to recover the actual error; no second LLM call or external service required.

Issue ordering: audit -> core ingestion -> tool API -> artifacts -> memory write -> embedding experiment -> context experiment. Issues may overlap only when contracts have been fixed and merge conflicts are minimized.

## Updated first-release priority (2026-10-10)

Ship the tool-call index/overview and an opt-in `MemoryContext.project` together. Projection only substitutes old, successful, settled tool-result payload text with a retrievable source marker; never changes original SQLite history or System Context Epoch. Measure actual billed/cache tokens and keep default off until tests. See `CONTEXT_V1.md`. Full memory-first context replacement remains a separate future experiment.
