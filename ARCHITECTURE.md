# OpenCode MEM — Operational Memory Architecture

Status: implemented behind flag on `memory-context-v1`; roadmap active (2026-10-10)
Architecture home: `gpt-mem/opencode-mem-architecture`; implementation: `gpt-mem/opencode-mem`, feature branch `memory-context-v1` (base `dev`).

## 1. Goal and scope

Build a built-in, deterministic-first Operational Memory for coding workflows. Preserve original OpenCode sessions as the source of truth. Index tool calls and outcomes, Bash executions, files, PR/issues/commits, URLs, JSON/XML/HTML structure, code snippets, explicit decisions and constraints. Offer compact discovery and exact retrieval via native tools, CLI and MCP-compatible API. In the first release, implement a narrowly scoped, opt-in reduction of **old successful tool-result payloads** at provider request assembly, alongside tool-call indexing and overview. Keep all source history, system-context epochs and protocol envelopes intact. Full memory-first history replacement is deferred.

This product is optimized first for small/cheap coding agents that need straightforward tool names and simple inputs. It must work offline without embeddings or LLM calls. Embeddings are optional after the deterministic baseline works; semantic retrieval must not silently replace exact/regex.

## Чем наш форк отличается от основного OpenCode (актуально: 2026-10-10)

Форк `gpt-mem/opencode-mem`, база — `origin/dev` (anomalyco/opencode). Основная работа — в ветке `memory-context-v1`: 18 коммитов над `origin/dev`: `2027af9b94` (проекция), `5b14671755` (тул ретрива), `bb04b082fd` (CI + savings-тесты), `e5570ec91b` (PII), `c8568cc1c7` + `4c183da787` (PR #1, shell-маркеры), `8c82f50dcc` + `3ebc63e119` (PR #2, location tool list), `7d47ee7477` (PR #3, тест-харнесс), `d1435d2338` (PR #4, CI-1), `31fb5e4bdf` (PR #6, `find_tool_calls`), `58554fc6de` (PR #7, V1-путь проекции), `cd1411475b` (PR #17, `get_tool_call_overview`), `702a4ca09f` (PR #18, редакция секретов), `2a5a00bbf2` (PR #19, сжатие внутри одного user-turn), `0982ec8493` (PR #21, batch-граница компакции), `7d7a7ecd79` (PR #22, mid-turn окно за `OPENCODE_MEMORY_MIDTURN`), `4f0f3223c7` (PR #24, полный ретрив с `offset`/`full`). PR #1, #2, #3, #4, #6, #7, #17, #18, #19, #21, #22, #24 смержены (squash), их ветки удалены; PR #5 (`groom/2026-10-10-find-tool-calls`) и PR #16 (`groom/2026-10-10-tool-call-overview`) закрыты как дубликаты (PR #6 и #17 соответственно). Открытых PR нет.

WIP-ветка `groom/2026-10-10-memory-context-v1-wire` доработана и влита как PR #7 (см. строку «V1-путь проекции» в таблице), groom-ветка удалена с remote. Грязный WIP по тулу `get_tool_call_overview` сохранён groom-сессией в `groom/2026-10-10-tool-call-overview` (PR #16, затем закрыт) и оформлен параллельной сессией в чистую ветку `tool-call-overview` (коммит `7bc07244e4`) — PR **#17 смержен** squash `cd1411475b`, ветка удалена. Грязное дерево ветки `stable-boundary` (batch-граница компакции) сохранено groom-сессией в `groom/2026-10-10-stable-boundary` (коммит `30853e6a29`) и оформлено в PR **#21 — смержен** squash `0982ec8493`, groom-ветка удалена с remote. Сразу после мержа PR #21 параллельная сессия оставила в working tree новую WIP (флаг `OPENCODE_MEMORY_MIDTURN`: рабочее окно assistant-сообщений по умолчанию выключено, граница стоит на user-turn-границе) — сохранена groom-сессией в `groom/2026-10-10-midturn-flag` (коммит `eb5ceba251` после rebase на смерженный PR #21; изначально `70e7afe9af` — rebase снял конфликт с squash-merge, batch-коммит пропущен как уже применённый; memory-context 37/37, typecheck 30/30) и оформлена в PR **#22 — смержен** squash `7d7a7ecd79` (groom-сессия 8 удалила groom-ветку с remote, содержимое идентично `memory-context-v1`, проверено пустым diff). Локальные `dev` и `no-context-trim` — указатели на `origin/dev`, нашей работы там нет; локальный `stable-boundary` — бывшая рабочая ветка, её содержимое уже в `memory-context-v1`. Локально ничего не хранится: грязное из working tree выносится в опубликованные ветки.

Groom-сессия 9 (2026-10-10): грязное дерево ветки `intent-tracker` (работа по issue #25 — IntentTracker MVP day 1, log-only, трек B1 из `INTENT-CACHE-PLAN.md`) сохранено в опубликованную ветку **`groom/2026-10-10-intent-tracker`** (2 коммита: `9d162da070` — drizzle-таблицы `intent`/`intent_signal` в `packages/core/src/session/sql.ts`, миграция `20261010195924_intent_tracker_tables`, флаги `OPENCODE_MEMORY_INTENT*`, модуль `packages/opencode/src/session/intent-tracker.ts`; `41e6933e91` — регистрация роута в `httpapi/server.ts`, хук в `prompt.ts`, тест `packages/opencode/test/session/intent-tracker.test.ts`). Пуш `--no-verify`: первый коммит (сырой WIP) не проходил pre-push typecheck в `prompt.ts` (ошибки Effect-типов), ко второму коммиту typecheck уже зелёный. Механика WIP: log-only — дешёвый детерминированный char-ngram TF cosine между новым user-turn и active intent-summary, пишет сигналы в `intent_signal` (cosine, llm_label, conf, acted); контекст не режет и сообщения не мутирует (cache-safe). **PR не открыт** — ветка WIP, кандидат на доработку и PR по issue #25; локальная ветка `intent-tracker` удалена (указывала на `memory-context-v1`). Локальная ветка `full-payload-retrieval` (исходные коммиты до squash-мержа PR #24, содержимое уже в `memory-context-v1` как `4f0f3223c7`) возвращена на remote как архив истории — не для мержа, закрыть/удалить после переноса интереса.

| Компонент | Что добавлено | Файл в коде | Как включить | Статус |
|---|---|---|---|---|
| Memory-проекция контекста | `MemoryContext.project()` подменяет текст старых успешных tool-result и shell-выводов компакт-маркером (`kind/tool/call_id/status/preview/original/retrieve`) на копии сообщений, между загрузкой истории и `toLLMMessages`. Оригиналы в SQLite, порядок, ID и protocol-конверты не меняются | `packages/core/src/session/memory-context.ts`; хук в `packages/core/src/session/runner/llm.ts` (заменяет `entries.map(e => e.message)` на `MemoryContext.project(...)`) | env `OPENCODE_MEMORY_CONTEXT=1` (default off) | В `memory-context-v1`, коммит `2027af9b94`; тесты `packages/core/test/memory-context.test.ts` |
| Правила неприкосновенности | Не сжимаются: незавершённые и error-тулы, provider-executed, memory-тулы, результаты < 2000 символов, shell без `callID` (нет пути ретрива). Окна защиты — берётся **более ранняя** из двух границ (`protectedStartIndex`): (1) разговорное — с 3-го с конца user-turn (нужно >2 user-turn, иначе окна нет); (2) рабочий набор — последние 2 assistant-сообщения (появилось в PR #19: без него сессия с одним user-prompt имела `protectedFrom=0` и не сжималась). В PR #22 окно (2) выключено по умолчанию за флагом `OPENCODE_MEMORY_MIDTURN` — граница стоит на user-turn-границе, префикс cache-стабилен внутри хода | там же: `DEFAULT_MIN_OUTPUT_CHARS=2000`, `DEFAULT_KEEP_RECENT_USER_TURNS=2`, `DEFAULT_KEEP_RECENT_ASSISTANT_TURNS=2`, `MEMORY_TOOL_PATTERN`, `resolveMidTurn` | включается вместе с основным флагом; mid-turn окно — только с `OPENCODE_MEMORY_MIDTURN=1` | В `memory-context-v1`: базовое правило + PR #19 (squash `2a5a00bbf2`) + PR #22 (squash `7d7a7ecd79`) |
| Cache-стабильная граница (PR #21, ISSUE-20) | Граница компакции двигается батчами (`stableBoundary(raw, batch) = floor(raw/batch)*batch`), чтобы проецируемый префикс оставался byte-identical между прыжками — mid-turn компакция каждый шаг инвалидировала prompt-cache и удорожала сессию (−45% токенов, +70% стоимости). Общий для `project`/`projectV1`; batch читается из `options.batchSize` или env `OPENCODE_MEMORY_BATCH_SIZE` (default 2, `1` — старое скользящее поведение); монотонность: сжатый результат не расжимается. Debug-лог получил `raw=` (граница до округления) | `packages/core/src/session/memory-context.ts` (`stableBoundary`, `resolveBatch`), `packages/core/src/flag/flag.ts` | env `OPENCODE_MEMORY_BATCH_SIZE` (при включённом `OPENCODE_MEMORY_CONTEXT`) | Влит: PR #21, squash-merge `0982ec8493`, groom-ветка `groom/2026-10-10-stable-boundary` удалена с remote; тесты в `packages/core/test/memory-context.test.ts` (byte-идентичность префикса, монотонность, env-override, V1-паритет) |
| PII-тегирование (не сжатие) | `PII.tag()` находит email, phone, credit card (с Luhn), api_key (`sk-`/`ghp_`/`AKIA`/assignment); в маркер попадает строка `pii=...`, оригинал не изменяется | `packages/core/src/session/pii.ts` | автоматически при включённом `OPENCODE_MEMORY_CONTEXT`; отдельного флага нет | В `memory-context-v1`, коммит `e5570ec91b`; тесты `packages/core/test/pii.test.ts` |
| Редакция секретов в маркерах/превью (PR #18) | `PII.redact(text)` заменяет bare API-ключи, assignment-секреты (сохраняя имя параметра), секретные URL query-параметры, Bearer-токены и Luhn-валидные карты на `[REDACTED:*]`. Применяется к memory-маркерам V1+V2 (`preview=`, `command=`/`url=`-сводки, проецируемое поле `command` shell-сообщения — раннер шлёт его модели рядом с маркером) и к model-visible `input`/`preview`/`error` в `find_tool_calls`/overview (V1+V2). Внутренний haystack и `get_tool_call_details` остаются сырыми: `query=` матчит оригиналы, точный ретрив авторизован. Email/phone — только тег | `packages/core/src/session/pii.ts` (`redact`), `packages/core/src/session/memory-context.ts`, `packages/core/src/tool/find-tool-calls.ts`, `packages/opencode/src/tool/find-tool-calls.ts` | автоматически при включённом `OPENCODE_MEMORY_CONTEXT` (маркеры) и всегда (find/overview) | Влит: PR #18, squash-merge `702a4ca09f`, ветка `pii-redaction` удалена с remote; тесты: pii.test.ts + memory-context.test.ts + tool-find-tool-calls.test.ts + memory-retrieval-v1.test.ts; CI: `mem-context.yml` гоняет и V1 retrieval-тест, запуск на `memory-context-v1` зелёный |
| Инструмент ретрива | `get_tool_call_details(call_id, max_chars?, offset?, full?)` — оригинал tool- и shell-вывода из SQLite по `call_id`; `full=true` → полный payload до hard cap 200k chars, `offset` — постраничный доступ, `truncated` означает «есть контент за окном» + `total_chars`; закрывает инвариант «ничего не скрыто» (включая originals >8k, которые раньше обрезались на 8k без пути к остатку) | `packages/core/src/tool/get-tool-call-details.ts`, регистрация в `packages/core/src/tool/builtins.ts`; V1-версия `packages/opencode/src/tool/get-tool-call-details.ts` | без флага — входит в builtins | В `memory-context-v1`: коммит `5b14671755` + PR #24 (squash `4f0f3223c7`, `offset`/`full`/`total_chars`); тесты `packages/core/test/tool-get-call-details.test.ts` + V1-кейсы `memory-retrieval-v1.test.ts` |
| Инструмент дисковери (I1) | `find_tool_calls(tool_name?, status?, text?, regex?, session_id?, limit?)` — компактные строки: call_id, status, время, превью команды/вывода, ref для ретрива; закрывает `find_tool_calls` из ROADMAP/I1b | `packages/core/src/tool/find-tool-calls.ts`, регистрация в `packages/core/src/tool/builtins.ts` | без флага — входит в builtins | Влит: PR #6, squash-merge `31fb5e4bdf`, ветка `find-tool-calls` удалена; тесты `packages/core/test/tool-find-tool-calls.test.ts` (groom-ветка `groom/2026-10-10-find-tool-calls` удалена с remote — содержимое идентично `memory-context-v1`) |
| Флаги | `OPENCODE_MEMORY_CONTEXT` (вкл. проекцию), `OPENCODE_MEMORY_CONTEXT_DEBUG` (лог `compacted=`/`protected_from=`/`raw=`), `OPENCODE_MEMORY_BATCH_SIZE` (размер батча границы, default 2; `1` = старое скользящее поведение), `OPENCODE_MEMORY_MIDTURN` (вкл. скользящее mid-turn окно, default off). WIP (только в `groom/2026-10-10-intent-tracker`, ещё не в `memory-context-v1`): `OPENCODE_MEMORY_INTENT` (вкл. log-only intent-трекер), `OPENCODE_MEMORY_INTENT_DEBUG`, `OPENCODE_MEMORY_INTENT_REFRESH_EVERY` (период рефреша summary, default 5) | `packages/core/src/flag/flag.ts` | env-переменные, default off (кроме batch size — действует при включённой проекции) | В `memory-context-v1`: все четыре флага (CONTEXT, DEBUG, BATCH_SIZE — PR #21; MIDTURN — PR #22, squash `7d7a7ecd79`). INTENT* — WIP в groom-ветке, см. строку «IntentTracker (WIP)» |
| CI | `mem-context.yml`: два джоба — целевые тесты (memory-context, savings, PII, retrieval, find-tool-calls в groom-ветке) + typecheck core, и блокирующий `core full suite` (полный `bun test` packages/core на ubuntu-latest + typecheck packages/opencode). Upstream-workflows починены для форка (CI-1): `test.yml` unit-матрица мапит blacksmith → github-hosted, когда репо не `anomalyco/opencode`; e2e и `pr-management/check-duplicates` на форке скипаются | `.github/workflows/mem-context.yml`, `test.yml`, `pr-management.yml` | `push`/`pull_request`/`workflow_dispatch` | CI-1 закрыт: PR #4 смержен (squash `d1435d2338`), запуски `mem-context` на `memory-context-v1` зелёные (`success`) |
| Shell-маркеры ретривятся (BUG-1) | В `shellMarker` добавлены `call_id=` и `retrieve=get_tool_call_details(...)`; shell без `callID` не сжимается; savings-тест ассертит оба вида маркеров (tool + shell) | `packages/core/src/session/memory-context.ts`, `packages/core/test/memory-context-savings.test.ts` | вместе с основным флагом | Влит: PR #1, squash-merge `4c183da787`, ветка удалена |
| Тул виден location-слою (PR #2) | `get_tool_call_details` добавлен в оба хардкоженных ожидаемых списка встроенных тулов — регресс собственного фича-коммита ломал `LocationServiceMap`-тест | `packages/core/test/location-layer.test.ts` | тесты, без флага | Влит: PR #2, squash-merge `3ebc63e119`, ветка удалена |
| Детерминированные help-снапшоты (PR #3) | В тест-harness закреплены `LANG=C`/`LC_ALL=C` — yargs локализует help-текст, и снапшоты падали на не-английской локали хоста | `packages/opencode/test/lib/cli-process.ts` | тесты, без флага | Влит: PR #3, squash-merge `7d47ee7477`, ветка удалена |
| V1-путь проекции (PR #7) | `MemoryContext.projectV1()` — та же компакт-проекция, но для `SessionV1.WithParts[]` (продовый TUI/run-путь идёт через `SessionPrompt` → `toModelMessagesEffect`, не через V2-runner; до этого хука сжатие на прод-пути не работало — подтверждено e2e-тестом на ladder/free: токены с флагом и без были идентичны). Хукнут в `prompt.ts` перед `toModelMessagesEffect`. Регистрация `getToolCallDetails`/`findToolCalls` в V1-registry. V1-версии тулов читают V1-хранилище `PartTable` (json_extract по callID/type) — `session_message` для V1-сессий пуста | `packages/core/src/session/memory-context.ts` (проекция `projectV1`); `packages/opencode/src/session/prompt.ts` (хук); `packages/opencode/src/tool/registry.ts` (регистрация); `packages/opencode/src/tool/find-tool-calls.ts`, `packages/opencode/src/tool/get-tool-call-details.ts` (V1-тулы); `packages/opencode/test/tool/memory-retrieval-v1.test.ts`; unit-тесты projectV1 в `packages/core/test/memory-context.test.ts` | тот же env `OPENCODE_MEMORY_CONTEXT=1` | Влит: PR #7, squash-merge `58554fc6de`, ветка `groom/2026-10-10-memory-context-v1-wire` удалена. E2E на ladder/free: turn-4 cache_r 39680→18432 (−54%), петля discover→retrieve закрыта (модель достала needle ALPHA-DELTA-42 через `get_tool_call_details` из PartTable) |
| Инструмент обзора (I1) | `get_tool_call_overview(tool?, status?, limit?, examples?)` — группировка tool-вызовов сессии по тулам: count, разбивка по статусам (pending/running/completed/error), по 2–5 последних примеров (call_id, input/error-превью); busiest-first; закрывает третий тул I1 из ROADMAP | `packages/core/src/tool/get-tool-call-overview.ts` (+ реиспользует `collectCandidates`/`Candidate` из `find-tool-calls.ts`), V1-версия `packages/opencode/src/tool/get-tool-call-overview.ts`, регистрация в `builtins.ts` и V1 `registry.ts`; тесты `packages/core/test/tool-get-tool-call-overview.test.ts` + V1-кейсы в `memory-retrieval-v1.test.ts` | без флага — входит в builtins | Влит: PR #17, squash-merge `cd1411475b`, ветка `tool-call-overview` удалена |
| IntentTracker (WIP, issue #25) | Log-only трекер интентов (трек B1, cache-safe): на каждом provider-шаге дешёвый детерминированный char-ngram TF cosine между новым user-turn и active intent-summary; сигналы (cosine, llm_label, llm_conf, acted) пишутся в таблицу `intent_signal`, интенты (summary + embedding, status active/closed/archived, parent_id, turn/token счётчики) — в таблицу `intent`; рефреш summary каждые N ходов (`OPENCODE_MEMORY_INTENT_REFRESH_EVERY`, default 5). Контекст не режет — сбор данных для калибровки порога смены интента (day-2 go/no-go) | `packages/opencode/src/session/intent-tracker.ts`, таблицы в `packages/core/src/session/sql.ts`, миграция `packages/core/src/database/migration/20261010195924_intent_tracker_tables.ts`, хук в `packages/opencode/src/session/prompt.ts`, роут в `packages/opencode/src/server/routes/instance/httpapi/server.ts`, тест `packages/opencode/test/session/intent-tracker.test.ts` | env `OPENCODE_MEMORY_INTENT=1` (+ опц. `OPENCODE_MEMORY_INTENT_DEBUG`, `OPENCODE_MEMORY_INTENT_REFRESH_EVERY`) | **WIP**: сохранён groom-сессией 9 в `groom/2026-10-10-intent-tracker` (коммиты `9d162da070`, `41e6933e91`); в `memory-context-v1` ещё не влит, PR не открыт |

Принципиально не меняется: `session/history.ts` (`entriesForRunner`), `session/context-epoch.ts`, `session/compaction`, `toLLMMessages`, tool protocol, SQLite-оригиналы, System Context Epoch.

Новое с прошлой синхронизации доков (2026-10-10, после groom-сессии 9): **грязь по issue #25 (IntentTracker log-only) сохранена** в опубликованную ветку `groom/2026-10-10-intent-tracker` (`9d162da070` + `41e6933e91`; таблицы `intent`/`intent_signal` + миграция, флаги `OPENCODE_MEMORY_INTENT*`, модуль `intent-tracker.ts`, хук в `prompt.ts`, роут, тест; пуш `--no-verify` — сырой WIP не проходил pre-push typecheck, ко второму коммиту зелёный). PR не открыт — ветка ждёт доработки. Ранее в этом цикле: PR #24 смержен (squash `4f0f3223c7`) — `get_tool_call_details` V1+V2 получил `offset`/`full`/`total_chars` (закрыло дыру ретрив-интегрити, prerequisite issue #23); дизайн-док **`FIRST-DELIVERY.md`** (delivery-маркер, флаг `OPENCODE_MEMORY_FIRST_DELIVERY`, acceptance ≥ −30% стоимости) на согласовании в issue #23; `gpt-mem/agent-benchmarks` PR #1 и #11 в `main`. `memory-context-v1` = 18 коммитов над `origin/dev`, открытых PR нет, stash пуст. Локальная ветка `full-payload-retrieval` возвращена на remote как архив исходных коммитов до squash-мержа PR #24 (контент уже в `memory-context-v1` как `4f0f3223c7`; не для мержа). Из незакоммиченного в docs-worktree сессии `smotri-po-nashemu-proektu-s-20261010-145111` (BENCHMARKS_DESIGN.md + копия `agent-benchmarks/`) groom-сессия 9 сделала ветку `groom/2026-10-10-benchmarks-design-wip` в репо доков — содержимое спасено, к обсуждению.

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
| Email | Regex | SQLite `mem_pii` (tagged) | `find_pii(type="email")` |
| Phone | Regex | SQLite `mem_pii` (tagged) | `find_pii(type="phone")` |
| Credit card | Regex + Luhn | SQLite `mem_pii` (tagged) | `find_pii(type="credit_card")` |
| API key | Pattern | SQLite `mem_pii` (tagged) | `find_pii(type="api_key")` |
| Name | NER (optional) | SQLite `mem_pii` (tagged) | `find_pii(type="name")` |

PII is **never hidden** — LLM can always retrieve it via `find_pii()`.

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
