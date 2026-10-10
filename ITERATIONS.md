# ITERATIONS

Журнал итераций. Формат: дата | тип шага | что сделано.

Типы шагов:
- plan — обновить архитектурный план
- compression — добавить сжатие / обработку типа контента
- mcp — добавить метод в наш API (не совсем MCP)
- test-free — тест на бесплатных LLM
- test-paid — тест на mimo flash 2.6
- baseline — сравнение со стандартным opencode
- ci — CI с полезным тестом
- review — ревью архитектуры
- bug — оффить баг / проблему

Правило: не делать один шаг одного типа больше двух раз подряд.

---

## 2026-10-10 | plan | Раздел 12 "Next iteration plan" в ARCHITECTURE.md: таблица сжатия по типам контента (bash, url, artifact, decision), шаги реализации, acceptance criteria.

## 2026-10-10 | plan | PII убрана из сжатия: отдельный раздел "PII handling (no compression)" — разметка и индексация (email/phone/credit card/api key/name) через find_pii(type).

## 2026-10-10 | compression | MemoryContext.project в форке (ветка memory-context-v1, gpt-mem/opencode-mem): детект типа контента (bash/url/artifact/generic), маркер-замена старых успешных tool-результатов с call_id/preview/retrieve-инструкцией, флаг OPENCODE_MEMORY_CONTEXT (default off) + DEBUG, хук в runner/llm.ts между history и toLLMMessages. Не сжимаются: error-тулы, provider-executed, memory-тулы, последние 2 user-turn, shell < 2000 символов. Оригиналы не трогаются. 9 unit-тестов, core suite чистый, typecheck чист.

## 2026-10-10 | mcp | Нативный тул `get_tool_call_details` (packages/core/src/tool/get-tool-call-details.ts, ветка memory-context-v1): извлекает полный оригинальный вывод tool-вызова из SQLite session history по call_id (assistant tool parts + shell messages), max_chars-обрезка, decode-bad-строки пропускаются, зарегистрирован в builtins.ts. Закрывает обещание маркеров сжатия — ничего не скрыто, всё ретривится. 5 юнит-тестов, typecheck чист. Запушено: 5b14671755.

## 2026-10-10 | ci | Ветка memory-context-v1: workflow `.github/workflows/mem-context.yml` (push/PR/workflow_dispatch, ubuntu-latest) — прогоняет memory-context.test, новый memory-context-savings.test, tool-get-call-details.test + typecheck core, пишет savings в job summary. Savings-тест: фикстура tool-heavy сессии (62041 → 24081 байт, 61.2% saved, tool payload 63.9%), маркеры компакции обязаны содержать call_id + retrieve=get_tool_call_details и быть уникальными, error/недавний турн/small результаты не трогаются, flag off = байт-в-байт идентично. 18 тестов зелёные, typecheck чист, oxlint по новым файлам 0 warnings. Запушено: bb04b082fd.

## 2026-10-10 | compression | PII-тегирование сжатия: новый `packages/core/src/session/pii.ts` (детект email, phone (без путаницы с картами), credit_card с Luhn-проверкой, api_key по паттернам sk-/ghp_/AKIA/ assignment) + `PII.tag()`; маркеры сжатия в memory-context теперь содержат строку `pii=email,credit_card,...` для tool-результатов и shell-вывода (тег только в компакт-маркере, оригинал в SQLite не трогается, путь ретрива get_tool_call_details прежний). 9 новых тестов PII + 3 теста маркеров, 25 тестов сьюты зелёные, typecheck чист, oxlint 0 warnings, pii.test.ts добавлен в CI workflow. Запушено: e5570ec91b.

## 2026-10-10 | bug | BUG-1 в ISSUES.md: маркеры сжатого shell-вывода не ретривятся — shellMarker не содержит call_id/retrieve-инструкции (в отличие от toolMarker), хотя SessionMessage.Shell.callID есть и get_tool_call_details умеет его резолвить; подсказка `message <id>` тулом не принимается. Плюс дыра в CI-тесте: savings-тест проверяет только маркеры `[mem:compacted tool result]`, shell-маркеры не ассертятся. GitHub issues на gpt-mem/opencode-mem отключены — баг зафиксирован в беклоге ISSUES.md. Fix: добавить call_id + retrieve в shellMarker и расширить тест.

## 2026-10-10 | bug | Fix BUG-1 (PR #1, ветка fix-shell-marker-retrieval → memory-context-v1): shellMarker теперь содержит `call_id=<callID> status=success` + `retrieve=get_tool_call_details(call_id="...")`; shell без callID не сжимается (нет пути ретрива — не трогаем). Savings-тест расширен: фикстура содержит 2 shell-вывода, оба вида маркеров (tool + shell) ассертятся на уникальный call_id + retrieve-строку; +2 новых теста (маркер резолвится к оригиналу, пустой callID не сжимается). 32 теста зелёные, typecheck чист. Savings: 79728→26037 байт (67.3%). PR: https://github.com/gpt-mem/opencode-mem/pull/1

