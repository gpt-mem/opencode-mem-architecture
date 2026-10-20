# OpenCode MEM — Operational Memory Architecture

Status: **v2-линия `main`** (порт апстрима v2.1.0); экономия токенов через штатное v2-усечение вывода тулов + компактификацию; ядро оперативной памяти (mem_record + put/search/get) в `main` с 2026-10-20 (PR #179/#180/#183). v1-линия `memory-context-v1` архивирована (см. «Чем наш форк отличается…» ниже). Актуально 2026-10-20.
Architecture home: `gpt-mem/opencode-mem-architecture`; implementation: `gpt-mem/opencode-mem`, целевая линия `main` (ранее `v2-base`).

## 1. Goal and scope

Build a built-in, deterministic-first Operational Memory for coding workflows. Preserve original OpenCode sessions as the source of truth. Index tool calls and outcomes, Bash executions, files, PR/issues/commits, URLs, JSON/XML/HTML structure, code snippets, explicit decisions and constraints. Offer compact discovery and exact retrieval via native tools, CLI and MCP-compatible API. In the first release, implement a narrowly scoped, opt-in reduction of **old successful tool-result payloads** at provider request assembly, alongside tool-call indexing and overview. Keep all source history, system-context epochs and protocol envelopes intact. Full memory-first history replacement is deferred.

This product is optimized first for small/cheap coding agents that need straightforward tool names and simple inputs. It must work offline without embeddings or LLM calls. Embeddings are optional after the deterministic baseline works; semantic retrieval must not silently replace exact/regex.

## Чем наш форк отличается от основного OpenCode (актуально: 2026-10-20)

Форк `gpt-mem/opencode-mem`, целевая линия — **`main`** (переименована из `v2-base`, PR #169), база — апстрим `anomalyco/opencode` **v2.1.0** (порт PR #171). Старая v1-линия (`memory-context-v1`, `dev`) архивирована как `archive-v1-line`; `packages/opencode` (V1-сессия) удалён — форк теперь чистая v2-раскладка (`packages/core`/`cli`/`tui`/`server`).

Экономия токенов достигается **штатным v2-усечением вывода тулов (2 КиБ / 2000 строк)** + **сессионной компактификацией**, а не отдельным memory-слоем. Ядро Operational Memory (write/read/recall: таблица `mem_record`, PII-redaction, store, тулы `put/search/get_operational_memory`) **портировано в v2** (PR #179/#180, слайсы 1–2 из issue #178). Остальной слой v1 (проекция `MemoryContext`, discover-тулы `find_tool_calls`/`get_tool_call_overview`, intent-tracker, cache-mark/cache-mask ledger, `schedule_job`) **не перенесён** — `cache-mark.ts`/`cache-mask.ts` внесены в `must_not_return` профиля дозора.

| Компонент | Что добавлено | Файл в коде | Как включить | Статус |
|---|---|---|---|---|
| Усечение вывода тулов | Лимит вывода инструмента в контексте модели: `MAX_BYTES = 2 KiB`, `MAX_LINES = 2000`. Всё длиннее пишется на диск (managed output, retention 7 дней), в контекст уходит усечённый превью + маркер `Full output saved to:` | `packages/core/src/tool-output.ts` (`ToolOutput`), конфиг-плагин `packages/core/src/config/plugin/tool-output.ts`, схема `packages/schema/src/config/tool-output.ts`, TUI `packages/tui/src/util/collapse-tool-output.ts` | конфиг `tool_output` (`max_bytes`/`max_lines`); дефолт 2 КиБ/2000 без флага | В `main` (PR #148, squash `58eaaa8b8b7b`); тесты `packages/core/test/tool-output.test.ts`, `packages/core/test/config/tool-output.test.ts` |
| Детектор doom-loop | Advisory-предупреждение, когда последние 4 завершённых tool-call имеют одинаковые tool+input+output: «Doom loop suspected… change the approach». Cross-step (каждый повтор — своё assistant-сообщение). Автостопа нет | `packages/core/src/session/runner/doom-loop.ts`, хук в `packages/core/src/session/runner/llm.ts` | без флага — всегда; порог `THRESHOLD=4` | В `main` (PR #154, squash `02f0d458a244`); тест `packages/core/test/doom-loop.test.ts` |
| Cross-spawn spawner | Свой спавнер держит broken pipe (EPIPE) от затирания ответа ребёнка — код возврата и stderr ребёнка остаются ответом | `packages/util/src/cross-spawn-spawner.ts` | без флага | В `main` (PR #153, squash `88970e3ae9a3`); тест `packages/core/test/effect/cross-spawn-spawner.test.ts` |
| Идемпотентная миграция БД | `provider_cache_mark` создаётся через `CREATE TABLE IF NOT EXISTS` — форк не падает на боевой базе, где таблица осталась от удалённого леджера | `packages/core/src/database/migration/20261019172723_colossal_sue_storm.ts` | — (миграция) | В `main` (PR #164, squash `663876427c`); регрессионный тест |
| Operational Memory (ядро) | Таблица `mem_record` (project-scoped, versioning через `supersedes`, `MAX_CHAIN=10`), модуль PII-redaction, store `writeBatch/search/getWithChain`, тулы `put_in_operational_memory` / `search_operational_memory` / `get_operational_memory` через Plugin API (Location/Permission-scoped). PII-редакция до персиста; `authority=agent` unless `decided_by`; search hint при 0 совпадений | `packages/core/src/session/mem-record.sql.ts`, `mem-record.ts`, `mem-record-store.ts`, `pii.ts`, `packages/core/src/tool/plugin/operational-memory.ts`, регистрация в `packages/core/src/plugin/internal.ts` | без флага — всегда (как core Plugin API) | В `main` (PR #179 слайсы 1–2 `03349ef2b2`, PR #180 слайс 3 `dfde60d61`); тест `packages/core/test/tool-operational-memory.test.ts` (5 кейсов) |
| Идемпотентная миграция `mem_record` | `CREATE TABLE IF NOT EXISTS` — v1-миграция `20261011235047_mem_record` могла уже создать таблицу в общей базе; форк раньше падал и не открывал её (selftest NOT-BOUND, issue #182) | `packages/core/src/database/migration/20261020143020_volatile_mister_fear.ts` | — (миграция) | В `main` (PR #183, squash `256e068a4d`); CI зелёный на linux+windows |
| Общая база со стоком | Сборка задаёт `OPENCODE_CHANNEL=latest`, иначе `database-path.ts` берёт `opencode-<канал>.db` и форк открывает пустую параллельную базу | `packages/cli/script/build.ts` + env `OPENCODE_CHANNEL` | env при сборке `OPENCODE_CHANNEL=latest` | В `main` (PR #162, squash `d980227b50`) |
| README-раздел установки | «OpenCode MEM (this fork)»: релиз/исходники/откат/проверка SHA; помечено, что `npm i -g @opencode/cli` — это upstream | `README.md` | — | В `main` (PR #157, squash `d5ecd5409ff4`) |

### Что держим как терминальный агент

- `packages/tui`, `packages/cli`, `packages/core`, `packages/server` — без нативного приложения (`packages/app`/`desktop`) и без веба.
- Codemode (`packages/codemode`), Ladder-провайдер, общая база сессий со стоком.
- Профиль продукта (для дозора по апстриму) — `opencode-mem-architecture/chain/upstream-policy.json`: `must_keep` = `tool-output.ts`, `shell.ts`, `doom-loop.ts`, миграции `colossal_sue_storm` + `volatile_mister_fear` (mem_record), `cross-spawn-spawner.ts`, `doom-loop.test.ts`, `mem-record.sql.ts`, `mem-record.ts`, `mem-record-store.ts`, `pii.ts`, `tool/plugin/operational-memory.ts`, `tool-operational-memory.test.ts`; `must_not_return` = `cache-mask.ts`, `cache-mark.ts`.

### Что НЕ перенесено из v1 (остальной Operational Memory-слой, удалён)

`MemoryContext.project`/`projectV1` (проекция контекста), discover-тулы `get_tool_call_overview`/`find_tool_calls`/`get_tool_call_details`/`find_pii`, intent-tracker + `OPENCODE_MEMORY_INTENT*`, cache-mark/cache-mask + `OPENCODE_MEMORY_CACHE_MARK`, first-delivery, reasoning-компакция, `schedule_job`, run-id-заголовок (`x-opencode-run-id`). Все 16 env-флагов `OPENCODE_MEMORY_*` из v1 в v2 не читаются. Портированы в v2 (PR #179/#180): `pii.ts`, `mem-record.ts`, `mem-record-store.ts`, тулы put/search/get_operational_memory, таблица `mem_record`.

Дозор за апстримом — `upstream-watch` (GHA, cron `17 */6 * * *`) + `upstream-policy.json` (классы PORT/ASK/SKIP); merge порта — за человеком. История v1-линии (48 коммитов `memory-context-v1`, PR #1–#72) — в git-истории форка и в `ITERATIONS.md`.

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

Index scope (contract, issue #34): memory tools (`find_tool_calls`, `get_tool_call_overview`, `get_tool_call_details`) never become candidates of `find_tool_calls` — otherwise every query indexes itself and a pattern present in one query propagates into the next search (PII self-spread). Their calls stay in session history and remain reachable through `get_tool_call_details(call_id)`; everything else (Bash, URLs, artifacts, tool results) stays searchable.

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

## 12. Next iteration plan (15 min)

**Goal:** Implement content-type-aware compression with retrieval.

### Compression types by content

| Content type | Compression | Storage | Retrieval |
|--------------|-------------|---------|-----------|
| Bash commands | Keep command + exit code + stderr preview | SQLite `mem_tool_call` | `get_tool_call_details(call_id)` |
| URLs/endpoints | Keep URL + method + status | SQLite `mem_entity_ref` | `find_agent_artifacts(kind="url")` |
| Markdown/JSON/XML | Keep manifest + sections | SQLite `mem_artifact` + `mem_artifact_section` | `get_agent_artifact(artifact_id, section_id)` |
| Decisions | Keep decision + why + timestamp | SQLite `mem_record` (type=decision) | `search_operational_memory(type="decision")` |

### PII handling (no compression)

PII is **not compressed** — it is **tagged and indexed** for discovery.

| PII type | Detection | Storage | Retrieval |
|----------|-----------|---------|-----------|
| Email | Regex | tagged on demand in the session tool-call index (PR #53) | `find_pii(type="email")` |
| Phone | Regex | tagged on demand in the session tool-call index (PR #53) | `find_pii(type="phone")` |
| Credit card | Regex + Luhn | tagged on demand in the session tool-call index (PR #53) | `find_pii(type="credit_card")` |
| API key | Pattern + `[REDACTED:*]` placeholder | tagged on demand in the session tool-call index (PR #53) | `find_pii(type="api_key")` |
| Name | NER (optional) | not implemented | not implemented |

**As shipped (PR #53):** no separate `mem_pii` table — `find_pii(type?, limit?)` (V1+V2) scans the same session-scoped tool-call candidates `find_tool_calls` searches and runs `PII.scan` over each haystack. Detection is **not** permission: the tool returns `call_id`, per-carrier counts and the surrounding line with the value replaced by a placeholder (`PII.mask`), never the value itself; carriers already masked by `PII.redact` in input summaries still count via their placeholder, so a credential that lived only in a command argument stays visible to the audit. `find_pii` is in `MemoryTools.names` (never a search candidate, counted in `memory_tools`) and in `MEMORY_TOOL_PATTERN` (its results are never compacted).

PII is **never hidden** — LLM finds carriers with `find_pii()` and loads the raw value through the authorized `get_tool_call_details(call_id)`.

### Implementation steps

1. **Add content-type detection** in `packages/core/src/session/runner/llm.ts`
   - Detect tool result type (bash, url, file, json, etc.)
   - Tag with content type before projection

2. **Create compression strategies** in `packages/core/src/session/compression/`
   - `bash.ts` — keep command, exit, stderr preview
   - `url.ts` — keep URL, method, status
   - `artifact.ts` — keep manifest + sections
   - `decision.ts` — keep decision + why + timestamp

3. **Add retrieval tools** in `packages/core/src/tool/`
   - `get_tool_call_details(call_id)` — already planned
   - `find_agent_artifacts(kind, query)` — already planned
   - `search_operational_memory(query, type)` — already planned

4. **Update projection logic** in `packages/core/src/session/projector.ts`
   - Apply compression based on content type
   - Keep source reference for retrieval
   - Never hide from LLM — always provide retrieval path

### Acceptance criteria

- [ ] Bash results compressed to command + exit + stderr preview
- [ ] URL results compressed to URL + method + status
- [ ] Artifacts compressed to manifest + sections
- [ ] All compressed content retrievable via tools
- [ ] No content hidden from LLM — always provide retrieval path
- [ ] Token reduction measurable (target: 20-40% for tool-heavy sessions)

### Next steps after this iteration

1. Add MCP-compatible API for external tools
2. Add CI with token reduction tests
3. Test on free LLM (Gemini Flash, etc.)
4. Test on paid LLM (Mimo Flash 2.6)
5. Compare with original OpenCode

## 13. Unified mask: provider cache-mark ledger (2026-10-11)

Полное описание: `../cache-intent-research/UNIFIED-MASK.md` (research-repo). Кратко:

### Идея

Вместо TTL-догадок храним по одному числу на провайдера: **сколько префикса провайдер подтвердил через `usage.cache_read` в прошлом ответе** (`mark_tokens`). Всё что выше mark при следующей отправке — сжатая проекция (маркеры + storage). Ниже mark — байт-в-байт (cache hit).

```
для провайдера P:
  prefix[0..mark] → байт-в-байт (проверка hash-инварианта)
  prefix[mark..]  → сжатая проекция (MemoryContext)
после ответа:
  mark = usage.cache_read_tokens   (подтверждение постфактум)
```

### Почему это решает всё сразу

| Свойство | Следствие |
|---|---|
| Бесплатный провайдер: mark = 0 | сжимается всё → трек A — частный случай того же пайплайна |
| Платный: mark растёт с ответами | свежий хвост всегда идёт сжатым → compact-at-first-delivery (B0) автоматически |
| LRU-вытеснение провайдером | cache_read < mark → mark падает → самоисправление, TTL не нужен |
| Смена провайдера (ladder rung) | другая строка ledger, ничего не инвалидируется |
| Каскад «решили резать выше — режем и ниже» | автоматически: область сжатия всегда суффикс над mark |

### Схема

```sql
provider_cache_mark (
  provider_id   TEXT PRIMARY KEY,   -- из usage последнего ответа
  mark_tokens   INTEGER NOT NULL,   -- подтверждённая граница кеша
  prefix_hash   TEXT,               -- hash префикса на момент подтверждения
  last_used_at  INTEGER
)
```

### Инварианты

1. **Ниже mark не мутировать.** Нарушение hash-проверки = баг проекции.
2. **mark растёт/падает только по фактическому usage** провайдера-ответа — никаких предсказаний TTL — и **сбрасывается в 0 при отказе запроса** (issue #39, PR #41: abort / таймаут / сетевая ошибка / `provider-error`; кеш после отказа недостоверен, а полный верbatim-префикс в упавший кеш — самая дорогая ошибка). Context-overflow из исключений: провайдер отклонил запрос до кеша, подтверждённый mark валиден. Self-heal: следующий подтверждённый ответ пересчитывает mark через `applyUsage`. **Единственное осознанное отклонение от «без предсказаний TTL» — idle-окно** (issue #39, PR #47): если последнему подтверждению провайдера больше `OPENCODE_MEMORY_MARK_IDLE_MS` (default 30 мин, `0` = off), `markIndexFor` read-only возвращает 0 и запрос уходит компактной проекцией — только на первом шаге хода (`step === 1`; посреди задачи in-flight владеет кешом, время само по себе mark не сбрасывает). Обе ошибкиguess стоят один ход и лечит `applyUsage`; инвариант «ниже mark не мутировать» (п.1) читается относительно текущего, непросроченного mark — просроченное подтверждение таковым не считается.
3. **Ladder API не меняется** — ledger полностью на нашей стороне (SQLite opencode). Провайдер берётся из `usage.providerID` последнего ответа, не из конфига.
4. IntentTracker решает КОГДА осознанно сбросить mark (смена интента); ledger решает ЧТО сжимать между сбросами; отказ запроса сбрасывает mark консервативно (п.2); долгая пауза объявляет подтверждение протухшим по idle-окну (п.2).

### Связь с компонентами

- `MemoryContext.project` — становится «маской»: получает mark, сжимает только suffix (уже чистая pure-function)
- B0 (issue #23, acceptance GO) — реализуется ledger-политикой, а не отдельным флагом
- IntentTracker (PR #26, day 1 merged) — логирует сигналы смены интента; day 2 (рез по смене) сбрасывает mark осознанно
- Трек A (OPENCODE_MEMORY_CONTEXT на бесплатных) — частный случай mark=0

### Требуемое тестовое покрытие (обязательно до merge)

- [x] **Unit: ledger basics** — mark растёт по cache_read, падает когда cache_read < mark, новый провайдер = строка с mark=0 (PR #32: applyUsage 5 тестов + 8 ledger/бd)
- [x] **Unit: инвариант префикса** — проекция не мутирует байты ниже mark; нарушение hash = откат к полному префиксу (fail-safe) (PR #32: hash mismatch / история сжалась → undefined)
- [x] **Unit: suffix-only сжатие** — при mark=K сжимается только message[K..], первые K байт-идентичны (PR #32: markIndex-опция project/projectV1, mark=0 паритет)
- [x] **Unit: смена провайдера** — два провайдера, разные mark, не пересекаются (PR #32)
- [x] **Integration: mark=0 = трек A** — unit-паритет mark=0 закрыт в PR #32; живой e2e на ladder/free выполнен (2026-10-11, см. ITERATIONS): **премисса «бесплатный провайдер = zero-cache» опровергнута** — ladder-прокси кеширует все модели (cache_read>0), mark=0-окно живёт только до первого подтверждения кеша (t1→t2 наблюдалось live), дальше ledger корректно переходит в floor-режим; byte-parity на zero-cache провайдере остаётся unit-гарантией. Побочный результат: fdmark на втором провайдере −55% provider-visible, needle OK; bare CACHE_MARK в boundary-режиме на кеширующем провайдере = no-compaction (продакшен-конфиг — CONTEXT+FIRST_DELIVERY+CACHE_MARK)
- [x] **Integration: B0 через ledger** — needle-сценарий bench23 arm fdmark (PR #33): свежий delivery компактируется выше mark, ретрив работает (needle-recall 100%), cost ≈ fd
- [x] **Property: fail-safe** — при integrity-ошибке ledger (hash mismatch, история сжалась ниже mark) → полный префикс, сжатие off. Никогда не ломаем запрос (PR #32). **Уточнено PR #33:** «нет строки» = mark 0 (элигабельно всё), НЕ verbatim — иначе первый ход провайдер кеширует полный bulk и mark закрепляет его навсегда
- [x] **A/B acceptance** — cost/session ≤ baseline, needle-recall 100%, через agent-benchmarks (PR #33): off $0.0225 → fdmark $0.00141 (−93.8%), input 154k → 4.3k, 4 сессии приаттачены к PR #33
- [x] **P1: B0 = ledger-политика** — убрана необходимость одиночного флага FIRST_DELIVERY рядом с CACHE_MARK (**PR #36, смержен** squash `2af044d478`): `firstDeliveryPolicy` включает first-delivery при `OPENCODE_MEMORY_CACHE_MARK=1` по умолчанию, parity-тест implied == explicit FD байт-в-байт; продакшен-конфиг = `CONTEXT=1 CACHE_MARK=1`. Issue #29 закрыт

Реализация первой стадии: PR #32 (`cache-mark-ledger`, флаг `OPENCODE_MEMORY_CACHE_MARK` off by default). Схема таблицы дополнена колонкой `mark_index` (конвертация токенов → индекс сообщений при record по sentCount; хранить только токены нельзя — pure-функция проекции работает с индексами). Хуки V1 (prompt.ts) + V2 (runner/llm.ts). Mark=0 байт-в-байт == поведение без ledger (keep-window/FD/intent-cut не меняются).

Реализация второй стадии: PR #33 (squash `4e411121e0`) — интеграционный acceptance-прогон вскрыл блокирующий баг семантики: mark_index рос до полной длины projected-запроса, компактированные сообщения падали ниже mark и пересылались сырыми оригиналами → мутация marker-префикса провайдера каждый ход → cost fdmark ≈ off ($0.0183). Фикс: (1) `recordUsage.sentCount` = `CacheMark.verbatimPrefixLength(projected, raw)` — mark покрывает только префикс, отправленный байт-в-байт; компактированный хвост остаётся над mark и ре-компактируется в идентичные marker-байты (append-only); (2) `markIndexFor`: нет строки → mark=0, fail-safe verbatim оставлен для prefix-hash mismatch/сжавшейся истории. Acceptance после фикса: cost $0.00141 (−93.8% vs off, −8% vs fd-only), needle-recall 100%, mark держится на verbatim-префиксе (mark=2), compacted растёт 1→6 по ходам.

- [x] **Сброс при отказе запроса (issue #39)** — `CacheMark.reset` роняет подтверждённый mark в `{0,0,null}`; self-heal через `applyUsage` по следующему usage; интеграционный тест session-runner: прогретый mark + падение провайдера → строка сброшена; context-overflow исключён (PR #41, V2 `SessionRunner`); прод-путь V1 `SessionPrompt` закрыт **PR #50** (`prompt.ts` после `handle.process` при не-overflow ошибке → reset; user-abort fiber-интом не доходит; регрессионный тест в `prompt.test.ts`: warm ledger → 400 → префикс ниже mark байт-в-байт, `markIndexFor=0`; без правки падает)
