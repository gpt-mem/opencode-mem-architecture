# GitHub Issue backlog — gpt-mem/opencode-mem

Target branch: `memory-context-v1` (base `dev`). Use short branches (up to 3 words, hyphens), conventional PR titles, and separate PRs. Each issue below is a standalone work item; follow `ARCHITECTURE.md` for full contracts. **GitHub issues на репо ВКЛЮЧЕНЫ** (с 2026-10-10) — основная очередь задач ведётся там; этот файл — локальный бэклог/история.

## I0 — Audit integration and baseline
Audit authoritative Session Runner, tool settlement, current SQLite event schema, output truncation/managed output files, versioned migrations and FTS5. Instrument baseline per-provider-turn breakdown: system/history/tool definitions, cache read/write, number of tool invocations and success. Collect representative coding sessions. **Acceptance:** reproducible baseline; source map and no behavior change. Dependencies: none.

## I1a — SQLite index and tool call/result ingestion
Create memory-owned SQLite schema/migrations and source-backed event index, supporting durable tool outcomes, Bash command, cwd, status, exit code, timestamps, error previews, output refs and source IDs. Incremental backfill, idempotency and redaction before indexing. **Acceptance:** retries do not duplicate events; exact linkage after restart; cross-session retrieval, no secret leaks. Dependencies: I0.
**Status 2026-10-10 (partial):** session SQLite already backs the retrieval tools; redaction-before-indexing shipped as redaction-before-delivery — `PII.redact()` in compact markers and find/overview model-visible previews (PR #18, merged squash `702a4ca09f`): API keys, Bearer tokens, secret URL params, Luhn cards → `[REDACTED:*]`; haystack/details stay raw for searchability and authorized exact retrieval. Remaining: the dedicated `mem_*` schema/backfill (I1a proper) is not started.

## I1b — Small-model tool overview/search/details
Native methods: `get_tool_call_overview`, `find_tool_calls`, `get_tool_call_details`. Summary groups by tool name and status, with counts and examples. Search by tool name, status, regex or text. Details connect each call and result and point to original full output. All responses bounded, paginated and source linked. **Acceptance:** find last failed Bash and full output without full session; tests for pending, unknown and deleted source. Dependencies: I1a.
**Status 2026-10-10:** all three tools shipped and merged into `memory-context-v1` — `find_tool_calls` (PR #6 / `31fb5e4bdf`), `get_tool_call_details` (`5b14671755`), `get_tool_call_overview` (PR #17, squash `cd1411475b`). Remaining acceptance gap: native tool-selection test on a small model (the retrieve-loop itself was e2e-verified on ladder/free in BUG-2).

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

(Фиксировано локально до включения GitHub issues; сейчас issues включены — новые баги заводить там.)

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

## BUG-2 — memory-context не работал на прод-пути V1 (FIXED IN PR #7, branch `groom/2026-10-10-memory-context-v1-wire`)

Найден e2e-тестом на бесплатных LLM (step test-free, 2026-10-10): `OPENCODE_MEMORY_CONTEXT=1` **не влиял на `opencode run`/TUI** — input-токены с флагом и без были идентичны (20256/9353/10065/206 против 20256/9355/10143/145), `OPENCODE_MEMORY_CONTEXT_DEBUG` не печатал ни строки.

**Причины (три дыры в одном):**
1. `MemoryContext.project` был захукнут только в V2-runner (`packages/core/src/session/runner/llm.ts:202`), а `SessionV2.prompt`/`resume` не имеют вызовов в проде. Реальный путь: `opencode run`/TUI → HTTP → `SessionPrompt` (`packages/opencode/src/session/prompt.ts`) → `MessageV2.toModelMessagesEffect` → `SessionProcessor` → `LLM.Service`. Хук отсутствовал.
2. `get_tool_call_details`/`find_tool_calls` регистрировались только в V2-builtins (`packages/core/src/tool/builtins.ts`); V1-реестр (`packages/opencode/src/tool/registry.ts`) их не содержит — маркеры указывали бы на несуществующие для модели тулы.
3. V1-тулы читали `session_message` (V2-таблица), которая для V1-сессий пуста (0 строк против 1578 `message` / 6797 `part`) — projector не пишет V2-таблицы из V1-событий.

**Чеклист:**
- [x] `MemoryContext.projectV1` для `SessionV1.WithParts[]` (те же правила защиты, маркеры с call_id/retrieve)
- [x] Хук в `prompt.ts` перед `toModelMessagesEffect`
- [x] V1-тулы `get_tool_call_details`/`find_tool_calls`, читающие `PartTable` (json_extract), регистрация в V1-registry
- [x] Unit-тесты projectV1 (10) + интеграционные V1-тулы (10)
- [x] E2E на ladder/free: флаг уменьшает cache_r (turn-4 39680→18432), retrieve-петля достаёт needle из PartTable (ALPHA-DELTA-42)
- [x] Замержить PR #7 после сборки чеков (merged 2026-10-10, squash `58554fc6de`)

**Acceptance:** `opencode run` с `OPENCODE_MEMORY_CONTEXT=1` компактит старые tool-выводы (подтверждено падением cache_r и debug-логом) и модель получает рабочие retrieve-инструкции; PR #7 смержен в `memory-context-v1`.

## NEW P0: Context Projection v1 — reduce old tool outputs in Build

See `CONTEXT_V1.md`. Implement a flag-gated in-memory substitution of older completed successful tool-result text at provider-turn assembly, preserving call/result envelopes, IDs, user messages, system epochs and native continuation metadata. Require retrievable originals, explicit fallback and A/B cost/quality tests. Do not replace all session history.

## BUG-3 — Один user-prompt ⇒ ноль компакции (FIXED 2026-10-10, PR #19, ветка `single-turn-compression`)

Найдено реальным замером (issue #9): правило «не трогаем всё начиная с 3-го с конца user-turn» при **одном** user-prompt давало `protectedFrom = userIndices[0] = 0` → ранний выход, 0 маркеров, `OPENCODE_MEMORY_CONTEXT_DEBUG` молчал на 9-шаговой сессии. Затронут каждый `opencode run` и первый ход TUI.

**Фикс:** второе окно защиты — последние `DEFAULT_KEEP_RECENT_ASSISTANT_TURNS=2` assistant-сообщения (рабочий набор модели), граница = более ранняя из двух окон (`protectedStartIndex`, общая для V1 и V2), новый опцион `keepRecentAssistantTurns`.

- [x] Unit-тесты single-turn (V1 + V2), memory-context 29/29
- [x] Реальная сессия: `compacted=1..5`, `protected_from=3..7`, ретрив работал, ответ верный
- [x] PR #19 смержен (squash `2a5a00bbf2`), CI `memory-context tests` + `core full suite` зелёные

**Acceptance:** сессия с одним user-prompt и ≥3 assistant-сообщениями сжимается (debug-лог непустой), рабочий набор и user-окно дословны. — Закрыт.

## ISSUE-20 (GitHub #20, CLOSED 2026-10-11 — PR #21 boundary batches + PR #22 MIDTURN gate, acceptance: cost parity) — Cache-стабильная проекция: mid-turn компакция удорожает сессию

Найдено тем же замером: MEM on дал −44.7% provider-visible токенов, но **+69.7% фактической стоимости** (0.011368 → 0.019295 USD): граница компакции сдвигается на одно сообщение каждый шаг → prompt-prefix-кеш инвалидируется от newly-compacted сообщения (`cache_read` залипает на ~8.8k = system+маркеры), а ещё полные хвостовые tool-выводы пересылаются некешированными (`input` +83.9%, `cache_hit_rate` 0.82 → 0.42). Точный прайсинг-модель, выведенная из замеров (2026-10-10, точное соответствие): `cost = 1.412e-7 × uncached + 3.06e-9 × cache_read` → **cache read ≈ 2.2% от uncached (~45× дешевле)** — любая перезапись уже отправленной истории на таком провайдере проигрывает.

**Чеклист (см. GitHub #20):**
- [x] Стабильная граница внутри user-turn (проекция один раз на user-turn) либо компакция только на user-turn границах — **смержено в PR #22** (squash `7d7a7ecd79`): mid-turn окно (рабочий набор assistant-сообщений) выключено по умолчанию, граница стоит на user-turn-границе; включается флагом `OPENCODE_MEMORY_MIDTURN=1`
- [x] Пакетная/монотонная компакция — точка изменения остаётся поздней, инвалидируемый хвост мал — **смержено в PR #21** (squash `0982ec8493`): граница двигается батчами `floor(raw/batch)*batch` (default 2, env `OPENCODE_MEMORY_BATCH_SIZE`), проецируемый префикс byte-identical между прыжками, монотонность покрыта тестами; `1` воспроизводит старое скользящее поведение
- [ ] Cache-aware admission: не компактить, если инвалидируемый хвост больше экономии — на cache-прайсинге вырождается в «не трогать уже отправленную историю» (уже дефолт после PR #22); остаётся только вариант «знать, кеширует ли провайдер» (capability/конфиг) и включать sliding/mid-turn для cacheless
- [x] Повторный A/B на том же харнессе (**2026-10-10**, ворктри на `eb5ceba251`, харнесс `/tmp/bench20`, сессии приаттачены к PR #22): одноповоротный сценарий — MEM on (новый default) **-cost parity** (−0.5%, $0.011548 → $0.011489, видимые токены −0.1%, hit 0.82, ответ верный); sliding до фикса +67.1%, batch=2 только +36.1%; 3-поворотный сценарий — MEM on **−1.2% cost, −19.1% provider-visible** (пошагово после компакции −86% видимых токенов), uncached +3.0%, все ответы верны; дебаг: повороты 1–2 байт-в-байт как off, один прыжок границы на повороте 3 (`protected_from=10 raw=10`), дальше append-only. Осталось: провайдер без prompt-cache (opt-in `OPENCODE_MEMORY_MIDTURN=1` покрывает, e2e-замер не делался)

**Acceptance (2026-10-10):** «не дороже» — ✅ выполнено (cost parity одноповоротный, −1.2% трёхповоротный, задачи верны во всех руках); «текущая экономия токенов» — ✅ в мультиповоротной форме (−19.1% суммарно), ❌ в одноповоротной (−0.1% — осознанно: старая −44.7% и была причиной +70% стоимости; доступна opt-in `OPENCODE_MEMORY_MIDTURN=1`). Единственный путь к безусловной долларовой экономии на cache-прайсинге — компакция при первой доставке (маркер вместо полного результата сразу; оригинал уже в SQLite) — заведено отдельно: **GitHub #23**.

## ISSUE-23 (GitHub #23, CLOSED 2026-10-11 — PR #27 delivery-режим + PR #36 ledger-политика; A/B GO, −48.5%/−92.3% cost, needle-recall 100%) — Compact at first delivery (B0, дизайн + prerequisite)

Единственный путь к долларовой экономии на cache-прайсинге: не отправлять bulk больших tool-выводов в принципе — delivery-маркер при первой доставке, оригинал в SQLite. Дизайн: **`FIRST-DELIVERY.md`** (та же маркерная семантика; элигабельность bash/webfetch/websearch/read ≥2000 chars, env `OPENCODE_MEMORY_FIRST_DELIVERY` default off + `_MIN_CHARS`/`_TOOLS`; cache-safe append-only без инвалидаций; loop-breakers: превью в маркере, ретрив всегда оригинал, `full`/`offset` постраничность; acceptance ≥ −30% реальной стоимости, needle 100%). Дизайн вынесен на согласование — комментарий в GitHub #23; gate: не имплементировать delivery-режим до согласования.

**Чеклист:**
- [x] Design-док `FIRST-DELIVERY.md` + комментарий в issue #23
- [x] Полный ретрив: `get_tool_call_details` V1+V2 `offset`/`full`/`total_chars` — PR #24, squash `4f0f3223c7` (закрыл и дыру #11: originals >8k раньше обрывались на 8k без пути к остатку)
- [x] Delivery-режим `project`/`projectV1` за `OPENCODE_MEMORY_FIRST_DELIVERY` (дефолт off) — PR #27, squash `3da43da910`
- [x] Юнит-тесты delivery-маркеров + append-only префикс + flag-off байт-в-байт — PR #27 (16 тестов)
- [x] Quality/loop-тест на LLM (маркер → ретрив → задача решается, ре-чит не зациклен) — A/B 2026-10-10: needle 100%, 2 retrieve с offset-пейджингом, лупов нет
- [x] Benchmark A/B (одноповоротный сценарий #20 + саммари-задача), attach-pr, go/no-go — **GO**: single-turn cost −48.5% (uncached −51.9%), summary cost −92.3% (uncached −96.1%), 0 инвалидаций кеша; 4 сессии на PR #27; вердикт-комментарий в issue #23
- [x] Обсуждение дефолта: решено в PR #36 — `firstDeliveryPolicy` включает first-delivery при `OPENCODE_MEMORY_CACHE_MARK=1` (продакшен-конфиг = `CONTEXT=1 CACHE_MARK=1`); одиночный `FIRST_DELIVERY` остаётся для ledger-less сетапов
