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
