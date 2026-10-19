# Промпт: установка форка, две версии в Session Manager, хук продвижения

> Вставь этот файл как первое сообщение новой сессии. Пути и SHA уже сверены с окружением на 2026-10-19.

## Роль и дисциплина

Ты инженер-исполнитель в форке `gpt-mem/opencode-mem`. Отвечаешь по-русски.
Для каждого изменения: issue → workspace → commit+push → PR → зелёный CI → merge → подтверждённый merge SHA. Локальная правка без мержа — не результат. Экспресс-режим: ключевые тесты прогоняй сам локально, CI — последним шагом.

## Текущее состояние

**Форк `gpt-mem/opencode-mem`, две линии:**

| Линия | Ветка | Head SHA | Раскладка |
|---|---|---|---|
| v1 (старая, рабочая) | `dev` | `5639dfe0b5` | `packages/opencode` |
| v2 (целевая) | `v2-base` | `950f0d869b` | `packages/core` + `packages/cli` (нет `packages/opencode`) |

Смержено на v2: #148 `58eaaa8b8b` (контекст 2 КиБ + маркер), #149 `fdea7937bf` (cache-mark ledger + две ветки Ladder + маска), #154 `02f0d458a2` (advisory doom-loop), #153 `88970e3ae9` (EPIPE/service/pwsh), #151 `950f0d869b` (CI/CD: push-триггеры `dev`+`v2-base`, 14 мёртвых workflow'ов удалено).
Смержено на v1: #144 `3b8e1471b4` (мост пермишенов V2→V1 + `BuiltInTools.node`), #152 `ea179aebf4` (fallback на `github.token`, `publish.yml` → `workflow_dispatch`), #146 `027097c092` (промпт шелла), #155 `9f2e1da780` (`generate` не коммитит workflow-файл).
Трекер: issue #147. Открытых PR — нет.

**Локально:**
- Активный бинарь `~/.opencode/bin/opencode`; бэкапы `~/.opencode/bin/opencode.<sha>-<YYYYMMDDHHMM>.bak`; сток — `opencode.stock-backup`.
- `~/.opencode/forever-install.json` — устарел (про `kobzevvv/opencode-forever` v1.18.34). Обновить.
- Цепочка: `~/opencode-mem-architecture/chain/{run-selftest.sh,run-releaser.sh,run-mem-chain.sh}` + зеркало `~/.opencode/scripts/` + launchd `local.opencode.mem-chain` (каждые 2 ч).
- **Устаревание:** в `run-releaser.sh` и `run-selftest.sh` стоит `BRANCH=memory-context-v1` (v1-раскладка, `packages/opencode`). Целевая линия — `v2-base` (v2-раскладка: `packages/core`+`packages/cli`). Перевести на неё.
- Порядок в цепочке сейчас «релиз → селфтест»; гейт `MEM_REQUIRE_SELFTEST=1`/`MEM_SELFTEST_OK=1` уже есть (exit 77 удерживает релиз).

## Задача 1 — инструкция по установке форка

**Проблема:** `README.md` форка — дословно upstream (`npm i -g opencode-ai@latest`). Из-за этого непонятно, как поставить форк и как откатиться на предыдущую версию.

**Что сделать:** добавить в `README.md` форка раздел «OpenCode MEM (форк)», который заменяет/дополняет upstream-инструкцию для этого репозитория:
1. Из релиза: теги вида `mem-v<YYYYMMDD-HHMM>-<SHA>`, ассет с бинарём → распаковать, положить в `~/.opencode/bin/opencode` (сток сохранить рядом).
2. Из исходников v2-линии: `v2-base` → `cd packages/cli && bun run script/build.ts --single --skip-install --skip-embed-web-ui` (версия вшивается из исходников через `packages/cli/src/version.ts`).
3. Конкретная/предыдущая версия: по тегу релиза или по SHA ветки; откат — через `.bak`-бэкап рядом с бинарём.
4. Проверка, что форк стоит: `opencode --version` содержит `fork at <SHA>`; флаги `OPENCODE_MEMORY_CONTEXT=1` и др. работают.
5. Явно: `npm i -g opencode-ai` — это **upstream**, не форк.

**Приёмка:** раздел читается и выполним с нуля; ссылки на теги/ветки реальны; upstream-установка помечена как альтернатива, а не как основная.

## Задача 2 — Session Manager: последняя + предпоследняя версия

**Место:** `~/code/claude-session-manager` (Next.js, БД `data/sessions.db`, ключ настройки `opencode_builds`). Механизм уже есть: `src/lib/opencode-builds.ts` (схема `OpencodeBuild`: `id`, `name`, `binary` (абсолютный), `kind: upstream|stable|snapshot`, `builtAt`, `autoFlag`), `resolveOpencodeBuild()`, API `GET /api/opencode/builds`, выбор сборки в форме новой сессии (`buildId`), UI `src/components/settings/OpencodeBuildSettings.tsx`.

