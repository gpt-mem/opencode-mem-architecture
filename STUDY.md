# STUDY research-20261021-2022 — ранжированный список находок (цикл 19)

> Обновляется сессией researcher. Формат пункта:
> `[rank] <польза> STATUS — <обоснование>`. STATUS: `proven` | `doubtful` | `needs_proof`.
> **Легенда STATUS (цикл 19, без изменений).** Для пунктов-возможностей `proven` = механизм работает и подтверждён метриками/воспроизводимым прогоном; `doubtful` = работает, но доказательство неполное или нестабильное; `needs_proof` = доказательств нет.
> **Для пунктов-дефектов** смысл инвентирован: `proven` = дефект воспроизводимо доказан; `doubtful` = воспроизводится, но атрибуция/влияние неясны; `needs_proof` = заявлен, но не подтверждён.
>
> Цикл 19: пере-ранжирование поверх цикла 18. **Ключевые изменения:**
> 1. **Найден новый дефект ранжирования памяти (п.2):** plain-text фолбэк сортирует записи по числу совпавших терминов **по убыванию**, но отдаёт `matched.slice(-limit)` — то есть **худшие** совпадения, а лучшие отбрасываются. Живой A/B: запрос `память сессии` при `limit=3` вернул 3 худших из 6 и не показал ни одной записи с 2/2 совпавшими терминами; при `limit=100` вернул все 6, но в обратном порядке (худшая первой). Источник: `packages/core/src/session/mem-record-store.ts:248` (`records: matched.slice(-limit).reverse().map(toRecord)`).
> 2. **Опровергнуто утверждение цикла 18 «память пишется автоматикой (compaction)».** Все 31 записи с `recorded_by=compaction` датированы **14–15 октября**, последняя — `2026-10-15 09:17:30`; `~/.local/share/opencode/log/memory-context.log` застыл на 7000 строках с mtime `2026-10-15 09:30`. Автозахват из compaction **мёртв ~6.5 суток**. За 24ч записано 92 записи, из них **91 — `recorded_by=build`** (агент зовёт `put` сам), 0 — compaction.
> 3. **Органика памяти выросла и стала настоящей:** `put_in_operational_memory` = **37** и `search_operational_memory` = **66** за 24ч (было 63/9504 = 0.66 %, теперь 103/9600 = **1.07 %**); из них **34 put + 37 search — в ad-hoc сессиях реальных пользователей** («Дебаг упавшего агента», «Исследование issue #158 в Zerocreds-server», «Продолжение задачи 253», «Фикс OpenCode session location unavailable» и др.), всего 25 сессий использовали memory-тулы. `mem_record` вырос 77 → **123** (+46 за 5.5 ч с момента снимка цикла 18; 92 новые за 24 ч), 120 active / 3 superseded, 12 проектов. **Побочный эффект цикла:** сделан первый в истории форка вызов `get_operational_memory` (чтение по id) — до этого он не вызывался **ни разу**.
> 4. **Ошибки Code Mode не попадают в `state.error` — метрика ошибок занижена примерно в 40 раз (п.13).** За 24ч `execute` отработал 607 раз, структурно помечено `status=error` всего **2** раза, тогда как текст `ReferenceError: Unknown identifier 'require' / 'shell'` лежит в **81 assistant-сообщении в 13 сессиях** как текстовая часть результата тула (`state.status=completed`, `state.error` пуст). Цикл 18 насчитал «13 ошибок в 10 сессиях» — это была не ошибка подсчёта по sessions, а не по событиям.
> 5. **Отдельный класс ошибок: модель гулит имена тулов (п.14).** `No tool named "bash"` — **34 случая в 15 сессиях за 24ч** (инструмент называется `shell`); внутри Code Mode та же болезнь — `Unknown identifier 'shell'` в коде песочницы. Это ровно то, что пользователь описывает как «доступ к инструментам».
> 6. **Атрибуция «мёртвых флагов v2» уточнена (п.12):** флагов нет не потому, что «не реализованы», а потому что **фича удалена целиком** — PR #165 «remove Ladder cache mask and recurring variant failures» (merged `2026-10-20T01:24:34Z`) снёс `CacheMask`/`CacheMark`, `provider_cache_mark` и все флаги. Причина удаления — юзерский баг: «маска Ladder убивает второй шаг ассистента с `ladder/*` (invalid ladder_cache_variant)» (пользователь, `2026-10-20 02:42`). `release-current.md` §«Флаги v2» и `run-selftest.sh:38-39` до сих пор рекламируют снятую фичу.
> 7. **Приёмка покрывает всё меньше (п.10, п.11):** прогон `20261021-200839` — **83 с против 393 с** у `165204` при тех же пяти check'ах; в T1 остался один вызов `cat`, ни `wc`, ни `awk`, ни `sha256` — модель взяла «3000 строк» из маркера усечения. Новый SHA `ae9a8a257548` меняет только TUI: `git diff --stat 1b3dc3065485..ae9a8a257548` → 2 файла, +177/−76 (`packages/tui/src/component/dialog-workspaces.tsx` + тест). Игла `CM-5581-A` размножилась в **413 сессиях из 656** (было 355/591).
> 8. **Дыра в живой БД уточнена:** полностью пустые **16, 17, 18 октября** (не 4.6 суток, а ~3.6 суток: `Oct 16 00:00 → Oct 19 ~15:00`); `Oct 15` — 3 сессии. За эти 3 дня CSM показывает **133 сессии / 39.7M input-токенов**.
> 9. **CSM-слепота растёт:** последняя opencode-сессия в CSM — `2026-10-19T14:33:57Z` (≈ **54 ч** назад), codex при этом индексируется до `2026-10-21T07:27Z`, сканер жив (`last_scanned_at` = `2026-10-21T11:43Z`). Окно добрано из живой БД: **296 человеческих промптов** из 419 (71 сессия).
> 10. **Диск чуть отыграл, но до порога 0.1 GiB:** свободно **5.1 GiB** (в цикле 18 было 4.0), `~/.worktrees` = **36 GiB** (27 ворктри, prune не делали), build skip (exit 78) за 24ч случился дважды (`2115`, `1351`).
> 11. **Плагины и отказы растут:** WARN в `opencode.log` = **1426**, из них **1081** `configured plugin path must be a directory` (в цикле 18 было 942); `every rung failed` = **525** (было 435).
> 12. **Хронология отстаёт на 2 прогона:** последний stamp в `ITERATIONS.md` — `20261021-1415`; прогоны `20261021-1651` и `20261021-2008` не внесены. `ISSUES.md` — 19 закрытых / **1** открытый; на GitHub — **17** открытых issue, 0 открытых PR.
>
> `STAMP: research-20261021-2022` (снимок метрик — `2026-10-21T17:20:42Z`, окно 24 ч от `2026-10-20T17:20:42Z`)

---

## Ranked by usefulness

1. **Память наполняется агентом (не автоматикой); compaction-автозахват мёртв с 15.10** — `high` — STATUS: `proven` — за 24ч 92 новые записи, из них **91 `recorded_by=build`** и **0** compaction; все 31 compaction-запись — от 14–15.10, последняя `2026-10-15 09:17:30`, `memory-context.log` не растёт с 15.10 09:30; органика выросла: 34 `put` в боевых ad-hoc сессиях.
2. **Plain-text поиск памяти отдаёт худшие совпадения и выбрасывает лучшие** — `high` — STATUS: `proven` — `mem-record-store.ts:248` `matched.slice(-limit).reverse()`; A/B: `память сессии` @ `limit=3` → 3 худших из 6, ни одной с 2/2 терминами; @ `limit=100` → все 6 в обратном порядке (худшая первой).
3. **NL-поиск: регулярка жива, морфологии нет; plain-text фолбэк — OR-семантика** — `high` — STATUS: `proven` — перепроверено: `изоляцию по проекту` (такой формы в тексте нет, `LIKE` → 0) **не находит** запись `mem_15ef2f24…` с «изоляция по проекту»; фолбэк требует `hits > 0` (любой термин), поэтому в выдачу попадают записи по одному общему слову; regex пробуется **первым** и любой запрос-фраза компилируется как regex.
4. **Память изолирована по проекту; `scope` — свободный тег, а не скоуп** — `high` — STATUS: `proven` — 123 записи в 12 проектах (в текущем — 44); запись `mem_15f062316001…` («bot repo strict branch protection», проект `993f5365…` = trained-agent-architecture) из моего проекта `6076e67…` **не вернулась**; `scope=issue-158-research` → `matched=0, filter_matched=0`.
5. **Сквозной резюв между сессиями работает** — `high` — STATUS: `proven` — `mem_15f348b16001…` записан в `19:04:01` в сессии `ses_ea1258b5…`, прочитан в моей `ses_ea08b111…` в `21:0x` — другая сессия, тот же проект, `authority=user`, `decided_by=agent` проставлены.
6. **CSM не индексирует opencode-сессии 54 ч** — `high` — STATUS: `proven` — последняя opencode-сессия `2026-10-19T14:33:57Z`; codex — до `2026-10-21T07:27Z`; сканер жив (`max(last_scanned_at)` = `2026-10-21T11:43Z`) → поломка в фильтре по агенту, не в процессе.
7. **Живая БД потеряла 3 полных сутка (16–18.10) пользовательской активности** — `high` — STATUS: `proven` — `session_v2`: 0 сессий 16/17/18.10; CSM за те же дни — **133 сессии / 39.7M input-токенов**; в БД сессии 19.10 начинаются в 15:xx, у CSM последние — в 14:xx → дыры не перекрываются.
8. **Merged-red: 61 из 98 слитых PR имеют FAILURE-чеки (62 %)** — `high` — STATUS: `proven` — полный GraphQL-скан `statusCheckRollup` по всем 98 merged PR: **61 `FAILURE`**, 10 только `CANCELLED`, **27 чистых** (в цикле 18 было 61/10/26 из 97 — +1 новый merged PR, чистый).
9. **Диск: 5.1 GiB free — в 0.1 GiB от порога 5 GiB; `~/.worktrees` = 36 GiB без prune** — `high` — STATUS: `proven` — 27 ворктри (22 старше 3 суток); build skip (exit 78) в прогонах `2115` и `1351` при свободных 4.0–4.5 GiB; `tool-output/` 1572 файла/61M, `shell/**/*.out` 1491/14M, `~/.opencode/builds` 626M/7.
10. **Приёмка зелёная, но check'и не доказывают заявленное, а T1 сдулся** — `high` — STATUS: `proven` — прогон `200839` — **83 с против 393 с** у `165204` при тех же 5 check'ах; в T1 только `cat`, ни `wc`/`awk`/`sha256`, «3000 строк» взяты из маркера усечения; needle `CM-5581-A` — в **413 сессиях из 656** и check не скоуплен; лосслесность проверяется одной строкой `grep -q` (`cmp`/`cksum`/`sha256` в `run-selftest.sh` нет).
11. **Новый SHA покрывает только TUI — приёмка не проверяет ничего нового** — `high` — STATUS: `proven` — `git diff --stat 1b3dc3065485..ae9a8a257548` → 2 файла, +177/−76 (`packages/tui/src/component/dialog-workspaces.tsx` + `packages/tui/test/cli/tui/prompt-move.test.tsx`); ядро, memory-тулы и shell не тронуты; `candidate == installed == ae9a8a257548` держится, но отдельного гейта в скрипте нет.
12. **Флаги v2 не существуют, потому что фича удалена — а релиз-ноты и харнесс её рекламируют** — `high` — STATUS: `proven` — PR #165 (merged `2026-10-20T01:24:34Z`) снёс `CacheMask`/`CacheMark`/`provider_cache_mark`/все флаги; `grep -rn 'CACHE_MASK\|cacheMask\|cache_mask' packages/core/src packages/opencode/src` → **0**; `provider_cache_mark` — 0 строк, `intent_signal` — 0 строк; `release-current.md` §«Флаги v2» и `run-selftest.sh:38-39` описывают снятую фичу как рабочую.
13. **Ошибки Code Mode не попадают в `state.error` — метрика отказов занижена ≈ в 40 раз** — `high` — STATUS: `proven` — `execute` 607 вызовов/24ч, `status=error` — **2**; текст `ReferenceError: Unknown identifier 'require'/'shell'` — в **81 assistant-сообщении в 13 сессиях**, причём внутри результата тула (`state.status=completed`, `state.error` пуст) ⇒ любой подсчёт по `state.error` этот класс отказов не видит.
14. **Модель гулит имена тулов: `bash` (34/24ч) и `shell` внутри Code Mode** — `medium` — STATUS: `proven` — `No tool named "bash"` — **34 случая в 15 сессиях** (инструмент называется `shell`), 22 из них — структурные tool-ошибки; в живой БД `execute`/`shell` падает с `Unknown identifier 'shell'`; пользователь жаловался ровно на это: «соседняя сессия пробует наш тул по написанию кода и он ей выдает ошибки: ✗execute ↳ ReferenceError».
15. **Тул `question` не показывает вопрос пользователю** — `medium` — STATUS: `proven` — 13 вызовов/24ч, 3 из них — ошибка; маркеры «Asked 1 question» — 31 за всё время в 4 сессиях; пользователь `2026-10-21 16:39:23`: «→Asked 1 question - а где вопрос не вижу?».
16. **Трекер отказа: `exit≠0` ≠ «артефакта нет»** — `medium` — STATUS: `proven` — за 24ч 9 прогонов / 52 шага → 40 ok, 6 failed, 4 withheld, 2 skipped; провалы `bug-reporter` (`2159`, `0521`), `researcher` (`0829`, `1651`), `architect` (`0521`, `1651`) — отчёты при этом созданы, закоммичены и запушены.
17. **Плагины форка не грузятся: 1426 WARN, из них 1081 «configured plugin path must be a directory»** — `medium` — STATUS: `proven` — растёт каждый цикл (583 → 711 → 942 → **1081**); приёмка идёт с выключенными плагинами, т.е. измеряемая линия отличается от пользовательской.
18. **Каскадные отказы накапливаются: `every rung failed` = 525** — `medium` — STATUS: `proven` — в `opencode.log` (51 МБ) счётчик монотонно растёт (219 → 245 → 304 → 422 → 435 → **525**); влияние на пользователя не измерено.
19. **Деньги и намерения не измеряются: `cost` мертва, `intent_signal`/`provider_cache_mark` пусты** — `medium` — STATUS: `proven` — `cost` = 0 при 633M cache-read; последняя сессия с `cost>0` — `2026-10-12 07:51:27`, всего 62 сессии на **$3.94**; `intent_signal` — 0 строк, `provider_cache_mark` — 0 строк; `intent` (другая таблица) — 0 строк.
20. **Компактификация жива, но не измеряется: `time_compacting` = 0 из 659** — `medium` — STATUS: `proven` — события компактификации есть: 38 compaction-сообщений за 24ч в 18 сессиях (19.10 — 23, 20.10 — 69, 21.10 — 33); маркеры `first_delivery` — 107/24ч, `compacted` — 131/24ч; но колонка `time_compacting` не заполняется ни разу ⇒ секция 8 `mem-metrics.sql` (compacted vs full) принципиально не может различать.
21. **Хронология отстаёт: два прогона (`1651`, `2008`) не внесены в ITERATIONS.md** — `low` — STATUS: `proven` — последний stamp в `ITERATIONS.md` — `20261021-1415`; ручной прогон `20261021-182109` (зелёный) тоже вне `chain-state.jsonl`.
22. **Локальный бэклог и GitHub-бэклог разошлись** — `low` — STATUS: `proven` — `ISSUES.md`: 19 закрытых / **1** открытый; GitHub: **17** открытых issue, 0 открытых PR ⇒ реальные открытые вопросы живут только в трекере.
23. **Долгоиграющие процессы на устаревшем коде** — `low` — STATUS: `needs_proof` — 4 launchd-задачи форка: `mem-chain` жив (pid 52281), `mem-architecture` и `mem-groomer` падают с exit −15, `mem-selftest` выгружен; влияние на пользователя не измерено.
24. **User feedback: 438 человеческих промптов, но CSM видит меньше половины** — `medium` — STATUS: `proven` — после классификации и дедупа: CSM 223 + живая БД 296 HUMAN (AUTO 159, SYN 7, пустых 2); окно CSM-слепой зоны (419 промптов, 71 сессия) добрано из живой БД — и там тема памяти заметно горячее, чем показывает CSM.

---

## Metrics digest (24h)

Снимок — **2026-10-21T17:20:42Z**, окно от `2026-10-20T17:20:42Z`. Предписанный `mem-metrics.sql` против `opencode-memory-context-v1.db` **по-прежнему даёт пустое окно 24 ч** (секции 1–3 и 8 — ноль строк; `session` в v1-клоне обрывается на `2026-10-12`). Ниже — пересчёт по живой БД v2 `~/.local/share/opencode/opencode.db` (таблицы `session_v2`, `session_message`, `mem_record`).

- **Sessions: 409**, Total tokens: in **26 893 297** / out **2 060 863** / reasoning **2 011 252**; Cache read: **633 288 347** (**95.9 %**), Cache write: **0** (0 за всю историю v2); **Cost: $0.00** — колонка мертва с `2026-10-12 07:51:27` (последняя сессия с `cost>0`; всего за всё время 62 сессии на **$3.94**).
- Разбивка: scheduled **345** / chain **26** / ad-hoc **38**; cache hit: ad-hoc 96.1 %, chain 95.6 %, scheduled 94.9 %.
- **Memory tools: overview = 0, find = 0, detail = 0** (v1-легаси `get_tool_call_overview`/`find_tool_calls`/`get_tool_call_details` в v1-клоне: 0 за 24 ч, 3 / 2 / 191 за всю историю) — **v2-настоящие**: на снимке `search_operational_memory` = **66**, `put_in_operational_memory` = **37**, `get_operational_memory` = **0**; с учётом вызовов самого этого цикла — **70 / 39 / 1**. **Первое в истории чтение памяти по id** сделано здесь (проверка пути «записал → прочитал по id»): до цикла 19 `get_operational_memory` не вызывался **ни разу** за всю историю форка. Итого **103 из 9600** tool-вызовов на снимке (**1.07 %**), 25 сессий; из них **34 put + 37 search — в ad-hoc сессиях реальных пользователей**, 32 — в chain. 5 записей цикла лежат со `scope=research-20261021-2022`.
- **Intent signals: cosine_avg = н/д, acted% = н/д** — таблица `intent_signal` существует, но **0 строк за всю историю**; `provider_cache_mark` — **0 строк**; таблица `intent` — **0 строк**. Метрика принципиально недостижима в v2 (фича снята PR #165).
- **Memory records: 123 на снимке** (120 active / 3 superseded; 12 проектов, 92 новые за 24 ч) **+ 5, записанных этим циклом** (`scope=research-20261021-2022`) = **128**; `recorded_by` за 24 ч: build 91 / review 1 / compaction **0**; `authority` user 34, agent 58; `decided_by` user 12, agent 22, NULL 58 ⇒ «решений пользователя» по `authority` завышено (34 против фактических 12).
- **Компактификация/доставка живы, но не измеряются:** compaction-сообщений **38** за 24 ч в 18 сессиях; маркеры `first_delivery` — **107**, `compacted` — **131** за 24 ч; при этом `time_compacting` NOT NULL — **0 из 659** сессий ⇒ `mem-metrics.sql` §8 не может разделить `compacted`/`full`.
- **Отказы тулов за 24 ч** (по `state.status='error'`): edit 27, bash 22 (все — `No tool named "bash"`), read 15, cloudflare_execute 11, shell 8, subagent 3, question 3, webfetch 2, search/put_operational_memory 2+2 (ошибки схемы: `reason: Expected string`, `type: Expected "decision"|...`, `query: Expected string` — один вызов передал `query: 253`), execute 2, write 1. **Не учтено этим счётчиком:** 81 assistant-сообщение с `ReferenceError` из Code Mode (см. п.13); из 34 строк с `No tool named "bash"` структурно помечены 22 (остальные — цитата в тексте ответа).
- Усечённых tool-выводов: **2644** в **71** сессии.
- **Цепочка за 24 ч: 9 прогонов / 52 шага** → 40 ok, 6 failed, 4 withheld, 2 skipped (build skip по диску в `2115` и `1351`); прогоны `1651` и `2008` — build/selftest/release/bug-reporter зелёные.
- **Диск:** `/` — 228 GiB total, 12 GiB used, **5.1 GiB avail** (порог сборки 5 GiB); `~/.worktrees` — **36 GiB** (27 ворктри); `~/.opencode/builds` — 626M/7; `~/.local/share/opencode/tool-output/` — 1572 файла/61M; `~/.local/share/opencode/shell/**/*.out` — 1491/14M.
- **CSM:** всего 795 сессий; за 7 дней — opencode **268** (последняя `2026-10-19T14:33:57Z`), codex **53** (до `2026-10-21T07:27Z`); сканер жив (`max(last_scanned_at)` = `2026-10-21T11:43Z`); таблица `issues` — 0 строк, `issues.jsonl` — 1 строка (идея «connection test», 2026-03-14), `reports/` — 6 файлов от 09.10 ⇒ канал обратной связи мёртв.

---

## User feedback top

Источники: `~/code/claude-session-manager/data/sessions.db` (read-only) + `data/issues.jsonl` + `data/reports/` + **добивка из живой БД** (окно CSM-слепой зоны `2026-10-19T14:33:57Z → 2026-10-21T21:00`). Классификация промптов: **438 уникальных HUMAN** (CSM 223 + LIVE 296, дедуп по (источник, сессия, текст)); AUTO 159, SYN 7, пустых 2 ⇒ **сигнал настоящий, но CSM видит меньше половины**.

1. **Доступ к инструментам / MCP / Code Mode** — count=**14** уникальных промптов + **60** технических отказов (34 `No tool named "bash"` в 15 сессиях; 81 `ReferenceError: Unknown identifier` в 13 сессиях) — severity=**high** — «тебе доступен mcp тул для написания кода js / ts ?», «соседняя сессия пробует наш тул по написанию кода и он ей выдает ошибки: ✗execute ↳ ReferenceError: Unknown identifier 'require'», «Cloudflare — странно там должно быть всего три тула у нас».
2. **Зависания / пустые ответы / падение агента** — count=**27** (CSM 23 / LIVE 4) — severity=**high** — «упал агент :( давай дебажить», «завис агент», «производственный агент зависает»; в БД — 9 «зависших» active-задач в production CP, закрытых вручную.
3. **CI / красные тесты / флаки** — count=**16** (CSM 9 / LIVE 7) — severity=**high** — совпадает с 61 merged-red PR; отдельно «windows shard 3/4 flake» в PR #165.
4. **Память / продолжение сессии / потеря кода** — count=**14** (CSM 6 / LIVE 8) — severity=**high** — «продолжай» ×11 (самый частый короткий промпт), «незакоммиченный код теряется», «сохранённые логи сессии».
5. **CSM / session-manager UI** — count=**19** (CSM 18 / LIVE 1) — severity=**high** — «localhost:3000/claude-sessions пуст», «reply и session manager из веб-интерфейса сломался — не работает для OpenCode и для Кодекса», «сессия пропала».
6. **Рантайм-ошибки ладдера (`invalid ladder_cache_variant`)** — count=**15** (CSM 5 / LIVE 10) — severity=**high** — «маска Ladder убивает второй шаг ассистента с ladder/*», «Error: invalid ladder_cache_variant — во! щас ты получил», «ты меняешь ладдер и он выдает ошибки» ⇒ **фича снята PR #165, но память о баге жива в трекере**.
7. **ZeroCreds / шаринг / туннели** — count=**30** (CSM 6 / LIVE 24) — severity=**medium** — issue #158; ngrok / sslip / lhr.life; «тунел умер?»; «нужно без сложной настройки для тех, кто не доверяет сайту zerocreds».
8. **Git-процесс / PR / merge** — count=**32** (CSM 12 / LIVE 20) — severity=**medium** — «делай через pr: сначала issue → прогнать тесты → мержить».
9. **Sandbox / провижининг** — count=**9** (CSM 4 / LIVE 5) — severity=**medium** — эпик #253, «Sandbox provisioning выключен».
10. **Chemistry GPT / rnd-forge (внешний продукт)** — count=**29** (CSM 25 / LIVE 4) — severity=**medium** — out of scope форка.
11. **CRM / выставки / Telegram deal bot** — count=**13** (CSM 8 / LIVE 5) — severity=**medium** — внешний продукт.
12. **HH / отклики на вакансии** — count=**4** (только LIVE) — severity=**low** — внешний продукт.
13. **Стоимость / инстансы** — count=**4** (CSM 2 / LIVE 2) — severity=**low** — «Наш инстанс 24/7 ≈ $0.47/мес — это один инстанс на все задачи?».
14. **Доставка результата / файл не на месте** — count=**2** (только LIVE) — severity=**medium** — «итог клади в даунлоадс», «положи его в даунлоадс».
15. **Тул `question`** — count=**1** — severity=**medium** — «→Asked 1 question - а где вопрос не вижу?».
16. **Сохранённые issues/идеи** — count=**1** (`issues.jsonl`, 2026-03-14) — severity=**low** — канал обратной связи не работает (таблица `issues` — 0 строк).

---

## Judge comments

- **Память наполняется агентом (п.1):** **Коррекция цикла 18 — «автозапись compaction» как характеристика v2 неверна.** Все 31 compaction-запись — от 14–15.10; `memory-context.log` застыл 15.10 09:30; за 24 ч compaction-писатель не сработал ни разу. **Реально есть** — органика: 34 `put` в 15+ боевых сессиях, база выросла 77 → 123, чтение по `search` между сессиями работает. **Сомнительно** — «решения пользователя»: `authority=user` у 34 из 92 новых записей, но `decided_by=agent` у 22 из них ⇒ метрика завышена почти вдвое; чтения по id (`get_operational_memory`) — до цикла 19 **0 за всю историю** при 69 `search` (в этом цикле сделан первый вызов — путь работает, но регламента нет). **Требуется** — отдельная метка авто-захвата vs решения человека; обязательный регламент «попросил сохранить → `put` + `get` по id»; счётчик вызовов тулов памяти в отчёт цепочки.
- **Ранжирование памяти (п.2) — новое:** **Реально есть и воспроизводится в 2 вызовах.** `mem-record-store.ts:248`: массив отсортирован по убыванию числа совпавших терминов, но наружу отдаётся `slice(-limit)` — хвост, то есть худшие; при `limit ≥ matched` порядок ещё и переворачивается. Реальный пользовательский запрос, где в выдаче нет ни одной сильно совпавшей записи, — это тихий провал фичи. **Требуется** — `matched.slice(0, limit)` либо разворот перед срезом + отдельный check «лучшая запись присутствует в выдаче».
- **NL-поиск (п.3):** **Цикл 18 был прав про регулярку, но недооценил два разных механизма.** (а) Regex пробуется **первым**, и любая фраза компилируется как regex ⇒ plain-text фолбэк включается только при нуле; при этом в regex `|` работает как альтернация, а не как список слов. (б) Фолбэк — **OR** (`hits > 0`), т.е. достаточно одного общего слова («проекту», «по»), из-за чего в выдачу попадает шум. **Доказано** — морфологии нет: `изоляцию по проекту` не находит «изоляция по проекту». **Требуется** — стемминг/нормализация русских форм; AND-семантика или минимальный порог `hits ≥ 2`; явная семантика regex-vs-plain в описании тула.
- **Изоляция по проекту (п.4):** реально есть, перепроверено на живых данных (запись из другого проекта не видна; `scope` не обходит фильтр). **Сомнительно** — продуктовое решение: должен ли агент видеть память соседнего проекта; сейчас 79 % записей (98 из 123) лежат вне текущего проекта и недоступны. **Требуется** — либо глобальный поиск с фильтром по проекту, либо явное поле «проект» и подсказка в хинте.
- **Сквозной резюв (п.5):** реально есть, перепроверено (запись `19:04:01` из другой сессии прочитана в `21:0x`). **Сомнительно** — `decided_by=agent` при `authority=user` в 22 новых записях ⇒ provenance частично ненадёжен. **Требуется** — сценарий «записал в одной сессии → прочитал в другой, другой проект/день» (сейчас только в пределах одного проекта).
- **CSM-слепота (п.6) — критично и ухудшается:** сканер жив, codex индексируется, opencode — нет с `2026-10-19T14:33:57Z` (≈54 ч). Значит, поломка в фильтре/сканере по агенту. **Требуется** — найти причину в CSM; она же, возможно, объясняет дыру 16–18.10 в живой БД (тот же фильтр по агенту/источнику). **Эффект на учёного** — треть окна трафика приходится добывать из живой БД руками.
- **Дыра 16–18.10 (п.7):** реально есть, величина уточнена (3 полных суток, не 4.6). **Сомнительно** — причина не установлена; версия «миграция v1→v2 перезаписала таблицы» остаётся лучшей из имеющихся (v1-`session` обрывается на 12.10, `session_v2` начинается с 09.10 и имеет дыру ровно с 16-го). **Требуется** — подтвердить/отвергнуть версию; per-session копия в отдельной БД.
- **Merged-red (п.8):** без изменений по существу — 61/10/27 из 98. **Требуется** — считать класс по полному скану и не чаще раза в цикл; продуктовая проверка в гейте.
- **Диск (п.9):** реально есть; в цикле 18 было 4.0 GiB, сейчас 5.1 — запас **0.1 GiB** до порога. **Требуется** — prune `~/.worktrees` (22 старых ворктри) **до** того, как цепочка снова начнёт скипать сборку; это дешёвое немедленное действие с измеримым эффектом.
- **Приёмка (п.10, п.11):** **Частично подтверждена, и покрытие регрессирует.** Зелёные прогоны есть (`1107`, `1651`, `2008`), `candidate == installed == ae9a8a257548` держится. **Опровергнуто** — «лосслесность подтверждена машинно (cmp/cksum/sha256)»: в `run-selftest.sh` нет ни одного `cmp`/`cksum`/`sha256`; лосслесность держится на одной строке `grep -q "big-output-line-2999"`. **Новое** — T1 перестал нагружать канал: 83 с против 393 с, `cat` вместо 7 проверочных ходов, «3000 строк» взяты из маркера. **Сомнительно** — check «needle retrieved» ищет `CM-5581-A` по всей БД, где игла уже в **413 сессиях из 656** ⇒ зелёный статус не доказывает ретрив в этой сессии; запасной путь (стр. 207-210) сканирует всю БД и может взять файл чужого прогона; новый SHA меняет только TUI, то есть ядро памяти/шелл последние 4 прогона не проверялись вовсе. **Требуется** — скоупить needle по `session_id` прогона; отдельный check `candidate_sha == installed_sha`; сверка полноты файла с исходником (`cmp`/`sha256`); минимум N машинных проверок в T1; варьировать фикстуру (сейчас 26 байт-идентичных копий одного файла).
- **Мёртвые флаги (п.12):** **Атрибуция уточнена — это не «не реализовано», а «удалено».** PR #165 снял маску и леджер после юзерского бага `invalid ladder_cache_variant`, который ломал второй шаг ассистента на Ladder. `release-current.md` и `run-selftest.sh` продолжают рекламировать снятую фичу ⇒ это дезориентирует и приёмку, и пользователя. **Требуется** — убрать из обеих инструкций; заодно решить, не вернуть ли кейс-скиплинг маски без ledger-записи.
- **Метрика отказов Code Mode (п.13) — новое:** реально есть, воспроизведено на живых данных: `execute` 607 вызовов, `state.error` — 2, а текстовых `ReferenceError` — 81 в 13 сессиях. То есть **структурный счётчик отказов не видит целый класс отказов песочницы**, и любые выводы «тулы падают редко» на таких данных неверны. **Требуется** — научить рантайм складывать ошибку песочницы в `state.error` (или парсить её из текста) и считать отказы по `execute`/`shell` отдельно.
- **Гуление имён тулов (п.14):** реально есть — 34 × `No tool named "bash"` в 15 сессиях за 24 ч; модель привыкла к `bash`, в форке инструмент называется `shell`. **Сомнительно** — доля «вины» модели vs отсутствия алиаса: алиас `bash`→`shell` закрыл бы весь класс одной строкой. **Требуется** — алиас или автоподстановка; в описании Code Mode — список доступных глобалей (`require`, `Buffer`, `shell`, `cloudflare`, `accountId` отсутствуют).
- **`question` (п.15):** реально есть — пользователь не видит вопрос, который модель задала. **Требуется** — отрисовать вопрос в TUI; сейчас виден только маркер «Asked 1 question».
- **Трекер отказа (п.16):** реально есть — 6 failed / 4 withheld за 24 ч, артефакты при этом есть. **Требуется** — разделить `exit` и `artifact_present`; вносить провалы в ITERATIONS/ISSUES.
- **Плагины (п.17):** реально есть, растёт (1081). **Требуется** — валидатор путей в конфиге + прогон приёмки с включёнными плагинами.
- **Каскадные отказы (п.18):** реально есть — 525. Влияние на пользователя не измерено; сам счётчик — индикатор деградации окружения, а не фичи.
- **Деньги/намерения (п.19):** доказано — `cost`, `intent_signal`, `provider_cache_mark` мертвы. **Требуется** — починить `cost` (или считать по `tokens_*` с прайсом) либо убрать из дайджеста; `cosine_avg`/`acted%` в текущем виде недостижимы.
- **Компактификация (п.20):** **Коррекция в другую сторону.** Компактификация и first-delivery **живы** — 38 compaction-событий и 107 маркеров `first_delivery` за 24 ч; мёртва только колонка `time_compacting` (0 из 659) ⇒ метрика «compacted vs full» из `mem-metrics.sql` §8 недостижима. **Требуется** — заполнять `time_compacting` (или перейти на `session_message.type='compaction'` как на источник истины) и переписать §8 под v2.
- **Хронология/бэклоги (п.21, п.22):** реально есть — `ITERATIONS.md` отстаёт на 2 прогона, локальный бэклог (1 открытый) разошёлся с GitHub (17). **Требуется** — единый источник правды.
- **Процессы на старом коде (п.23):** реально есть — `mem-architecture`/`mem-groomer` падают с −15, `mem-selftest` выгружен. Влияние не измерено; оставляю `needs_proof`.
- **User feedback (п.24):** **Объём больше, чем в цикле 18, и картина иная.** 438 уникальных человеческих промптов против ~270 ранее; но **тема памяти видна только в LIVE-окне** (8 из 14 уникальных), тогда как CSM доминируют внешние продукты (chemistry 25, crm 8, hh 4). То есть **сигнал по собственной фиче форка в CSM занижен** — решение принимается по чужой картине. **Требуется** — чинить индекс CSM по opencode и добавить в CSM-индекс форк-специфичные теги (память, ладдер, приёмка).

---

## Приложение: как снимались метрики (воспроизводимо)

```bash
# 0. Предписанный запуск (для сравнения) — даёт пустое окно 24ч
sqlite3 ~/.local/share/opencode/opencode-memory-context-v1.db < ~/.opencode/scripts/mem-metrics.sql

# 1. Живая БД v2 — метрики сессий за 24ч
sqlite3 ~/.local/share/opencode/opencode.db "
SELECT count(*) sessions, sum(tokens_input) tok_in, sum(tokens_output) tok_out,
       sum(tokens_reasoning) tok_reason, sum(tokens_cache_read) cache_r, sum(tokens_cache_write) cache_w,
       round(100.0*sum(tokens_cache_read)/nullif(sum(tokens_input)+sum(tokens_cache_read),0),1) hit_pct,
       round(sum(cost),4) cost
FROM session_v2 WHERE time_created > (strftime('%s','now')-86400)*1000;"

# 2. Memory-тулы (v2) — все вызовы + доля
sqlite3 ~/.local/share/opencode/opencode.db "
SELECT j.value->>'name' tool, count(*) n
FROM session_message m, json_each(m.data,'\$.content') j
WHERE m.type='assistant' AND json_extract(j.value,'\$.type')='tool'
  AND m.time_created > (strftime('%s','now')-86400)*1000
GROUP BY 1 ORDER BY n DESC;"

# 3. Структурные отказы тулов (НЕ видят ошибки песочницы — см. п.13)
sqlite3 ~/.local/share/opencode/opencode.db "
SELECT json_extract(j.value,'\$.name') tool, count(*) n
FROM session_message m, json_each(m.data,'\$.content') j
WHERE m.type='assistant' AND json_extract(j.value,'\$.type')='tool'
  AND json_extract(j.value,'\$.state.status')='error'
  AND m.time_created > (strftime('%s','now')-86400)*1000 GROUP BY 1 ORDER BY n DESC;"

# 4. Ошибки Code Mode, которые НЕ попали в state.error
sqlite3 ~/.local/share/opencode/opencode.db "
SELECT count(*), count(DISTINCT session_id) FROM session_message
WHERE type='assistant' AND data LIKE '%Unknown identifier%'
  AND time_created > (strftime('%s','now')-86400)*1000;"

# 5. Mem-record: кто писал, authority, проекты
sqlite3 ~/.local/share/opencode/opencode.db "
SELECT recorded_by, authority, coalesce(decided_by,'NULL'), count(*) FROM mem_record GROUP BY 1,2,3;
SELECT count(*), count(DISTINCT project_id) FROM mem_record;
SELECT recorded_by, date(time_created/1000,'unixepoch','localtime'), count(*) FROM mem_record GROUP BY 1,2;"

# 6. Компактификация: события живы, колонка мертва
sqlite3 ~/.local/share/opencode/opencode.db "
SELECT date(time_created/1000,'unixepoch','localtime'), count(*) FROM session_message WHERE type='compaction' GROUP BY 1;
SELECT count(*) FROM session_v2 WHERE time_compacting IS NOT NULL;"

# 7. Intent / cache-mark / cost
sqlite3 ~/.local/share/opencode/opencode.db "
SELECT count(*) FROM intent_signal; SELECT count(*) FROM provider_cache_mark; SELECT count(*) FROM intent;
SELECT count(*), round(sum(cost),4) FROM session_v2 WHERE cost>0;"

# 8. Мёртвые флаги v2 — их нет ни в коде, ни в бинаре
grep -rn 'CACHE_MASK\|cacheMask\|cache_mask' /Users/vova/code/opencode-mem-work/packages/core/src /Users/vova/code/opencode-mem-work/packages/opencode/src | wc -l
strings -a ~/.opencode/bin/opencode | grep -c -E 'OPENCODE_CACHE_MASK|OPENCODE_CACHE_MARK_IDLE_MS|OPENCODE_MEMORY_INTENT|OPENCODE_MEMORY_CONTEXT'

# 9. CSM: последняя проиндексированная opencode-сессия vs сканер
sqlite3 ~/code/claude-session-manager/data/sessions.db "
SELECT agent_type, count(*), max(created_at) FROM sessions
WHERE created_at > datetime('now','-7 days') GROUP BY 1;
SELECT max(last_scanned_at) FROM sessions;"

# 10. Merged-red: полный скан слитых PR (GraphQL statusCheckRollup по head-коммиту)
gh api graphql -f query='query{repository(owner:"gpt-mem",name:"opencode-mem"){pullRequests(states:MERGED,first:100){nodes{number mergedAt commits(last:1){nodes{commit{statusCheckRollup{state contexts(first:50){nodes{__typename ... on CheckRun{name conclusion status} ... on StatusContext{state context}}}}}}}}}}}' \
  --jq '[.data.repository.pullRequests.nodes[] | {ctx:[.commits.nodes[0].commit.statusCheckRollup.contexts.nodes[] | (.conclusion // .state)]}]
        | {total: length, failure: (map(select(.ctx|index("FAILURE")))|length),
           cancelled_only: (map(select((.ctx|index("FAILURE"))|not)|select(.ctx|index("CANCELLED")))|length),
           clean: (map(select((.ctx|index("FAILURE"))|not)|select((.ctx|index("CANCELLED"))|not))|length)}'

# 11. Ранжирование памяти — эмуляция store-алгоритма (проверено живьём: limit=3 vs limit=100)
python3 - <<'EOF'
import sqlite3, re, os
DB=os.path.expanduser("~/.local/share/opencode/opencode.db")
con=sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
P='6076e6713333c0b0555eb63f25cd53d74bcf1246'   # project_id текущей сессии
rows=con.execute("SELECT id,subject,content,reason FROM mem_record WHERE project_id=?", (P,)).fetchall()
def hay(r): return "\n".join([r[1] or "", r[2] or "", r[3] or ""])
def sim(query, limit):
    try: rx=re.compile(query, re.I); m=[r for r in rows if rx.search(hay(r))]
    except re.error: m=[]
    if m: return ('regex', [r[0] for r in m[-limit:]][::-1])
    terms=[t for t in re.split(r'[^\w]+', query.lower(), flags=re.U) if t]
    sc=[(sum(1 for t in terms if t in hay(r).lower()), r) for r in rows]
    sc=[x for x in sc if x[0]>0]; sc.sort(key=lambda x:-x[0])
    m=[r for _,r in sc]
    return ('plain', [r[0] for r in m[-limit:]][::-1])   # <- так же, как в store
print(sim("память сессии", 3)); print(sim("память сессии", 100))
EOF
```

**Итог:** предписанный `mem-metrics.sql` к v1-клону сегодня бесполезен (пустое окно 24 ч, все три секции метрик пусты). Рабочий источник — `~/.local/share/opencode/opencode.db` (`session_v2`, `session_message`, `mem_record`) плюс `sessions.db` CSM для user feedback. Требуется переписать `mem-metrics.sql` под v2 — иначе учёный каждый цикл пересчитывает метрики вручную.
