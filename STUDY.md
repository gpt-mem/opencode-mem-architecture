# STUDY research-20261021-1445 — ранжированный список находок (обновлённый учёным)

> Обновляется сессией researcher. Формат пункта:
> `[rank] <польза> STATUS — <обоснование>`. STATUS: `proven` | `doubtful` | `needs_proof`.
> **Легенда STATUS (цикл 18).** Для пунктов-возможностей `proven` = механизм работает и подтверждён метриками/воспроизводимым прогоном; `doubtful` = работает, но доказательство неполное или нестабильное; `needs_proof` = доказательств нет.
> **Для пунктов-дефектов** смысл инвентирован: `proven` = дефект воспроизводимо доказан; `doubtful` = воспроизводится, но атрибуция/влияние неясны; `needs_proof` = заявлен, но не подтверждён.
>
> Цикл 18: пере-ранжирование поверх цикла 17. **Ключевые изменения:**
> 1. **NL-поиск `#187` — цикл 17 ошибся в атрибуции.** Регулярка живая (`OPENCODE_.*_MASK` → matched), plain-text-фолбэк живой (`релиз-ноты селftest` → matched=1). Настоящие ограничения другие: **нет морфологии** (`потеряла` → matched=1, `потерять` → matched=0 на той же записи) и **изоляция по проекту** (77 записей в 9 проектах, из текущего проекта видно 20; запрос со `scope=issue-158-research` из другого проекта → filter_matched=0). 9 «нулевых» вызовов за 24ч — это **не дефект матчера**: 2 из них сделаны за 16–35 с *до* появления искомой записи, 1 — падеж, остальные — «записи нет в скоупном проекте».
> 2. **Сквозной резюв между сессиями — `proven` (было needs_proof).** `ses_acc_a` put 17:40:34 → `ses_acc_b` отдаёт запись в 17:40:58; `ses-acc-A` put 19:18:23 → `ses-acc-B` находит её в 19:18:49. `authority=user`, `decided_by=user` проставляются корректно.
> 3. **Память наполняется автоматикой, а не по просьбе.** 77 записей: `recorded_by` = build 45 / **compaction 31** / review 1; compaction-писатель ставит и `authority=user`, и `decided_by=user` → «решений пользователя» 47 из 77, а записей, помеченных одновременно `recorded_by=build` и `decided_by=user`, — всего 7. При этом вызовов memory-тулов за 24ч — **63 из 9504 (0.66%)**, а `get_operational_memory` — **0 за всю историю**.
> 4. **CSM перестал индексировать opencode-сессии на 48 ч** (последняя — 2026-10-19T14:33:57Z; codex при этом индексируется до 2026-10-21; сканер жив, `last_scanned_at` = 2026-10-21T11:43Z). Живая БД при этом полна: **461 сессия / 66.3M input-токенов** за это же время.
> 5. **Живая БД, наоборот, потеряла 4.6 суток** (Oct 15 00:00 → Oct 19 15:00): 0 сессий против 165 сессий / 41.7M input-токенов по CSM. **Дыры комплементарны** — «слепые зоны» двух источников не перекрываются.
> 6. **24-часовое окно снова репрезентативно**: 381 сессия, из них 36 ad-hoc с живыми человеческими заголовками в реальных проектных каталогах (утверждение цикла 17 «в окне только цепочка» больше не верно).
> 7. **Merged-red переоценён вверх**: полный GraphQL-скан всех 97 слитых PR → **61 с `FAILURE`**, 10 только с `CANCELLED`, **26 чистых** (цикл 17 называл 27/19/56). REST-верификация на #4/#87/#184/#1 совпала.
> 8. **Диск: 4.0 GiB free — уже ниже порога 5 GiB.** `~/.worktrees` = 36 GiB (27 ворктри, 22 старше 3 суток), prune не делали и в этом цикле (с цикла 17 без изменений). Build skip (exit 78) в прогонах `2115` и `1351`.
> 9. **Новые дефекты:** тул `question` не показывает вопрос пользователю (13 вызовов/24ч, 8 маркеров «Asked 1 question», пользователь: «а где вопрос не вижу?»); Code Mode `execute` — 13 жёстких ошибок в 10 сессиях за 24ч (`Unknown identifier 'require'/'Buffer'/'cloudflare'`, `ImportExpression is not supported`).
> 10. **Приёмка**: `candidate == installed` держится (`1b3dc3065485`), но отдельного check'а на это в скрипте нет; needle-константа `CM-5581-A` встречается в **365 сессиях / 814 сообщениях** живой БД → проверка «needle retrieved» проходит по чужим данным. **Опровергнуто утверждение цикла 17** «лосслесность подтверждена машинно (cmp/cksum/sha256)»: в `run-selftest.sh` нет ни одного `cmp`/`cksum`/`sha256` — лосслесность держится на одной строке `grep -q`.