## 2026-10-10 | review | Groom-сессия форка: working tree чист, stash пуст, незапушенных коммитов нет; локальная ветка `no-context-trim` (без уникальных коммитов, = `origin/dev`) запушена в origin. Ветки `fix-shell-count`, `fix-shell-tab`, `fix-shell-test`, `prompt-stash-sync` на origin — штатные ветки upstream anomalyco/opencode (идентичные SHA есть на upstream), чистить/мерджить нечего; полезного в них для memory-context нет. Доки: в ARCHITECTURE.md добавлен раздел «Чем наш форк отличается от основного OpenCode» (компонент → файл → флаг → статус, новое с прошлой синхронизации), восстановлен удалённый `CONTEXT_V1.md` (на него ссылаются ARCHITECTURE §7/§11, ISSUES, ROADMAP). Статус PR #1: MERGEABLE → `memory-context-v1`, `memory-context tests` SUCCESS, остальные чеки в очереди.

## 2026-10-10 | bug | Доделка открытого PR #1 (`fix-shell-marker-retrieval` → `memory-context-v1`): локальный прогон перед мержем — core 1115 pass / 17 fail (те же 18 фейлов падают и на базе `memory-context-v1` — окружениеные: cross-spawn ×15, Npm.add, LocationServiceMap), opencode 3618 pass / 3 fail (тайминги HTTP compression/PTY ticket/subprocess, к PR отношения не имеют), typecheck обоих пакетов чист, CI `memory-context tests` PASS. Upstream-чеки `test` и `pr-management` стояли в очереди 57+ мин: они используют раннеры `blacksmith-4vcpu-*`, которых на форке нет, и никогда не стартуют; ветка без branch protection → PR #1 MERGED (merge-commit 4c183da7), зависшие раны отменены.

## 2026-10-10 | bug | PR #2 (`fix-location-tool-list` → `memory-context-v1`, merge-commit 3ebc63e1): регресс от собственного фича-коммита — `get_tool_call_details`, добавленный в `builtins.ts`, сломал точное сравнение списка встроенных тулов в `packages/core/test/location-layer.test.ts` (`LocationServiceMap > isolates location state...` падал в полном core-сьюте, CI не видел: workflow `mem-context` гоняет только memory-context-файлы). Фикс: `get_tool_call_details` добавлен в оба ожидаемых списка. Проверка: 36 pass / 0 fail по 5 затронутым файлам, core 1116/16 (остались только окружениеные), монорепо-typecheck 30/30 (pre-push hook), CI `memory-context tests` PASS. PR: https://github.com/gpt-mem/opencode-mem/pull/2

## 2026-10-10 | ci | Чистый локальный прогон: 2 фейла починены (PR #3, ветка fix/test-suite-clean): (1) location-layer.test.ts — хардкоженные списки тулов дополнены get_tool_call_details; (2) help-snapshots — yargs локализует help на pt_BR локали хоста, в тест-harness закреплены LANG=C/LC_ALL=C. Typecheck core+opencode чистый. PR #1 (shell-маркеры) смержен. Остался открыт PR #3.

## 2026-10-10 | review | Groom-сессия: форк чист (working tree чист, stash пуст, все ветки запушены). PR #3 (`fix/test-suite-clean`) смержен (squash `7d47ee7477`) — все запускаемые чеки зелёные, queued-чеки мёртвые (CI-1); ветки PR #1/#2/#3 удалены и локально, и на origin. Открытых PR нет; вся работа — в `memory-context-v1` (9 коммитов над `origin/dev`). ARCHITECTURE.md: раздел «Чем наш форк отличается» сверён с git log (строки BUG-1/PR #1 → влит, новые строки PR #2 и PR #3, CI-строка с оговоркой про blacksmith). В ISSUES.md закоммичен CI-1.

## 2026-10-10 | ci | CI-1 (пункт беклога ISSUES.md), PR #4 (`ci-fork-runners` → `memory-context-v1`, https://github.com/gpt-mem/opencode-mem/pull/4): (1) `test.yml` — unit-матрица мапит blacksmith-раннеры на github-hosted, когда репо не `anomalyco/opencode` (fork: ubuntu-latest/windows-latest, чеки не висят в queued); e2e-джоб и `pr-management/check-duplicates` на форке скипаются (`if: github.repository == 'anomalyco/opencode'`; e2e — Playwright-шум, duplicate-check требует upstream-only `OPENCODE_API_KEY`). (2) `mem-context.yml` — новый блокирующий джоб `core full suite`: полный `bun test` в packages/core на ubuntu-latest (macOS-окружениеные фейлы там не воспроизводятся) + typecheck packages/opencode — регрессии в любых core-тестах теперь падают в CI. Валидация: YAML парсится, core локально 1116/16 (те же окружениеные), opencode 3618/3 (окружениеные), typecheck чист, pre-push turbo typecheck 30/30. Стартанувший queued-run `pr-management` отменён вручную; acceptance CI-1 проверить после сборки чеков PR #4 и замержить.
