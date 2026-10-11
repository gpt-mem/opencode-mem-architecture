# Handoff: где живут данные OpenCode для анализа (2026-10-11)

## 5 баз данных в `~/.local/share/opencode/`

| База | Размер | Канал / флаги | Кто спавнит | Для чего |
|------|--------|---------------|-------------|----------|
| `opencode.db` | 107 MB | default (`latest`) | `~/.opencode/bin/opencode` (wrapper) | Основной сток сессий (81) |
| `opencode-local.db` | 46 MB | `OPENCODE_DB=...` / `--channel local` | бенчмарки, тесты | Локальные/тестовые запуски |
| `opencode-forever.db` | 0.25 MB | `forever` | `opencode-forever` (kobzevvv форк) | Не используется |
| `opencode-.db` | 49 MB | `OPENCODE_MEMORY_CONTEXT=1` + пустой `channel` | `mem on` (пустой канал) | MEM-форк, пустой канал |
| **`opencode-memory-context-v1.db`** | **107 MB** | **`memory-context-v1`** | **MEM-форк gpt-mem/opencode-mem ветка `memory-context-v1`** | **✅ АКТИВНЫЙ — 27 сессий, это наша аналитика** |

**Вывод**: только `opencode-memory-context-v1.db` актуальна для MEM-аналитики. Остальные — сток/тесты/forever.

---

## Запуск OpenCode — механика каналов

```bash
# Из бинара opencode.bin:
function F5() {
  if (OPENCODE_DB) return OPENCODE_DB;                     # 1) env override
  if (latest|beta|prod || DISABLE_CHANNEL_DB) return "opencode.db";  # 2) дефолт
  return `opencode-${channel}.db`;                          # 3) по каналу сборки
}
```

- **Канал = константа сборки** (`latest/beta/dev/forever/local/memory-context-v1/...`)
- Имя БД = `opencode-<канал>.db` (пустой канал → `opencode-.db`)
- MEM-форк собирается как отдельный канал (`memory-context-v1`), имеет свой бинарник

---

## Кто держит БД (lsof)

| База | Процессы |
|------|----------|
| `opencode.db` | 4 активных сессии + next-server (Session Manager) |
| `opencode-local.db` | bench runner (node 92465) |
| `opencode-forever.db` | bench runner (node 92465) |
| `opencode-.db` | 4 MEM-форк сессии (OPENCODE_MEMORY_CONTEXT=1) |
| `opencode-memory-context-v1.db` | 2 MEM-форк сессии + Session Manager (node 92465) |

---

## Логи и артефакты для анализа

### Логи (в `~/.opencode/scripts/`):
- `chain-logs/chain-*.log` — общий лог цепочки
- `selftest-logs/selftest-*.log` — dogfooding логи
- `releaser-logs/releaser-*.log` — сборка/релиз
- `launchd-stdout.log` / `launchd-stderr.log` — launchd daemon

### Артефакты в GitHub docs-репо (`opencode-mem-architecture`):
- `STUDY.md` — ранжированный список находок (обновляет researcher)
- `BUGS-REPORT.md` — систематизация багов (обновляет bug-reporter)
- `ITERATIONS.md` — хронология шагов (дописывает architect)
- `ROADMAP.md` — приоритеты (подправляет architect)
- `prompt.txt` — промпт builder'а (подправляет architect)
- `chain/` — скрипты цепочки (run-mem-chain.sh, 4 промпта, mem-metrics.sql, plist)

### Тяжёлые артефакты → Google Drive
- **Папка**: `OpenCode MEM Artifacts` (шареная с SA `vovako-21js@trained-assist-gdrive-sa.iam.gserviceaccount.com`)
- **Ключ SA**: `GOOGLE_APPLICATION_CREDENTIALS` (создаётся через `gcloud iam service-accounts keys create`)
- **Что заливаем**: полные selftest-логи (>1MB), большие debug-дампы, raw SQL exports
- **Не заливаем**: chain-last.md, STUDY.md, BUGS-REPORT.md — они в GitHub репо

---

## SQL-метрики (mem-metrics.sql)

```bash
sqlite3 ~/.local/share/opencode/opencode-memory-context-v1.db < ~/.opencode/scripts/mem-metrics.sql
```

Показывает:
1. Расходы по типам сессий (chain/scheduled/ad-hoc)
2. Топ-10 по кеш-чтению/стоимости
3. Динамика 7 дней
4. Использование memory-тулов (overview/find/detail/artifact)
5. Доля memory-тулов среди всех tool-вызовов
6. Cache mark активность
7. Intent-сигналы (cosine, acted)
8. Context projection экономия

---

## Схема регулярных сессий (mem-chain, каждые 2ч)

```
launchd local.opencode.mem-chain (StartInterval=7200)
       │
       ▼
run-mem-chain.sh (lock, state.jsonl, chain-logs/)
       │
       ├── release  → run-releaser.sh          → release-current.md
       ├── selftest → run-selftest.sh          → selftest-<STAMP>.log
       ├── bug-reporter    → prompt-bug-reporter.txt → BUGS-REPORT.md (git push)
       ├── researcher      → prompt-researcher.txt   → STUDY.md (git push)
       └── architect       → prompt-architect.txt    → ROADMAP.md + prompt.txt + ITERATIONS.md + chain-last.md (git push)
```

### Зависимости между шагами
| Шаг | Читает | Пишет |
|-----|--------|-------|
| release | — | `release-current.md`, GitHub Release, новый бинарь |
| selftest | `release-current.md` | `selftest-<STAMP>.log` |
| bug-reporter | `release-current.md`, `selftest-logs/`, `ISSUES.md`, `ITERATIONS.md` | `BUGS-REPORT.md` (push) |
| researcher | `STUDY.md` (вход), `BUGS-REPORT.md`, `mem-metrics.sql`, CSM `sessions.db` | `STUDY.md` (push) |
| architect | `release-current.md`, `BUGS-REPORT.md`, `STUDY.md`, `ROADMAP.md`, `prompt.txt` | `ROADMAP.md`, `prompt.txt`, `ITERATIONS.md`, `chain-last.md` (push) |

---

## Launchd сервисы (активные)

| plist | Schedule | Что делает |
|-------|----------|------------|
| `local.opencode.mem-chain` | 2h | Полная цепочка (релиз→сетест→баг→учёный→архитектор) |
| `local.opencode.mem-groomer` | 1h | Архивация/причесывание репо (отдельно) |
| `local.opencode.mem-architecture` | KeepAlive (2 min) | Основной builder-цикл (scheduled-iteration) |

**Отключено**: `local.opencode.mem-selftest` — теперь внутри mem-chain.

---

## Учётная запись для тяжёлых артефактов

```
Service Account: vovako-21js@trained-assist-gdrive-sa.iam.gserviceaccount.com
Project: trained-assist-gdrive-sa
Scopes: https://www.googleapis.com/auth/drive
```

Настройка:
```bash
# Создать ключ (однократно)
gcloud iam service-accounts keys create ~/gdrive-sa-key.json \
  --iam-account vovako-21js@trained-assist-gdrive-sa.iam.gserviceaccount.com \
  --project trained-assist-gdrive-sa

export GOOGLE_APPLICATION_CREDENTIALS=~/gdrive-sa-key.json
```

В `run-mem-chain.sh` для тяжёлых логов добавить upload в папку `OpenCode MEM Artifacts` (Drive file ID предварительно создан и расшарен SA).