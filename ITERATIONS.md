2026-10-23 | fix | Updated mem-metrics-v2.sql for v2-tables (session_v2) | - | Metrics now report real session data for v2.
2026-10-23 | docs | Cleaned release-current.md, removed dead v1 flags | - | Documentation is now accurate to v2.

2026-10-23 | port | Портировал CacheMarkLedger и MemoryContext проекцию в v2 (WIP) | - | Подготовка к интеграции ledger/хука в runner/llm.ts.
2026-10-23 | fix | Pass markIndex to SessionMemoryContext.project in runner/llm.ts | - | Fixed bug where cache ledger floor was ignored.
PR creation failed due to token permissions.