**Что сделать:**
1. Раскладка на диске: `~/.opencode/builds/<SHA>/opencode` — реальные бинари; симлинки `~/.opencode/builds/current` → последний установленный, `~/.opencode/builds/previous` → предпоследний. Сдвиг при установке нового: `previous ← current`, `current ← <new>`, атомарно (временные симлинки + `mv -T`).
2. Скрипт управления (положить в `~/opencode-mem-architecture/chain/` + зеркало `~/.opencode/scripts/`): подкоманды `install <путь-к-бинарю>`, `shift`, `list`, `rollback`. Установка копирует бинарь в `builds/<SHA>`, сдвигает симлинки, обновляет `~/.opencode/forever-install.json`.
3. Зарегистрировать две записи в `opencode_builds` (через API/UI настроек):
   - `mem-latest` → `~/.opencode/builds/current`, `kind: stable`, `autoFlag: true`, имя «OpenCode MEM — последняя»;
   - `mem-previous` → `~/.opencode/builds/previous`, `kind: snapshot`, `autoFlag: true`, имя «OpenCode MEM — предпоследняя».
   Плюс запись `upstream` для стока (`kind: upstream`, `autoFlag: false`).
4. В UI настроек секции сборок — добавить кнопку «Установить сборку» и пояснение про сдвиг симлинков.

**Приёмка:** `resolveOpencodeBuild("mem-latest")` и `("mem-previous")` возвращают существующие файлы; запуск сессии с `previous` показывает прошлый SHA в `opencode --version`; установка новой сборки сдвигает симлинки без ручной правки настроек.

## Задача 3 — хук продвижения новой версии для агента

**Требование:** при появлении новой версии форка с новым SHA агент получает хук → гоняет свой CI/CD (e2e) → если зелёно, обновляет OpenCode, включая подмену бинаря в двух видах образов.

**Место:** агент = `~/code/ai-agent-runner` (движок) + `~/code/trained-assist-tg-bot` (Telegram-интерфейс). Движок запускает бинарь через `src/adapters/engine/opencode-adapter.ts` (`OPENCODE_BIN`, по умолчанию `/usr/local/bin/opencode`). «Два вида образов» — VM-воркеры: **france** (`eu-vm2-sandbox`) и **russia** — инвентари `deploy/vm-worker/inventory/{france,russia}.json`, окружение `deploy/vm-worker/worker.env.*.example` (`OPENCODE_BIN=/usr/local/bin/opencode`), установка `scripts/install-vm-worker.sh`, конфиг `deploy/vm-worker/engine-config/opencode.json`, сервис `deploy/vm-worker/ai-agent-vm-worker.service`.

**Что сделать:**
1. Источник события: последний тег `mem-v*` или tip `v2-base` в `gpt-mem/opencode-mem` → кандидат `<SHA>`. Хук: эндпоинт или крон в раннере (уже есть wrangler-воркеры) + команда в tg-bot. Событие «новый SHA появился» (SHA отличается от текущего активного).
2. Проверка кандидата перед промоушном: скачать/собрать бинарь, прогнать e2e раннера — `bun run test` (vitest, `test/`), `scripts/m1-step7-conversation-e2e.mjs`, `scripts/sandbox3-vm2-live-canary.mjs` — через `OPENCODE_BIN=<candidate>`. Красный → промоушен не делать, отчёт.
3. Промоушен при зелёном: установка бинаря в `~/.opencode/builds/<SHA>` + сдвиг симлинков (как в задаче 2) + регистрация в `opencode_builds` + подмена бинаря на **обоих** VM-воркерах (france и russia) + рестарт `ai-agent-vm-worker.service` + обновление `~/.opencode/forever-install.json`.
4. Перевести цепочку `run-selftest.sh`/`run-releaser.sh` с `memory-context-v1` на `v2-base` и `packages/opencode` на `packages/cli`; инвертировать порядок на «кандидат → проверка → промоушен» (проверка до установки активного бинаря, а не после).

**Приёмка:** при новом таге агент сам детектит кандидат, прогоняет e2e, при зелёном поднимает `current` и переставляет бинарь на france+russia; при красном — остаётся на текущей версии и пишет отчёт. Хук проверен end-to-end на реальном релизе.

## Финал

Обнови issue #147 итоговым комментарием: что сделано по каждой задаче, merge SHA, остаток. Проверь `git status`/untracked в воркtree перед сдачей.
