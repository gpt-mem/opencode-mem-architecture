# STUDY — ранжированный список находок (стартовая точка учёного)

> Обновляется сессией researcher (chain, каждые 2ч). Формат пункта:
> `[rank] <польза> STATUS — <обоснование>`. STATUS: `proven` | `doubtful` | `needs_proof`.

Первый цикл (seed из A/B + selftest сессий 27-28, до входа researcher):
`STAMP: seed-2026-10-11`

## Ranked by usefulness

1. **Memory tools overview/find/detail (I1)** — `high` — STATUS: `proven` — влиты (PR #68), 21 проходной тест; overview особенно эффективен в A/B (лучший recall/cost).
2. **Context projection v1 (`OPENCODE_MEMORY_CONTEXT`)** — `medium` — STATUS: `doubtful` — включается флагом; в acceptance −0.3% регрессия; экономия токенов есть, но нужен реальный production-путь (по умолчанию off).
3. **Cache-stable boundary + cache-mark (`CACHE_MARK=1`)** — `high` — STATUS: `proven` — cache_r 0→21376 в dogfooding; стабильная граница кеша сокращает cache-write.
4. **Intent-switch detector (трек B1, `intent_signal`)** — `medium` — STATUS: `doubtful` — precision-first детектор пишет сигналы (cosine/llm_label/acted); нужен накопленный production для выводов о точности.
5. **First-delivery / ledger-политика (ISSUE-23)** — `high` — STATUS: `proven` — A/B GO, −48.5%/−92.3% cost, needle-recall 100%.
6. **PII-tagging + redaction маркеров** — `medium` — STATUS: `proven` — `0 markers with pii=` в selftest (утечек нет); PII-дрели работают.
7. **Compaction на single user-prompt (BUG-3)** — `medium` — STATUS: `proven` — PR #19 закрыл «ноль компакции» на одноповоротном сценарии.
8. **Эвристика `filename` в detectKind** — `low` — STATUS: `doubtful` — в A/B деградирует; кандидат на замену content-based/LLM-judge подходом.
9. **LLM-judge для evaluate** — `low` — STATUS: `needs_proof` — не реализован; вместо него сессия researcher комментирует proven/doubtful по бенчмаркам.
10. **Memory-first context replacement (I5)** — `low` — STATUS: `needs_proof` — отдельный эксперимент; замена полного диалога на memory-тулы как источник контекста.

## Metrics digest
_(заполняется researcher)_

## User feedback top
_(заполняется researcher из CSM sessions.db)_

## Judge comments
_(заполняется researcher)_