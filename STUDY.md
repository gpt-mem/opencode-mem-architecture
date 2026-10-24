# STUDY research-20261024-0230

Метод: read-only. SQL по `~/.local/share/opencode/opencode.db` (`session_v2`/`session_message`) +
`mem-metrics-v2.sh` (канонический источник; `mem-metrics.sql` бьёт по мёртвой v1-базе),
CSM `sessions.db`/`issues.jsonl`/`reports/` (read-only), `chain-state.jsonl`,
`selftest-logs/`, `opencode.log`, git/gh по форку `gpt-mem/opencode-mem` и
`gpt-mem/opencode-mem-architecture`. Окно дайджеста — 24 ч, если не указано иное. Числа, помеченные
«≈», получены keyword-классификацией и приблизительны (методика в секции User feedback).

## Ranked by usefulness

1. **CI форка красный 4+ коммита подряд на `main` — теперь 9 failing jobs** — `high` — STATUS: `proven` — `gh run list --branch main`: head `f62df808f332` → 36 check-runs, 13 success, 14 skipped, **9 failure** (`typecheck`, `unit (linux)`, `unit (linux, shard 1/4)`, `unit (windows, shard 2/4)`, `unit (windows, shard 4/4)`, `verify (linux)`, `build (linux)`, `build (linux, service)`). Корень: TS2719 в `packages/core/src/session/runner/llm.ts:403` — duplicate branded `SessionID`/`Continuation`/`RunError` types, введённые коммитом 57bfddbe69 (wiring CacheMarkLedger).
2. **Root cause selftest-500 найден и пофикшен (PR #208 merged), но CI `main` сломан** — `high` — STATUS: `proven` — 18 рантайм-ошибок `Layer @opencode/CacheMarkLedger is wired to different dependencies` (`opencode.log`, 23.10 10:00–12:57); PR #208 (`9db2ce9a37`) чинит wiring, замержен 23.10 13:24; selftest зелёный `2343`/`0213`; candidate=installed=`f62df808f332`. **Сомнительно:** CI `main` теперь красный из-за typecheck-регресса того же фикса.
3. **V2-флаги существуют, но release-notes их не документирует** — `high` — STATUS: `proven` — бинарь `f62df808f332` содержит `OPENCODE_V2_MEMORY_CONTEXT`, `OPENCODE_V2_MEMORY_MIN_CHARS`, `OPENCODE_V2_MEMORY_TOOLS`, `OPENCODE_V2_MEMORY_CONTEXT_DEBUG`; release-current.md секция «Флаги v2» имеет пустые имена (`-  — включить...`), `grep -c OPENCODE_MEMORY` = 0; генератор `run-releaser.sh` пишет неверные имена `OPENCODE_V2_MEMORY_CONTEXT_MIN_CHARS`/`_TOOLS` (лишний `CONTEXT`).
4. **TDZ в ранжировании памяти пофикшен на `main`** — `high` — STATUS: `proven` — `mem-record-store.ts:245` `const limit = ...`, используется на 249/258 — раннего чтения нет; PR #208/memory-context-v1 влит.
5. **Приёмка фиктивна: «ответ модели ≠ исходник», DONE печатается ДО проверок** — `high` — STATUS: `proven` — `run-selftest.sh:190` печатает `=== SELFTEST … DONE ===` до проверок `:209`/`:217`/`:223`; needle ищется `strings` по файлу сессии+WAL, а не по ответу модели; флаг памяти выключен (`OPENCODE_V2_MEMORY_CONTEXT` не задан в selftest/chain) → память не тестируется.
6. **Selftest не устойчив к инфра-сбою: один `500` обнуляет прогон** — `high` — STATUS: `proven` — серия 23.10: зелёные → `091649` `every rung failed` → `112556` прерван → `130047`/`152618`/`154310` 5×`500`+NOT-BOUND; `2343`/`0213` зелёные после мерджа #208. Retry/backoff на `UnexpectedStatus: 500` и разделение инфра/продуктового вердикта — нет.
7. **Окно доставки 2 KiB режет аргументы `put_in_operational_memory`** — `high` — STATUS: `proven` — truncation-маркеры `showing lines` = **3162 за 24 ч / 9454 за 7 д** (не убывает); корень двухконтурный (`MAX_BYTES`+байтовый курсор против маркера по строкам).
8. **Деньги и intent мертвы — детекторы не пишут** — `high` — STATUS: `proven` — `cost`=0 во всём 24ч окне (и 7 д); последняя сессия с `cost>0` — 2026-10-12; `intent_signal`=0 строк в v2-БД ⇒ `cosine_avg`/`acted%` недривятся.
9. **CSM-сканер стоит, канал feedback мёртв** — `high` — STATUS: `proven` — `max(last_scanned_at)`=`2026-10-21T11:43:24Z`, последняя сессия в CSM 21.10 07:27; таблица `issues`=0, `issues.jsonl`=1 строка (2026-03-14), `reports/`=12 файлов от 09.10, `analyzer-state.json.last_run`=`2026-04-02`.
10. **«No tool named» — схема тулов рекламирует `tools.opencode.list_mcp_resources`, рантайм отвергает** — `high` — STATUS: `proven` — 421 сообщения с `No tool named` за 24 ч, из них **320** — `tools.opencode.list_mcp_resources`; схема (system message) содержит `tools.opencode.list_mcp_resources({...})`, модель вызывает так → ошибка; 359/421 — в `scheduled-iteration`.
11. **Ошибки Code Mode вне `state.error` — занижение подтверждено** — `high` — STATUS: `proven` — `execute` 124 вызова / 1 структурная ошибка в 24 ч, но **71** assistant-сообщений с `Unknown identifier`; `No tool named` = **421** (см. п.10).
12. **mem-metrics.sql (#190) мёртв для v2; рабочий wrapper есть** — `high` — STATUS: `proven` — предписанный скрипт бьёт по `opencode-memory-context-v1.db` (заморожена 2026-10-12; 24 ч окно пусто); `mem-metrics-v2.sh` корректно читает `session_v2`+`session_message` и все канальные `opencode*.db`.
13. **Disk здоров, prune-шаг в цепочке работает** — `high` — STATUS: `proven` — `/` **44 GiB свободно (22 % занято)**; `~/.worktrees` = **0 B / 0 ворктри**; `chain-state.jsonl` пишет `step:"prune"` + `prune-detail` (`freed_kb:0`, `mode:apply`).
14. **`mem_record`: запись идёт, дублей нет, но органики мало** — `medium` — STATUS: `proven` — **272** всего / 247 active / 25 superseded, 15 проектов, **4** новых за 24 ч; типы decision 120 / constraint 83 / failed_approach 46 / user_signal 23; authority agent 161 / user 111; пустой scope 91/272.
15. **Компакция есть, но не измеряется (`time_compacting` всегда NULL)** — `medium` — STATUS: `proven` — `compaction` сообщений 5 (24 ч) / 159 (7 д); `time_compacting IS NOT NULL` = 0 из 1146 сессий 7 д ⇒ §8 `mem-metrics.sql` не различает compacted/full.
16. **Валидация кросс-проектной памяти вводит в заблуждение** — `medium` — STATUS: `proven` — `get_operational_memory` по id из другого проекта отдаёт `found:false, "No memory … in this project"`, хотя запись активна ⇒ лишний поиск.
17. **Форк-плагины не грузятся: большинство WARN** — `medium` — STATUS: `proven` — `configured plugin path must be a directory` = **1725** из `opencode.log` (лог охватывает 21-24.10); счётчики **не сравнимы** между циклами: лог компактится in-place, сейчас 49.5 MiB / 92k строк.
18. **`question`-тул не показывает вопрос** — `medium` — STATUS: `proven` — 4 вызова за 24 ч (1 error); жалоба пользователя ровно одна («→Asked 1 question - а где вопрос не вижу?», 21.10).
19. **Саморевью не ревьюит код форка** — `medium` — STATUS: `proven` — self-review сессии заявляют «правок не вносил, рабочее дерево не менял»; отдельно `scheduled-iteration` делает ~1842 вызова retrieval-тула без правок.
20. **`ITERATIONS.md` отстаёт** — `medium` — STATUS: `proven` — записи от 23.10 есть по #15/#29/#194/#191, но нет серии 5×500 (`132557`/`133453`/`152618`/`154310`), chain `2343`/`0213`, диагноза CacheMarkLedger, регресса typecheck; последняя запись — «Эпик #202: Шаги 1–4 в main».
21. **Открытые issues форка: 23; открытых PR — 0** — `medium` — STATUS: `proven` — P0: #202 (unified mask только на мёртвой v1), #190 (метрики v1), #195/#197 (приёмка/needle), #191 (флаги — частично устранено, но release-notes сломаны), #198 (read), #207 (порт v2.1.3); PR #208 замержен, но внёс typecheck-регресс.
22. **NL-поиск: regex приоритетен, морфологии нет, fallback по OR** — `medium` — STATUS: `doubtful` — код `mem-record-store.ts:236-243` сохранён, но проверить семантику вживу нельзя: selftest не включает флаг памяти ⇒ эмпирика загрязнена; статус `active` фильтр в query не работает (superseded в выдаче).
23. **«`<tool_call>` в строке данных»** — `low` — STATUS: `doubtful` — наблюдение `065732` не воспроизведено; механизм не установлен.
24. **API-key/baseURL в логах `0644`** — `low` — STATUS: `doubtful` — в свежих логах не найдено; `selftest-logs/` по-прежнему world-readable, риск не снят.
25. **Долгоживущие процессы на старом коде** — `low` — STATUS: `needs_proof` — `opencode serve` и фоновые процессы крутятся из старых dist; влияние на пользователя не измерено.
26. **Cross-memory resume — единственный реальный апгрейд, но тонкий** — `low` — STATUS: `doubtful` — новых независимых наблюдений нет; прошлые (090453, 111142) сделаны в self-review агентских сессиях, не в пользовательских ad-hoc, и эффект перекрывается дефектом длины (п.4/п.7) ⇒ «память помогла» не отделено от «память перефразировала прошлое знание».

---

## Metrics digest (24h)

- **Sessions: 151** (scheduled 102, chain 29, ad-hoc 20), **Total tokens: in 104,258,599 / out 1,066,155** (reasoning ≈240,080), **Cache read: 327,953,674 (75.9 %)**, cache_write 0, **Cost: $0.00** (детектор мёртв; последний `cost>0` — 2026-10-12)
- **Memory tools: overview=0, find_tool_calls=0, get_tool_call_details=1845** (1842 из них — `scheduled-iteration`), **search_operational_memory=2, put_in_operational_memory=2, get_operational_memory=0** ⇒ органическая доля ≈ 7 вызовов/24 ч; «доля memory-тулов 16.9 %» — артефакт scheduled-цикла
- **Intent signals: cosine_avg=н/д, acted%=н/д** (`intent_signal`=0 строк)
- Memory records: 272 всего / 247 active / 25 superseded, 15 проектов, 4 новых за 24 ч; типы decision 120 / constraint 83 / failed_approach 46 / user_signal 23; authority agent 161 / user 111; пустой scope 91
- Compaction: 5 сообщений (24 ч), 159 (7 д), 0 сессий с `time_compacting` из 1146 (7 д)
- Truncation-маркеры `showing lines`: 3162 (24 ч), 9454 (7 д)
- Tool errors (`state.status='error'`, 24 ч): edit 81, read 33, grep 12, list_mcp_resources 320 (+ variants 15), shell 2, write 3, get_tool_call_details 2, execute 1, webfetch 1, search 5, question 1; `No tool named` 421, `Unknown identifier` 71
- Runtime errors (`opencode.log`): `Layer @opencode/CacheMarkLedger is wired to different dependencies` = **13** (23.10 10:00–12:57) — корень selftest-500, **после 23.10 12:57 — 0**
- Chain (`chain-state.jsonl`, 23-24.10): `2343` prune→build ok→**selftest ok(327 s)**→release ok→bug-reporter/researcher/architect failed; `0213` prune→build ok→**selftest ok(361 s)**→release ok→bug-reporter ok→researcher/architect pending
- Selftest logs (серия 23-24.10): `164511` 0F DONE → `172641` 1F DONE → `183352` 3F DONE → `193612` 1F DONE → `205059` 3F NO-DONE → `214529` 1F NO-DONE → `234346` 0F DONE → `020107` 0F DONE → `021315` 0F DONE (gtd=1)
- Disk: `/` 44 GiB свободно (22 % занято); `~/.worktrees` 0 B / 0 ворктри; stale checkout `/Users/vova/code/opencode-mem-verify` (f62df808f3) загрязняет локальный typecheck
- GitHub: `gpt-mem/opencode-mem` **23 open issues / 0 open PR** (PR #208 merged 23.10 13:24); `main` CI **9 failure**; `gpt-mem/opencode-mem-architecture` 1 open issue; docs-репо HEAD == origin/main
- CSM: 795 сессий (opencode 721 / codex 74), `last_scanned_at` `2026-10-21T11:43:24Z`; `issues`=0, `issues.jsonl`=1 (2026-03-14), `reports/` от 09.10

---

## User feedback top

Методика: primary — CSM `sessions.db` (795 сессий, `first_prompt`+`summary`+`generated_title`, keyword-классификация, категории пересекаются); secondary — user-промпты `opencode.db` за 3 суток (369 «человеческих» промптов после отсева automation/selftest/subagent). CSM **стоит с 21.10** ⇒ свежесть ограничена, свежие сигналы сняты вручную из `opencode.db`.

### CSM keyword hits (approx, overlapping)

1. **session-manager/sessions** — 259 — severity=high — «куча сессий оборвалась … в session manager не отображаются», `Failed to switch model: Location not found: ~/.worktrees/...`
2. **CI / тесты / flaky** — 246 — severity=high — «почини ошибки в тестах чтобы pr прошёл», «e2e не зашавершился», «разбор падения unit в PR #165»
3. **Тулы / MCP / Code Mode сломаны** — 246 — severity=high — «у неё нет доступа ни к каким тулам», «execute ↳ ReferenceError: Unknown identifier 'require'»
4. **Форк / память / приёмка** — 173 — severity=high — «fix this bug …/issues/119», «разобраться почему CI стал», «детекшн loop часто ловит ложные детекты …/pull/145»
5. **GH-токены / права / merge** — 159 — severity=medium — «мой gh-токен без права merge», «merge не проходит — нужен admin-токен»
6. **Стоимость / инстансы** — 117 — severity=low — «инстанс 24/7 ≈ $0.47/мес — один на все задачи?»
7. **Sandbox / provisioning** — 111 — severity=medium — «Sandbox provisioning выключен — нужно включать»
8. **Агент завис / упал / пустой ответ** — 99 — severity=high — «он ничего не отвечает», «упал агент», «agent exited non-zero»
9. **Провайдер / каталог моделей / Ladder** — 91 — severity=high — «invalid ladder_cache_variant», «Zen worker capacity unavailable», «21 модель ушла из инвентаря»
10. **ZeroCreds / tunnel / шаринг** — 36 — severity=medium — «кодекс не может с zerocreds работать», «хочу поделиться кредами с коллегой» (повторяется ≥5 раз)
11. **Ответ неверен / расхождение** — 18 — severity=high — «не то что просил», «какой клаудфларе не валиден?»

### Свежие реальные сигналы из `opencode.db` (22–24.10, не в CSM — сканер стоит):

- **Failed to switch model: Location not found** — worktree-путь не найден (23.10 12:22) — severity=high
- **MCP/engineering skills отвалились** — «вчера всё коннектилось … а сегодня всё сломалось» (22.10 12:17) — severity=high
- **Автоапдейт перезаписал форк** — «это автоапдейт который перезаписал мой форк опенкода?» (21.10 17:49) — severity=high
- **Zen rings / ladder free** — «Zen worker capacity unavailable — раннеров нет» (22.10 18:34) — severity=medium
- **Биллинг / лимиты** — «пополнил один аккаунт на 10 юзд получается увеличился лимит у него?» (23.10) — severity=low

---

## Judge comments

- **P.1 (CacheMarkLedger 500) — РЕШЕН runtime, но CI `main` сломался** — **Реально есть:** 13 рантайм-ошибок 23.10 10:00–12:57; PR #208 merged 23.10 13:24; selftest зелёные `2343`/`0213`; candidate=installed=`f62df808f332`. **Сомнительно:** тот же коммит (57bfddbe69) внёс TS2719 в `llm.ts:403` — duplicate branded types → 9 failing jobs на `main`. **Требуется:** пофиксить typecheck (дубликат `SessionID`/`Continuation`/`RunError`), довести `main` до зелёного, пересобрать кандидата.
- **P.2 (CI main) — красный на 9 jobs** — **Реально есть:** typecheck, unit (linux shard 1/4), unit (linux), unit (windows shard 2/4), unit (windows shard 4/4), verify (linux), build (linux), build (linux, service). **Требуется:** тот же фикс (P.1) → зелёный `main`.
- **P.3 (TDZ) — пофикшен на `main`** — **Реально есть:** `mem-record-store.ts:245` `const limit` перед использованием на 249/258; регресс закрыт.
- **P.4–P.6 (фиктивная приёмка, 2 KiB, устойчивость) — структура неизменна** — **Реально есть:** `DONE` на 190 до проверок 209/217/223; needle в файле сессии, не в ответе; truncation-маркеры 3162/24 ч; флаг памяти выключен в selftest/chain; 5×`500`+NOT-BOUND в истории. **Требуется:** машинная сверка ответа T1 с исходником (`sha256`/`cmp`), перенос `DONE` после проверок, retry/backoff на `500` или `inconclusive`, запись candidate/installed SHA в chain-state, включить `OPENCODE_V2_MEMORY_CONTEXT=1` в selftest для реального теста памяти.
- **P.7 (деньги/intent) — без изменений** — **Реально есть:** `cost`=0, `intent_signal`=0. **Требуется:** починить или убрать из дайджеста как источник шума.
- **P.8 (CSM) — мёртв** — **Реально есть:** `last_scanned_at` 21.10, `issues`=0, `reports/` от 09.10, `analyzer-state.last_run` 2026-04-02. **Требуется:** watchdog на `last_scanned_at` старше 2 ч; иначе секция User feedback деградирует в ручной разбор `opencode.db`.
- **P.10 (No tool named) — NEW ROOT CAUSE** — **Реально есть:** схема тулов (system message) содержит `tools.opencode.list_mcp_resources({...})`; модель вызывает так → «No tool named»; 320× в 24 ч, 359 из `scheduled-iteration`. **Сомнительно:** это не галлюцинация модели, а несоответствие схема↔рантайм. **Требуется:** либо зарегистрировать тулы с `tools.opencode.` префиксом, либо убрать их из схемы, либо алиасить к нативным именам.
- **P.11 (V2 флаги) — флаги существуют, но доки сломаны** — **Реально есть:** бинарь содержит `OPENCODE_V2_MEMORY_CONTEXT`, `OPENCODE_V2_MEMORY_MIN_CHARS`, `OPENCODE_V2_MEMORY_TOOLS`, `OPENCODE_V2_MEMORY_CONTEXT_DEBUG`; release-current.md — пустые имена; генератор пишет неверные `*_CONTEXT_MIN_CHARS`/`*_CONTEXT_TOOLS`. **Требуется:** починить генератор (имена без лишнего `CONTEXT`), убрать редактор секретов или разрешить `OPENCODE_V2_MEMORY_*` в release-notes, закрыть #191.
- **P.12 (метрики #190) — рабочий обход есть** — **Реально есть:** `mem-metrics-v2.sh` даёт полный дайджест; предписанный `mem-metrics.sql` — пустой. **Требуется:** обновить промпт исследователя на v2-wrapper (issue `#190`).
- **P.13 (prune) — работает** — **Реально есть:** `prune` в `run-mem-chain.sh`, `~/.worktrees` пуст, `/` 44 GiB. **Сомнительно:** stale checkout `/Users/vova/code/opencode-mem-verify` загрязняет локальный typecheck (дубликат effect). **Требуется:** убрать/очистить stale checkout.
- **P.15 (read-тул, #198) — исправлено в коде, issue открыт** — **Реально есть:** `plugin/read.ts:23` указывает реальный потолок (`50 KiB ≈ 624 строки`). **Требуется:** закрыть `#198`.
- **Свежий user-сигнал (MCP/сессии/worktree/auto-update/zen)** — **Реально есть:** пользователь 22–23.10 сообщает об отвале MCP-серверов, потерянных/невидимых сессиях, `Location not found` по worktree, автоапдейте поверх форка, мертвых zen-кольцах. **Сомнительно:** относится ли это к форку `opencode-mem` или к session-manager/окружению/ladder. **Требуется:** завести issues и разграничить (форк vs CSM/окружение/ladder).

---

## Next research priorities

1. **Пофиксить typecheck на `main` (TS2719 в `llm.ts:403`)** — снять 9 failing jobs, довести `main` до зелёного, пересобрать кандидата, прогнать selftest.
2. **Устойчивость selftest к инфра-сбою** — retry/backoff на `UnexpectedStatus: 500` + разделение инфра/продуктового вердикта + candidate/installed SHA в chain-state.
3. **Машинная сверка ответа T1 с исходником** (`sha256`/`cmp`) + перенос `DONE` после проверок (#195/#197).
4. **Включить `OPENCODE_V2_MEMORY_CONTEXT=1` в selftest/chain** — иначе память не тестируется вообще.
5. **Watchdog на CSM-сканер** (`last_scanned_at` старше 2 ч) — иначе feedback-канал слеп.
6. **Завести issues по свежим user-сигналам** (MCP отвал, потерянные сессии/worktree location, автоапдейт поверх форка, zen) и разграничить форк vs окружение/ladder.
7. **Починить/выключить детекторы `cost` и `intent_signal`** — сейчас дайджест по ним пуст.
8. **Исправить схему тулов: `tools.opencode.list_mcp_resources` не вызываема** — алиас к нативному `list_mcp_resources` или убирать из схемы.
9. **Поправить release-notes генератор** — имена флагов без лишнего `CONTEXT`, не вырезать `OPENCODE_V2_MEMORY_*` при публикации.
10. **`ITERATIONS.md`** — дописать chain `2343`/`0213`, регресс typecheck, диагноз CacheMarkLedger, статус флагов.
11. **Закрыть `#198`** (read-тул) — фактически исправлено.
12. **Очистить stale checkout `/Users/vova/code/opencode-mem-verify`** — загрязняет локальный typecheck.

---

Коммит change: git add STUDY.md && commit -m "research: research-20261024-0230" && push