`STAMP: research-20261021-1445`

---

## Ranked by usefulness

1. **NL-поиск op-memory работает (regex + plain-text), но без морфологии** — `high` — STATUS: `proven` — живой A/B: `OPENCODE_.*_MASK` → matched, `релиз-ноты селftest` → matched=1, `worktrees mem-metrics` → matched=2; падеж ломает: `потеряла` → matched=1, `потерять` → matched=0 на той же записи (PR #187 «fall back to plain-text matching» — в main).
2. **Память изолирована по проекту: 77 записей в 9 проектах, из текущего видно 20** — `high` — STATUS: `proven` — `search_operational_memory` фильтрует по `project_id`: запись со `scope=issue-158-research` лежит в проекте `/Users/vova/code/zerocreds-server`, а запрос с этим scope из другого проекта даёт `filter_matched=0`; `scope` — свободный тег, а не механизм скоупа.
3. **Сквозной резюв между сессиями работает** — `high` — STATUS: `proven` — `ses_acc_a` put 17:40:34 → `ses_acc_b` (поиск без query) в 17:40:58 отдаёт `mem_15a66a125001K5AosPw2Du0rzT`; `ses-acc-A` put 19:18:23 → `ses-acc-B` в 19:18:49 находит запись многословным запросом; `authority=user`/`decided_by=user` проставлены.
4. **Память пишется автоматикой (compaction), а не по запросу человека** — `high` — STATUS: `proven` — 77 записей: `recorded_by` = build 45 / **compaction 31** / review 1; compaction-писатель ставит и `authority=user`, и `decided_by=user` → по `authority` авто-захват от решений человека не отличить, только по `recorded_by`; при этом вызовов memory-тулов за 24ч **63 из 9504 (0.66%)**, `get_operational_memory` — **0 за всю историю**, scope `chemistry-gpt` — **0 записей**, хотя пользователь просил дважды.
5. **CSM перестал индексировать opencode-сессии (48 ч)** — `high` — STATUS: `proven` — последняя opencode-сессия в CSM — 2026-10-19T14:33:57Z; codex индексируется до 2026-10-21; сканер жив (`max(last_scanned_at)` = 2026-10-21T11:43Z); живая БД доказывает, что за это время прошло **461 сессия / 66.3M input-токенов**.
6. **Живая БД потеряла 4.6 суток пользовательской активности (Oct 15 00:00 → Oct 19 15:00)** — `high` — STATUS: `proven` — в `session_v2` 0 сессий за Oct 15/16/17/18, тогда как CSM за те же дни показывает 165 сессий / 41.7M input-токенов; в БД сессии Oct 19 начинаются в 15:xx, у CSM последние — в 14:xx → дыры не перекрываются.
7. **Merged-red: 61 из 97 слитых PR имеют FAILURE-чеки (63%)** — `high` — STATUS: `proven` — полный GraphQL-скан `statusCheckRollup` по всем 97 merged PR: 61 `FAILURE`, 10 только `CANCELLED`, 26 чистых; REST-сверка #4 (2×failure), #87 (1), #184 (1), #1 (5×cancelled) — совпала.
8. **Диск: 4.0 GiB free — ниже порога 5 GiB; `~/.worktrees` = 36 GiB без prune** — `high` — STATUS: `proven` — 27 ворктри, 22 старше 3 суток; build skip (exit 78) в прогонах `2115` и `1351`; `~/.opencode/builds` 470M/6, `tool-output/` 1477 файлов/61M, `shell/*.out` 1095/11M.
9. **Флаги v2 не существуют, но релиз-ноты и селftest их обещают/экспортируют** — `high` — STATUS: `proven` — `strings` по установленному бинарю: 0 вхождений `OPENCODE_CACHE_MASK`, `OPENCODE_CACHE_MARK_IDLE_MS`, `OPENCODE_MEMORY_INTENT`, `OPENCODE_MEMORY_CONTEXT`, `intent_signal`; `release-current.md` §«Флаги v2» описывает первые два; `run-selftest.sh:38-39` их экспортирует, стр. 128 утверждает, что они «действуют именно на эту проверку».
10. **Приёмка зелёная, но check'и не доказывают то, что заявляют** — `high` — STATUS: `doubtful` — needle-константа `CM-5581-A` — фиксированная строка в 365 сессиях / 814 сообщениях живой БД, проверка (стр. 224) грепает весь файл БД → проходит по данным чужого прогона; лосслесность spilled-вывода проверяется **одной** строкой `grep -q "big-output-line-2999"` (стр. 218) — сравнения с исходником (`cmp`/`cksum`/`sha256`) в `run-selftest.sh` нет вообще; `candidate == installed` фактически держится (`1b3dc3065485`), но отдельного check'а на равенство в скрипте нет — `INSTALLED_VER` только логируется (стр. 65/67/243).
11. **Харнесс отдаёт модели начало окна, срезанное по байту, а не по строке** — `medium` — STATUS: `proven` — `selftest-20261021-165204.log:10` → `ig-output-line-2975` (потерян первый байт `b`), при маркере «showing lines 2976-3000 of 3000»; 92 таких строки в том же логе.
12. **Деньги и намерения не измеряются: `cost` мертва, `intent_signal`/`provider_cache_mark` пусты** — `medium` — STATUS: `proven` — `cost` = 0 при 474.7M cache-read (последний `cost>0` — 2026-10-12 04:51Z, всего $3.94 за 62 сессии); `time_compacting` NOT NULL — 0 из 609 сессий при 7000 строк в `memory-context.log`, где `compacted=1..90` и `first_delivery=true` в 6178 строках → компактификация и first-delivery в v2 **живы**, мёртвы только cache-mask и intent.
13. **Code Mode `execute` ломается на песочнице: 13 ошибок в 10 сессиях за 24ч** — `medium` — STATUS: `proven` — `ReferenceError: Unknown identifier 'require' / 'Buffer' / 'cloudflare' / 'shell' / 'accountId' / 'text'`, `SyntaxError: Syntax 'ImportExpression' is not supported` — в описании тула нет списка доступных глобалей.
14. **Тул `question` не показывает вопрос пользователю** — `medium` — STATUS: `proven` — 13 вызовов / 24ч, 8 маркеров «Asked 1 question»; пользователь 2026-10-21 13:39:23 в `ses_ea278b864ffekQH5xcPNDtiryp`: «→ Asked 1 question - а где вопрос не вижу?».
15. **Плагины форка не грузятся: 942 WARN `configured plugin path must be a directory`** — `medium` — STATUS: `proven` — растёт каждый цикл (779 → 909 → 942); приёмка идёт с выключенными плагинами, то есть в конфиге пользователя не измеряется.
16. **Каскадные отказы накапливаются: `every rung failed` = 435** — `medium` — STATUS: `proven` — в `opencode.log` (44 MB) счётчик растёт монотонно (219 → 245 → 304 → 422 → 435).
17. **Трекер отказа: `exit≠0` ≠ «артефакта нет»** — `medium` — STATUS: `proven` — за 24ч 9 прогонов / 52 шага → 39 ok, 6 failed, 5 withheld, 2 skipped; провалы `1913` (researcher exit=1 при уже запушенном коммите), `0521` (bug-reporter + architect), `0829` (researcher) — артефакты при этом есть.
18. **User feedback: 202 из 268 промптов CSM — реальные люди** — `medium` — STATUS: `proven` — 36 AUTO (`# Исполнитель Epic`, `# Роль: worker/architect`, `You are an autonomous worker`), 28 SYN (`Say hello`, `Reply with OK`, `Use the pdf_read tool exactly once`, `Call engineering_ci_wait`), **202 HUMAN**, 2 пустых; топ-боли: CSM/session-manager UI 22, Chemistry GPT 24 (внешний продукт), CI/красные тесты 49, доступ к инструментам 65, зависания/пустые ответы 31, память/продолжение 18.
19. **Дефект «ответ модели ≠ исходник» не воспроизводится, но стресс-случай сдулся** — `medium` — STATUS: `doubtful` — полное эхо 3000 строк было 2026-10-20 (`233804`: 3023 исходные строки в ответе); за последние 4 прогона в ответе лишь **30–76 исходных строк** (161822 — 30, 165204 — 54), т.е. T1 фактически не нагружает канал; при этом набивка строк цела (максимальный x-run = 60 во всех логах, обрезанных прогонов почти нет).
20. **Хронология отстаёт: последний прогон `1651` (4/4 ok) не внесён в ITERATIONS.md** — `low` — STATUS: `proven` — в `ITERATIONS.md` есть `1415` и `1351` (2 упоминания), но `1651` — 0; `ISSUES.md` — 19 закрытых / 1 открытый, при 17 открытых issue на GitHub.
21. **Локальный бэклог и GitHub-бэклог разошлись** — `low` — STATUS: `proven` — в `ISSUES.md` открыт 1 пункт, на GitHub — 17 открытых issue; риск, что реальные открытые вопросы живут только в трекере.
22. **Долгоиграющие процессы на устаревшем коде** — `low` — STATUS: `needs_proof` — 4 launchd-задачи форка: `mem-chain` жив (pid 14995), `mem-architecture` и `mem-groomer` падают с exit −15, `mem-selftest` выгружен; влияние на пользователя не измерено.

---

## Metrics digest (24h)

Снимок снят **2026-10-21T14:45:31Z** по живой БД `~/.local/share/opencode/opencode.db`, таблицы `session_v2` + `session_message`. **Предписанный `mem-metrics.sql` против `opencode-memory-context-v1.db` по-прежнему даёт пустое окно 24ч**: 0/0/0 вызовов `get_tool_call_overview`/`find_tool_calls`/`get_tool_call_details`, одна реликтовая строка `provider_cache_mark` от 2026-10-12, секция `signals` — 0 строк. Ниже пересчёт вручную.

- **Sessions: 381**, Total tokens: in **22 490 040** / out **1 731 169** / reasoning **1 640 528**; Cache read: **474 733 961** (**95.5%**), Cache write: **0** (0 за всю историю v2); **Cost: $0.00** — колонка мертва с 2026-10-12 04:51Z (последняя сессия с `cost>0`; всего за всё время 62 сессии на **$3.94**).
- **Memory tools: overview=0, find=0, detail=0 calls** (v1-легаси в `opencode-memory-context-v1.db`: 0 за 24ч, 3 / 2 / 191 за всю историю) — **v2-настоящие**: `search_operational_memory` = **42**, `put_in_operational_memory` = **21**, `get_operational_memory` = **0** → итого **63 из 9504** tool-вызовов (**0.66%**) за 24ч; за всю историю — 45 / 21 / **0**, то есть чтение по id не вызывалось ни разу.
- **Intent signals: cosine_avg = н/д, acted% = н/д** — таблица `intent_signal` — 0 строк за всю историю, `provider_cache_mark` — 0 строк в живой БД, в бинаре нет ни `intent_signal`, ни семейства `OPENCODE_MEMORY_*`. Метрика принципиально недостижима в v2.
- Разбивка сессий за 24ч: scheduled **318** / chain **27** / ad-hoc **36** (живые человеческие заголовки в `/Users/vova/code/trained-agent-architecture`, `/Users/vova/code/.worktrees/...`, `/Users/vova/.worktrees/...`).
- Дополнительно: усечённых tool-выводов **2597** в **76** сессиях; `mem_record` — **77** записей (`recorded_by` build 45 / compaction 31 / review 1; `authority` user 47 / agent 30; `decided_by` user 37 / agent 10 / null 30; 9 проектов; scope `chemistry-gpt` — 0). **Важная деталь:** compaction-писатель проставляет и `authority=user`, и `decided_by=user` (все 31 его записи) → по `authority` нельзя отличить авто-захват от решения человека, различать надо по `recorded_by`; `time_compacting` NOT NULL — **0 из 609** сессий; сессий по дням за всю историю: Oct 09 — 11, Oct 10 — 55, Oct 11 — 15, Oct 12 — 1, Oct 13 — 16, Oct 14 — 50, **Oct 15–18 — 0**, Oct 19 — 24, Oct 20 — 150, Oct 21 — 282; freelist 48 страниц (было 5595 → 353 → 48, БД подчистили).
- Цепочка за 24ч: **9 прогонов / 52 шага** → 39 ok, 6 failed, 5 withheld, 2 skipped (build skip по диску в `2115` и `1351`).

---

## User feedback top

Источники: `~/code/claude-session-manager/data/sessions.db` (795 сессий; **268** opencode-сессий за 7 дней) + `issues.jsonl` + `reports/` + **добивка из живой БД** (окно Oct 19 15:00 → Oct 21 14:32, 381 человеческий промпт, которых CSM уже не видит). Классификация промптов CSM: **36 AUTO / 28 SYN / 202 HUMAN / 2 пустых** — то есть 75 % сигнала настоящие.

1. **Доступ к инструментам / MCP / js-ts-code** — count=**65** (CSM) + **81** (живая БД, окно CSM-слепой зоны) — severity=**high** (и «тебе доступен mcp тул», и «пропали доступы к обычным инструментам»; в живой БД — пачка `js-ts-code` и `Code Mode` ошибок).
2. **CI / красные тесты** — count=**49** (CSM) + **13** (живая БД) — severity=**high** (блокирует мержа; совпадает с 61 merged-red PR; отдельно — «windows shard 3/4 flake» в PR #165).
3. **Зависания / пустые ответы / падение агента** — count=**31** (CSM) + **12** (живая БД) — severity=**high** («упал агент :(», «production agent hangs», «не дошла до ответа»).
4. **CSM / session-manager UI** — count=**22** — severity=**high** (`localhost:3000/claude-sessions` пуст, сессия пропала, worktree не создался; сервисные счётчики 7д: `session_worktree_skipped=117`, `session_start_missing_from_sidebar=21`, `session_start_no_id=22`, `delegation_reply_no_child=15`, `session_start_in_sidebar=27` из 79 полученных id).
5. **Chemistry GPT (внешний продукт)** — count=**24** — severity=**medium** (out of scope форка: жалобы идут, форк ни при чём).
6. **Память / продолжение / логи сессии** — count=**18** (CSM) + **49** (живая БД) — severity=**high** (прямой запрос «план в operational memory (scope chemistry-gpt)» ×2 — записи нет; «продолжай работу с сохранением логов сессии»; «незакоммиченный код теряется»).
7. **ZeroCreds / шаринг / туннели** — count=**10** (CSM) + **36** (живая БД) — severity=**medium** (issue #158; ngrok / sslip / lhr.life; «тунел умер?»).
8. **Sandbox / провижининг** — count=**13** — severity=**medium** (эпик #253, «Sandbox provisioning выключен»).
9. **Вопросы к агенту (тул `question`)** — count=**5** — severity=**medium** («→ Asked 1 question - а где вопрос не вижу?» — вопрос не показан).
10. **Сохранённые issues/идеи** — count=**1** (`issues.jsonl`: идея «connection test», 2026-03-14); таблица `issues` — **0** строк; `reports/` — 6 отчётов от 09.10 — severity=**low** (канал обратной связи не работает).

---

## Judge comments

- **NL-поиск (п.1):** **Коррекция цикла 17 — «дефект регулярки» не подтвердился.** Regex работает (`OPENCODE_.*_MASK` → matched, `tunnel|туннель|share` → matched), plain-text-фолбэк работает (`релиз-ноты селftest` → matched=1, `worktrees mem-metrics` → matched=2). 9 нулевых ответов за 24ч объясняются: (а) поиск шёл **до** записи — `tunnel` в 11:56:27, запись в 11:56:43; `js-ts-code` в 11:39:54, запись в 11:40:29; (б) падеж — `миграции форка идемпотентные` против записи «Миграции форка обязаны быть идемпотентными»; (в) записи нет в скоупном проекте — `hh|отклик|ваканс|trained-assist` в проекте `opencode-mem-architecture` не совпал ни с одной из 20 записей. Собственный хинт тула уже велит повторить без query. **Требуется** — стемминг/нормализация русских форм (главный реальный пробел) и внятная семантика regex-vs-plain: сейчас приоритет у regex, поэтому запрос с `|` молча трактуется как альтернация, а не как список слов.
- **Изоляция по проекту (п.2):** реально есть — 77 записей в 9 проектах, из текущего видно 20 (26 %). **Сомнительно** — `scope` вводит в заблуждение: он выглядит как механизм скоупа, но фильтр проекта сильнее. **Требуется** — либо глобальный поиск с фильтром, либо явное поле «проект» в записи и подсказка в хинте; продуктово решить, должен ли агент видеть память соседнего проекта.
- **Сквозной резюв (п.3):** реально есть — две независимые пары сессий, запись→поиск в пределах 20–30 с, `authority`/`decided_by` проставлены. **Сомнительно** — обе пары созданы вручную в тест-проекте `mem-accept`; в боевых проектах записей 77, но чтений по id нет ни разу. **Требуется** — боевой сценарий «записал в одной сессии → прочитал в другой, другой проект/день».
- **Автоматическое наполнение (п.4):** реально есть — 31 из 77 записей написал compaction-писатель, `authority` user у 47. **Сомнительно** — это фоновая автозапись по compaction, а не память «по запросу человека»; причём compaction-писатель ставит `decided_by=user`, так что метрика «решений пользователя» завышена; `scope=chemistry-gpt` пуст при двух прямых просьбах; `get_operational_memory` = 0 → инструмент чтения по id не используется вообще. **Требуется** — закрыть просьбу «сохрани план в scope X» наблюдаемым фактом; разделить метки авто-захвата и решений человека (например, `recorded_by=compaction` ≠ `decided_by=user`).
- **CSM-слепота (п.5):** **Критично.** Сканер жив, codex индексируется, opencode — нет с 2026-10-19T14:33Z. Значит, поломка именно в фильтре/сканере по агенту, а не в процессе. **Требуется** — найти причину в CSM (заодно это объяснит, почему часть истории v2 «пропала» — возможно, тот же фильтр).
- **Потеря Oct 15–19 в живой БД (п.6):** реально есть — 0 сессий против 165 по CSM; freelist 5595 → 353 → 48 страниц, то есть база была подчищена (VACUUM), и удалённые строки «съедены» — восстановить их из файла уже нельзя. **Сомнительно** — причина не установлена (миграция схемы v1→v2 с пересозданием таблиц — лучшая из версий: v1-таблицы `session`/`message`/`part` обрываются на 2026-10-15 22:10, `session_v2` начинается с 2026-10-09 и имеет дыру ровно с 15-го). **Требуется** — подтвердить или отвергнуть версию «миграция перезаписала таблицы»; сохранять per-session копию в отдельной БД.
- **Merged-red (п.7):** **Переоценка вверх.** Цикл 17 написал 27/19/56 — фактически 61/10/26 из 97. Причина — неполная выборка. **Требуется** — считать класс по полному скану и только раз в цикл; «зелёный PR» (#179/#180/#183/#187) не дал органики — продуктовая проверка в гейте по-прежнему нужна.
- **Диск (п.8):** реально есть — 4.0 GiB free (в снимках цикла 17 было 5.9–6.1 GiB), порог 5 GiB пробит, build skip случился дважды. **Требуется** — prune `~/.worktrees` (22 старых ворктри × ~1.3 GiB) **до** того, как цепочка начнёт скипать сборку; это дешёвое немедленное действие с измеримым эффектом.
- **Мёртвые флаги (п.9):** реально есть — 0 вхождений в бинаре; `release-current.md` и `run-selftest.sh` продолжают их рекламировать. **Требуется** — убрать из обеих инструкций; это дезориентирует и приёмку, и пользователя.
- **Приёмка (п.10):** **Частично подтверждена, и одно утверждение цикла 17 опровергнуто.** Зелёные прогоны есть (`2337`, `1107`, `1651`), `candidate == installed` держится (`1b3dc3065485`). **Опровергнуто:** «лосслесность подтверждена машинно (cmp/cksum/sha256)» — в `run-selftest.sh` **нет ни одного** `cmp`/`cksum`/`sha256`; `sha256` в `run-releaser.sh` относится к tar.gz релиза, а не к выводу. Лосслесность spilled-файла держится на одной строке `grep -q "big-output-line-2999"`. **Сомнительно** — check «needle retrieved» ищет константу `CM-5581-A` по всему файлу БД, где она встречается в 365 сессиях → зелёный статус не доказывает, что игла доехала в **этом** ответе; запасной путь поиска файла (стр. 207-209) сканирует всю БД и может взять файл чужого прогона. **Требуется** — скоупить needle по `session_id` текущего прогона; добавить отдельный check `candidate_sha == installed_sha`; проверять полноту файла сверкой с исходником (`cmp`/`wc -c`/хвост), а не наличием одной строки.
- **Байтовое усечение (п.11):** реально есть — первая строка окна режется пополам, границы в маркере не совпадают с фактическим содержимым. **Требуется** — правка окна по строкам в `packages/core/src/shell.ts` и печать фактических границ в маркере.
- **Деньги/намерения (п.12):** **Коррекция в обе стороны.** `cost` и `intent_signal`/`provider_cache_mark` мертвы — доказано. Но `memory-context.log` (7000 строк) показывает `compacted=1..90` и `first_delivery=true` в 6178 строках → **компактификация и first-delivery в v2 работают**, «фича мертва» читать нельзя; мёртвы только mask-mark и intent. **Требуется** — починить `cost` (или считать по `tokens_*` с прайсом) и `time_compacting`; `cosine_avg`/`acted%` либо порт, либо убрать из дайджеста.
- **Code Mode (п.13):** реально есть — 13 жёстких ошибок в 10 сессиях за 24ч; модель не знает ограничений песочницы. **Требуется** — перечислить доступные глобали/запреты в описании тула (или в ответе на ошибку), иначе каждая сессия с `execute` тратит ход на `ReferenceError`.
- **`question` (п.14):** реально есть — пользователь не видит вопрос, который модель задала. **Требуется** — отрисовать вопрос в TUI; сейчас виден только маркер «Asked 1 question».
- **Плагины (п.15):** реально есть, растёт (942). **Требуется** — валидатор путей в конфиге + прогон приёмки с включёнными плагинами, иначе измеряемая линия отличается от пользовательской.
- **Каскадные отказы (п.16):** реально есть — 435. Влияние на пользователя не измерено; сам счётчик — индикатор деградации окружения, а не фичи.
- **Трекер отказа (п.17):** реально есть — 6 failed / 5 withheld за 24ч, артефакты при этом есть. **Требуется** — разделить `exit` и `artifact_present`; вносить провалы в ITERATIONS/ISSUES.
- **User feedback (п.18):** **Коррекция цикла 17 — сигнала больше, чем думали.** 202 из 268 промптов реальные (цикл 17 насчитал 137 при другой выборке). **Новое:** CSM не видит последние 48 ч, поэтому окно добрано из живой БД, и там доминируют ZeroCreds/туннели (36), память/продолжение (49) и инструменты (81) — то есть тема памяти в реальном трафике заметно hotter, чем показывает CSM. **Требуется** — чинить индекс CSM по opencode, иначе каждое решение принимается по неполной картине.
- **«Ответ ≠ исходник» (п.19):** **Не воспроизводится, но и не проверяется.** Полное эхо 3000 строк было 2026-10-20 (`233804` — 3023 строки в ответе); двумя прогонами ранее ещё 1098–2130; за последние 4 прогона — 30–76 строк. То есть дефект не «починился», а **перестал воспроизводиться, потому что условие перестало возникать**: модель отвечает пересказом, и check'и этого не замечают. **Требуется** — либо машинная сверка ответа с исходником (доля исходных строк в ответе ≥ порога), либо ужесточение формулировки T1 и отдельный check «в ответе ≥ N строк исходника».
- **Хронология (п.20/21):** реально есть — `ITERATIONS.md` отстаёт (нет `1651`), локальный `ISSUES.md` (1 открытый) разошёлся с GitHub (17 открытых). **Требуется** — единый источник правды; сейчас решения принимаются по разным спискам.
- **Процессы на старом коде (п.22):** реально есть — `mem-architecture`/`mem-groomer` падают с −15, `mem-selftest` выгружен. Влияние не измерено; оставляю `needs_proof`.

---

## Приложение: как снимались метрики (воспроизводимо)

```bash
# Живая БД v2 — метрики сессий
sqlite3 ~/.local/share/opencode/opencode.db "
SELECT count(*) sessions, sum(tokens_input) tok_in, sum(tokens_output) tok_out,
       sum(tokens_reasoning) tok_reason, sum(tokens_cache_read) cache_r, sum(tokens_cache_write) cache_w,
       round(100.0*sum(tokens_cache_read)/nullif(sum(tokens_input)+sum(tokens_cache_read),0),1) hit_pct,
       round(sum(cost),4) cost
FROM session_v2 WHERE time_created > (strftime('%s','now')-86400)*1000;"

# Tool-вызовы и memory-тулы — v2-путь (session_message)
sqlite3 ~/.local/share/opencode/opencode.db "
SELECT j.value->>'name' tool, count(*) n
FROM session_message m, json_each(m.data,'\$.content') j
WHERE m.type='assistant' AND json_extract(j.value,'\$.type')='tool'
  AND m.time_created > (strftime('%s','now')-86400)*1000
GROUP BY 1 ORDER BY n DESC;"

# Усечения
sqlite3 ~/.local/share/opencode/opencode.db "
SELECT count(*) truncated, count(DISTINCT m.session_id) sessions
FROM session_message m, json_each(m.data,'\$.content') j
WHERE m.type='assistant' AND json_extract(j.value,'\$.type')='tool'
  AND json_extract(j.value,'\$.state.metadata.truncated') IN (1,'true')
  AND m.time_created > (strftime('%s','now')-86400)*1000;"

# Mem-record: кто писал и с каким authority
sqlite3 ~/.local/share/opencode/opencode.db "
SELECT recorded_by, authority, count(*) FROM mem_record GROUP BY 1,2;
SELECT count(DISTINCT project_id) projects, count(*) total FROM mem_record;"

# Intent / cache-mark / компактификация
sqlite3 ~/.local/share/opencode/opencode.db "
SELECT count(*) FROM intent_signal; SELECT count(*) FROM provider_cache_mark;
SELECT count(*) FROM session_v2 WHERE time_compacting IS NOT NULL;"

# Мёртвые флаги v2 — в бинаре их нет
strings -a ~/.opencode/bin/opencode | grep -c -E 'OPENCODE_CACHE_MASK|OPENCODE_CACHE_MARK_IDLE_MS|OPENCODE_MEMORY_INTENT|OPENCODE_MEMORY_CONTEXT'

# CSM: последняя проиндексированная opencode-сессия vs сканер
sqlite3 ~/code/claude-session-manager/data/sessions.db "
SELECT agent_type, count(*), max(created_at) FROM sessions
WHERE created_at > datetime('now','-7 days') GROUP BY 1;
SELECT max(last_scanned_at) FROM sessions;"

# Merged-red: полный скан слитых PR (GraphQL statusCheckRollup по head-коммиту)
gh api graphql -f query='query{repository(owner:"gpt-mem",name:"opencode-mem"){pullRequests(states:MERGED,first:100){nodes{number mergedAt commits(last:1){nodes{commit{statusCheckRollup{state contexts(first:50){nodes{__typename ... on CheckRun{name conclusion status} ... on StatusContext{state context}}}}}}}}}}}' \
  --jq '.data.repository.pullRequests.nodes | length'   # -> 97
```

Предписанный запуск (для сравнения) — `sqlite3 ~/.local/share/opencode/opencode-memory-context-v1.db < ~/.opencode/scripts/mem-metrics.sql` — даёт **пустое окно 24ч**; причина в п.4 и в разделе «Metrics digest».
