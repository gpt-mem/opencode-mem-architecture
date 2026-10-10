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

## 2026-10-10 | compression | Реализована MemoryContext.project в форке (ветка memory-context-v1, форк gpt-mem/opencode-mem): детект типа контента (bash/url/artifact/generic), маркер-замена старых успешных tool-результатов с call_id/preview/retrieve, флаг OPENCODE_MEMORY_CONTEXT (по умолчанию выкл), хук в runner/llm.ts между history и toLLMMessages. Оригиналы не трогаются. 9 unit-тестов, 1109 тестов core проходят, typecheck чист.
