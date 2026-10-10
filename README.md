# OpenCode Memory Architecture

Архитектура оперативной памяти для OpenCode агентов.

## Связанные репозитории

| Репозиторий | Назначение |
|-------------|------------|
| [gpt-mem/opencode-mem](https://github.com/gpt-mem/opencode-mem) | Реализация: форк OpenCode с памятью (ветка `memory-context-v1`) |
| [gpt-mem/agent-benchmarks](https://github.com/gpt-mem/agent-benchmarks) | Инфраструктура бенчмарков: замер токенов/стоимости из SQLite-сессий, attach к PR |
| [gpt-mem/cache-intent-research](https://github.com/gpt-mem/cache-intent-research) | Исследования: prompt-cache, интент-детекция, UNIFIED-MASK, анализ реальных сессий |
| [anomalyco/opencode](https://github.com/anomalyco/opencode) | Оригинальный OpenCode (upstream) |

## Зачем

Оперативная память для агентов:
- Индексация вызовов инструментов, результатов, артефактов
- Поиск по истории сессий без LLM
- Уменьшение контекста для старых успешных вызовов инструментов (экономия токенов)
- Сохранение оригинальной истории сессий как источника истины
- Cache-aware сжатие: ledger подтверждённых границ кеша провайдера (UNIFIED-MASK)

## Документация

- [ARCHITECTURE.md](./ARCHITECTURE.md) — архитектура и компоненты
- [CONTEXT_V1.md](./CONTEXT_V1.md) — проекция контекста v1
- [FIRST-DELIVERY.md](./FIRST-DELIVERY.md) — compact-at-first-delivery (B0)
- [INTENT-CACHE-PLAN.md](./INTENT-CACHE-PLAN.md) — стратегия двух треков (кеш-free / кеш-aware)
- [ISSUES.md](./ISSUES.md) — локальный бэклог (дублирует GitHub issues)
- [ITERATIONS.md](./ITERATIONS.md) — журнал итераций агентов
- [ROADMAP.md](./ROADMAP.md) — план реализации
