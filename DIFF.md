# Чем наш форк отличается от основного OpenCode

- **CacheMarkLedger**: Управление сжатием контекста через маркировку verbatim-префиксов. 
  - Реализация: `packages/core/src/session/cache-mark-ledger.ts`
  - Флаг: `OPENCODE_CACHE_MARK` (env)
  - Статус: Активная разработка (grooming текущих реализаций).
- **Сброс при отказе запроса (self-healing)**: Механизм `CacheMark.reset` при сбоях или переполнении.
  - Реализация: `packages/core/src/session/memory-context.ts`
  - Статус: Стабильно (интеграционный acceptance-прогон пройден).
