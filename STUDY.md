# STUDY research-20261023-1614

Метод: read-only. SQL по `~/.local/share/opencode/opencode.db` (`session_v2`/`session_message`) +
`mem-metrics-v2.sh` (канонический источник; предписанный `mem-metrics.sql` бьёт по мёртвой v1-базе,
см. п.12), CSM `sessions.db`/`issues.jsonl`/`reports/` (read-only), `chain-state.jsonl`,
`selftest-logs/`, `opencode.log`, git/gh по форку `gpt-mem/opencode-mem` и
`gpt-mem/opencode-mem-architecture`. Окно дайджеста — 24 ч, если не указано иное. Числа, помеченные
«≈», получены keyword-классификацией и приблизительны (методика в секции User feedback).

## Ranked by usefulness

1. **Root cause selftest-500 найден: `Layer @opencode/CacheMarkLedger is wired to different dependencies`** — `high` — STATUS: `proven` — кандидат `11455206b4` (собран из `main` после мержа #29) падает в рантайме; в `opencode.log` 18 вхождений ошибки за 10:00–12:57 (первое `2026-10-23T10:00:50Z`), `/api/location` → HTTP 500 ⇒ T1 не поднимается. PR **#208** (`fix-cache-mark-ledger-layer`, `9db2ce9a37`) чинит wiring, но **его CI красный** (`unit (linux)` fail, `verify (linux)` fail) ⇒ блокер не снят.
2. **CI форка красный 4 коммита подряд на `main`** — `high` — STATUS: `proven` — `gh run list --branch main`: `11455206b4`, `7038275716`, `3bc22d5100` → workflows `test` и `check` = **failure** (последний зелёный `test` — `0214663376`, 2026-10-22T17:57). `nix-eval`/`compliance-close` зелёные ⇒ падают unit/typecheck-джобы.
3. **TDZ в ранжировании памяти всё ещё на `main`** — `high` — STATUS: `proven` — `packages/core/src/session/mem-record-store.ts:248` читает `limit` до `const limit` (стр.250) → `ReferenceError: Cannot access 'limit' before initialization` на no-query/regex-ветке. PR #208 в описании обещает фикс, но он не влит; рабочие ветки `fix-mem-search-regression` (`08b418b2d6`) содержат фикс. Прямое следствие — красный `test`.
4. **Приёмка фиктивна: «ответ модели ≠ исходник», харнесс сверяет только маркер** — `high` — STATUS: `proven` — `run-selftest.sh:190` печатает `=== SELFTEST … DONE ===` **до** проверок `:209`/`:217`/`:223`; needle ищется `strings` по файлу сессии+WAL (`:223`), а не по ответу модели (#195/#197 открыты). Т.е. 5/5 `ok` достижимы без чтения ответа.
5. **Selftest не устойчив к инфра-сбою: один `500` обнуляет прогон** — `high` — STATUS: `proven` — серия 23.10: `031138`/`032210`/`051357`/`060854`/`071528`/`084308` зелёные (T1–T5 exit=0) → `091649` все ходы `every rung failed` → `112556` прерван (verify-клон ≠ кандидат) → `130047`/`132557`/`133453`/`152618`/`154310` **5 прогонов подряд** `T1 exit=1 UnexpectedStatus: 500` + `session: NOT-BOUND … оставшиеся ходы пропущены`; chain `20261023-1300` и `20261023-1543` `selftest exit=70` (23–24 s против 89–566 s зелёных).
6. **Окно доставки 2 KiB режет аргументы `put_in_operational_memory`** — `high` — STATUS: `proven` — truncation-маркеры `showing lines` = **2786 за 24 ч / 8396 за 7 д** (не убывает); корень двухконтурный (`MAX_BYTES`+байтовый курсор против маркера по строкам).
7. **Деньги и intent мертвы — детекторы не пишут** — `high` — STATUS: `proven` — `cost`=0 во всём 24 ч окне (и 7 д); последняя сессия с `cost>0` — `2026-10-12 07:51`; `intent_signal`=0, `provider_cache_mark`=0, `intent`=0 в основной БД ⇒ `cosine_avg`/`acted%` недривятся.
8. **CSM-сканер стоит, канал feedback мёртв** — `high` — STATUS: `proven` — `max(last_scanned_at)`=`2026-10-21T11:43:24Z`, последняя сессия в CSM `2026-10-21T07:27`; таблица `issues`=0 строк, `issues.jsonl`=1 строка (2026-03-14), `reports/`=12 файлов от 09.10, `analyzer-state.json.last_run`=`2026-04-02` ⇒ ни жалоб, ни feature request через CSM не поступает (свежие сигналы сняты вручную из `opencode.db`, см. User feedback).
9. **Ошибки Code Mode вне `state.error` — занижение** — `high` — STATUS: `proven` — `execute` 182 вызова / 1 структурная ошибка в 24 ч, но **199** assistant-сообщений с `Unknown identifier`; `No tool named` = **225** за 24 ч.
10. **«No tool named» — модель выдумывает имена тулов** — `high` — STATUS: `proven` — 225 вхождений за 24 ч; структурных ошибок `edit` 104 / `read` 50 / `list_mcp_resources` 22 / `grep` 12.
11. **V2-флаги не существуют, релиз-ноты их рекламируют** — `high` — STATUS: `proven` — `strings` по установленному бинарю **и всем 9 кандидатам**: `OPENCODE_MEMORY_{CONTEXT,CACHE_MARK,FIRST_DELIVERY}` = 0; при этом `release-current.md:17` под заголовком «Флаги v2» перечисляет `OPENCODE_MEMORY_CONTEXT=1`. Частично закрыто (v1-реликт-флаги убраны), issue `#191` открыт.
12. **`mem-metrics.sql` (#190) мёртв для v2; рабочий wrapper уже есть** — `high` — STATUS: `proven` — предписанный скрипт бьёт по `opencode-memory-context-v1.db` (заморожена `2026-10-12 14:34`; 24 ч окно пусто: `get_tool_call_details` calls_24h=0); `mem-metrics-v2.sh` корректно читает `session_v2`+`session_message` и все канальные `opencode*.db`. Дайджест снят wrapper'ом.
13. **Disk здоров, prune-шаг в цепочке** — `high` — STATUS: `proven` — `/` **24 GiB свободно (33 % занято)**; `~/.worktrees` = **0 B / 0 ворктри**; `chain-state.jsonl` пишет `step:"prune"` + `prune-detail` (`freed_kb:0`, `mode:apply`). Дефект закрыт.
14. **`get_tool_call_details` 1376/24 ч — но 1365 из scheduled-сессий** — `high` — STATUS: `proven` — почти весь объём даёт `scheduled-iteration` (1365); органические сессии — 11 вызовов суммарно ⇒ «доля memory-тулов 16.9 %» — артефакт автоматического цикла, а не пользовательского спроса.
15. **`read`-тул: описание приведено в соответствие (issue #198 всё ещё открыт)** — `medium` — STATUS: `proven` — `packages/core/src/tool/plugin/read.ts:23` теперь пишет «defaults to 2000, capped by MAX_READ_BYTES = 50 KiB ≈ 624 lines»; расхождение устранено в коде, но `#198` не закрыт.
16. **SHA расходится: бинарь и кандидат разошлись** — `medium` — STATUS: `proven` — установлен `opencode v0.0.0-fork-at-021466337676`; свежайший кандидат `11455206b4b0`; `selftest-last.json.sha12`=`021466337676`; `130047`–`154310` проверяли кандидата `11455206b4b0` против установленного `021466337676` ⇒ «SHA immutable пять циклов» не держится, а кандидат вообще не поднимается (п.1).
17. **`mem_record`: запись идёт, дублей нет** — `medium` — STATUS: `proven` — **272** всего / 247 active / 25 superseded, 15 проектов, 29 новых за 24 ч; типы decision 120 / constraint 83 / failed_approach 46 / user_signal 23; authority agent 161 / user 111; пустой scope 91/272.
18. **Компакция есть, но не измеряется** — `medium` — STATUS: `proven` — `compaction` сообщений 12 (24 ч) / 158 (7 д); `time_compacting IS NOT NULL` = 0 из 1075 сессий 7 д ⇒ §8 `mem-metrics.sql` не различает compacted/full.
19. **Валидация кросс-проектной памяти вводит в заблуждение** — `medium` — STATUS: `proven` — `get_operational_memory` по id из другого проекта отдаёт `found:false, "No memory … in this project"`, хотя запись активна ⇒ лишний поиск. Код-путь в этом цикле не менялся.
20. **Форк-плагины не грузятся: большинство WARN** — `medium` — STATUS: `proven` — `configured plugin path must be a directory` = **1435** из `opencode.log` (лог охватывает 10-21…10-23). Счётчики **не сравнимы** между циклами: лог компактится in-place (`logging.ts`), сейчас 43.5 MiB и 76 999 строк.
21. **`question`-тул не показывает вопрос** — `medium` — STATUS: `proven` — 4 вызова за 24 ч; жалоба пользователя ровно одна («→Asked 1 question - а где вопрос не вижу?», 21.10).
22. **Саморевью не ревьюит код форка** — `medium` — STATUS: `proven` — self-review сессии заявляют «правок не вносил, рабочее дерево не менял»; отдельно `scheduled-iteration` делает ~1365 вызовов retrieval-тула без правок.
23. **`ITERATIONS.md` отстаёт** — `medium` — STATUS: `proven` — записи от 2026-10-23 есть по #15/#29/#194/#191, но нет ни серии 5×500 (`132557`/`133453`/`152618`/`154310`), ни chain `1543`, ни диагноза CacheMarkLedger; последняя запись — «Цикл 23 (dogfood selftest)».
24. **Открытые issues форка: 23; открытых PR — 1** — `medium` — STATUS: `proven` — среди issues P0 `#190` (метрики v1), `#202` (unified mask только на мёртвой v1), `#195`/`#197` (приёмка/needle), `#191` (флаги), `#198` (read), `#207` (порт v2.1.3); единственный PR — `#208` (CI красный).
25. **NL-поиск: regex приоритетен, морфологии нет, fallback по OR** — `medium` — STATUS: `doubtful` — код `mem-record-store.ts:236-243` сохранён, но проверить семантику вживую нельзя: search-путь падает с TDZ (п.3) на no-query/regex-ветках ⇒ эмпирика загрязнена.
26. **«`<tool_call>` в строке данных»** — `low` — STATUS: `doubtful` — наблюдение `065732` не воспроизведено; механизм не установлен.
27. **API-key/baseURL в логах `0644`** — `low` — STATUS: `doubtful` — в свежих логах не найдено; `selftest-logs/` по-прежнему world-readable, риск не снят.
28. **Долгоживущие процессы на старом коде** — `low` — STATUS: `needs_proof` — `opencode serve` и фоновые процессы крутятся из старых dist; влияние на пользователя не измерено.
29. **Cross-memory resume — единственный реальный апгрейд, но тонкий** — `low` — STATUS: `doubtful` — новых независимых наблюдений нет; прошлые (090453, 111142) сделаны в self-review агентских сессиях, не в пользовательских ad-hoc, и эффект перекрывается дефектом длины (п.4/п.6) ⇒ «память помогла» не отделено от «память перефразировала прошлое знание».

---

## Metrics digest (24h)

- **Sessions: 203** (scheduled 145, ad-hoc 31, chain 27), **Total tokens: in 147,557,548 / out 950,778** (reasoning ≈687 K), **Cache read: 299,990,508 (67.0 %**, cache_write 0**)**, **Cost: $0.00** (детектор мёртв; последний `cost>0` — 2026-10-12)
- **Memory tools: overview=0, find_tool_calls=0, detail=get_tool_call_details 1376** (1365 из них — `scheduled-iteration`), **search_operational_memory=3, put_in_operational_memory=13, get_operational_memory=0** ⇒ органическая доля ≈ 27 вызовов/24 ч; «доля memory-тулов 16.9 %» — артефакт scheduled-цикла
- **Intent signals: cosine_avg=н/д, acted%=н/д** (`intent_signal`=0 строк)
- Memory records: 272 всего / 247 active / 25 superseded, 15 проектов, 29 новых за 24 ч; типы decision 120 / constraint 83 / failed_approach 46 / user_signal 23; authority agent 161 / user 111; пустой scope 91
- Compaction: 12 сообщений (24 ч), 158 (7 д), 0 сессий с `time_compacting` из 1075 (7 д)
- Truncation-маркеры `showing lines`: 2786 (24 ч), 8396 (7 д)
- Tool errors (`state.status='error'`, 24 ч): edit 104, read 50, list_mcp_resources 22, grep 12, shell 6, write 4, get_tool_call_details 4, bash 4, search 3, question 3, webfetch 2, execute 1; `No tool named` 225, `Unknown identifier` 199
- Runtime errors (`opencode.log`): `Layer @opencode/CacheMarkLedger is wired to different dependencies` = **18** (10:00–12:57) — корень selftest-500
- Chain (`chain-state.jsonl`, 23.10): `0842` prune→build ok→**selftest ok(89 s)**→release ok→bug-reporter/researcher/architect failed; `1055` **build exit=70**; `1300` build ok→**selftest exit=70 failed(23 s)**→release withheld→architect failed; `1543` build ok(7 s)→**selftest exit=70 failed(24 s)**→release withheld→bug-reporter failed
- Selftest logs: 88 `.log`; 23.10 серия зелёная (`084308` и ранее)→`091649` rung-fail→`112556` прерван→**5×`500`/NOT-BOUND** (`130047`–`154310`)
- Disk: `/` 24 GiB свободно (33 % занято); `~/.worktrees` 0 B / 0 ворктри (prune работает)
- GitHub: `gpt-mem/opencode-mem` **23 open issues / 1 open PR (#208, CI красный)**; `main` CI `test`+`check` красные на 3 последних коммитах; `gpt-mem/opencode-mem-architecture` 1 open issue; docs-репо HEAD == origin/main
- CSM: 795 сессий (opencode 721 / codex 74), `last_scanned_at` `2026-10-21T11:43:24Z`; `issues`=0, `issues.jsonl`=1 (2026-03-14), `reports/` от 09.10

## User feedback top

Методика: primary — CSM `sessions.db` (795 сессий, `first_prompt`+`summary`+`generated_title`, keyword-классификация,
категории пересекаются); secondary — user-промпты `opencode.db` за 3 суток (369 «человеческих» промптов после
отсева automation/selftest/subagent). CSM **стоит с 21.10** ⇒ свежесть ограничена, свежие сигналы сняты вручную из `opencode.db`.

1. **CI / тесты / flaky** — ≈192 CSM-сессий — severity=high — «почини ошибки в тестах чтобы pr прошёл», «e2e не зашавершился», «разбор падения unit в PR #165»
2. **Форк / память / приёмка** — ≈169 CSM — severity=high — «fix this bug …/issues/119», «разобраться почему CI стал», «детекшн loop часто ловит ложные детекты …/pull/145»
3. **Тулы / MCP / Code Mode сломаны** — ≈168 CSM — severity=high — «у неё нет доступа ни к каким тулам», «execute ↳ ReferenceError: Unknown identifier 'require'»
4. **trained-assist / Ladder runtime (соседний продукт)** — ≈132 CSM — severity=medium — «какой именно opencode запускает trained-assist в проде»
5. **Провайдер / каталог моделей / Ladder** — ≈115 CSM — severity=high — «invalid ladder_cache_variant», «Zen worker capacity unavailable», «21 модель ушла из инвентаря»
6. **Sandbox / provisioning** — ≈112 CSM — severity=medium — «Sandbox provisioning выключен — нужно включать»
7. **Агент завис / упал / пустой ответ** — ≈89 CSM — severity=high — «он ничего не отвечает», «упал агент», «agent exited non-zero»
8. **Стоимость / инстансы** — ≈57 CSM — severity=low — «инстанс 24/7 ≈ $0.47/мес — один на все задачи?»
9. **GH-токены / права / merge** — ≈33 CSM — severity=medium — «мой gh-токен без права merge», «merge не проходит — нужен admin-токен»
10. **ZeroCreds / tunnel / шаринг** — ≈21 CSM — severity=medium — «кодекс не может с zerocreds работать», «хочу поделиться кредами с коллегой» (повторяется ≥5 раз)
11. **Ответ неверен / расхождение** — ≈10 CSM — severity=high — «не то что просил», «какой клаудфларе не валиден?»
12. **`question`-тул не показывает вопрос** — 1 — severity=medium — «→Asked 1 question - а где вопрос не вижу?» (21.10)

**Свежие реальные сигналы из `opencode.db` (22–23.10, не в CSM — сканер стоит):**
- **MCP/engineering skills отвалились** (22.10 12:17, «Сбой подключения MCP и engineering skills») — «вчера всё коннектилось … а сегодня всё сломалось, всё отвалилось» — severity=high
- **Потерянные/невидимые сессии + worktree-location** (22.10 12:16 «Восстановление потерянных сессий», 23.10 12:22 «Ошибка переключения сессий») — «куча сессий оборвалась … в session manager не отображаются», `Failed to switch model: Location not found: ~/.worktrees/...` — severity=high
- **Автоапдейт перезаписал форк** (21.10 17:49 «Фикс OpenCode session location unavailable») — `△Session location unavailable … ничего не выбирается`, «это автоапдейт который перезаписал мой форк опенкода?» — severity=high
- **`ladder/standard is not available in this session's location`** (22.10 16:14–16:20, 4 сессии) — severity=medium
- **Зен-кольца мертвы** (22.10 18:34) — «Zen worker capacity unavailable — раннеров нет» — severity=medium
- **Админка LLM-ladder** (21.10 17:28) — «Cannot read properties of null (reading 'reset')», OR free-лимит 922/1000 — severity=low

- **Что бьёт по форку vs проходит мимо:** #1, #2, #3, #7, #11, #12 + свежие MCP/sessions/auto-update — про форк и его приёмку; #4, #5, #6, #8, #9, #10 — про соседние продукты (Ladder / ZeroCreds / Cloudflare / sandbox / CSM).
- **Сдвиг:** спрос на память как пользовательскую функцию по-прежнему близок к нулю; максимальный спрос — приёмка/CI и работоспособность окружения (MCP, сессии, worktrees).

## Judge comments

- **P.1 (CacheMarkLedger 500) — новый главный факт цикла** — **Реально есть:** 18 рантайм-ошибок `Layer @opencode/CacheMarkLedger is wired to different dependencies` (`opencode.log`, 10:00–12:57); кандидат `11455206b4` не поднимается, `/api/location` → 500; PR #208 диагностирует и чинит. **Сомнительно:** сам фикс не проверен — CI PR #208 красный (`unit (linux)`/`verify (linux)` fail). **Требуется:** починить CI PR #208 (или переоткрыть `#29`-регресс), довести до зелёного, влить, пересобрать кандидата и прогнать selftest.
- **P.2 (CI main) — красный 4 коммита** — **Реально есть:** `test`+`check` failure на `11455206b4`/`7038275716`/`3bc22d5100`. **Требуется:** тот же фикс (P.1 + P.3) → зелёный `main`.
- **P.3 (TDZ) — на `main` всё ещё сломан** — **Реально есть:** `mem-record-store.ts:248` использует `limit` до объявления на `:250`; `#194` закрыт преждевременно. **Требуется:** влить фикс (ветка `fix-mem-search-regression`), регресс-тест на «superseded не возвращается», переоткрыть `#194` до зелёного.
- **P.4–P.6 (фиктивная приёмка, 2 KiB, устойчивость) — структура неизменна** — **Реально есть:** `DONE` печатается на `:190` до проверок `:209`/`:217`/`:223`; needle ищется в файле сессии, не в ответе; truncation-маркеры 2786/24 ч; 5×`500`+NOT-BOUND. **Требуется:** машинная сверка ответа T1 с исходником (`sha256`/`cmp`), перенос `DONE` после проверок, retry/backoff на `500` или пометка `inconclusive`, запись candidate/installed SHA в chain-state.
- **P.7 (деньги/intent) — без изменений** — **Реально есть:** `cost`=0, `intent_signal`/`provider_cache_mark`/`intent`=0. **Требуется:** починить или убрать из дайджеста как источник шума.
- **P.8 (CSM) — мёртв** — **Реально есть:** `last_scanned_at` 21.10, `issues`=0, `reports/` от 09.10, `analyzer-state.last_run` 2026-04-02. **Требуется:** watchdog на `last_scanned_at` старше 2 ч; иначе секция User feedback деградирует в ручной разбор `opencode.db`.
- **P.9–P.10 (Code Mode, «No tool named») — занижение подтверждено** — **Реально есть:** 182 `execute` / 1 структурная ошибка, но 199 `Unknown identifier`; `No tool named` 225. **Требуется:** складывать sandbox-ошибки в `state.error` и/или отдельный счётчик.
- **P.11 (флаги v2, #191) — 5-й цикл** — **Реально есть:** 0 совпадений во всех бинарях; `release-current.md:17` всё ещё рекламирует `OPENCODE_MEMORY_CONTEXT=1` под «Флаги v2». **Требуется:** либо реализовать флаг, либо убрать строку из релиз-нот (issue `#191`).
- **P.12 (метрики #190) — рабочий обход есть** — **Реально есть:** `mem-metrics-v2.sh` даёт полный дайджест; предписанный `mem-metrics.sql` — пустой. **Требуется:** обновить промпт исследователя на v2-wrapper (issue `#190`).
- **P.15 (read-тул, #198) — исправлено в коде, issue открыт** — **Реально есть:** `plugin/read.ts:23` указывает реальный потолок (`50 KiB ≈ 624 строки`). **Требуется:** закрыть `#198`.
- **P.13 (prune) — закрыт** — **Реально есть:** `prune` в `run-mem-chain.sh`, `~/.worktrees` пуст, `/` 24 GiB. **Требуется:** следить за регрессом.
- **Свежий user-сигнал (MCP/сессии/auto-update)** — **Реально есть:** пользователь 22–23.10 сообщает об отвале MCP-серверов, потерянных/невидимых сессиях, `Location not found` по worktree и о том, что автоапдейт перезаписал форк. **Сомнительно:** относится ли это к форку `opencode-mem` или к session-manager/окружению. **Требуется:** завести issues и разграничить (форк vs CSM/окружение).

## Next research priorities

1. **Довести PR #208 до зелёного CI и влить** — снять 500 (P.1), TDZ (P.3) и красный `main` (P.2) разом; затем пересобрать кандидата и прогнать selftest.
2. **Устойчивость selftest к инфра-сбою** — retry/backoff на `UnexpectedStatus: 500` + разделение инфра/продуктового вердикта + candidate/installed SHA в chain-state.
3. **Машинная сверка ответа T1 с исходником** (`sha256`/`cmp`) + перенос `DONE` после проверок (#195/#197).
4. **Watchdog на CSM-сканер** (`last_scanned_at` старше 2 ч) — иначе feedback-канал слеп.
5. **Завести issues по свежим user-сигналам** (MCP отвал, потерянные сессии/worktree location, автоапдейт поверх форка) и разграничить форк vs окружение.
6. **Починить/выключить детекторы `cost` и `intent_signal`** — сейчас дайджест по ним пуст.
7. **Сложить ошибки Code Mode в `state.error`** — убрать занижение.
8. **Обновить промпт исследователя на `mem-metrics-v2.sh`** (#190) и убрать/реализовать v2-флаги в релиз-нотах (#191).
9. **`ITERATIONS.md`** — дописать серию 5×500, chain `1543` и диагноз CacheMarkLedger.
10. **Закрыть `#198`** (read-тул) — фактически исправлено.

---

Коммит change: git add STUDY.md && commit -m "research: research-20261023-1614" && push
