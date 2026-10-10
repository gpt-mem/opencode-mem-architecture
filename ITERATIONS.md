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
