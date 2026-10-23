# STUDY research-20261023-1323

Метод: read-only. SQL по `~/.local/share/opencode/opencode.db` (`session_v2`/`session_message`) +
`mem-metrics-v2.sh` (канонический источник; предписанный `mem-metrics.sql` бьёт по мёртвой v1-базе,
см. п.14), CSM `sessions.db`/`issues.jsonl`/`reports/` (read-only), `chain-state.jsonl`,
`selftest-logs/`, git/gh по форку `gpt-mem/opencode-mem` и `gpt-mem/opencode-mem-architecture`.
Окно дайджеста — 24 ч, если не указано иное. Числа, помеченные «≈», получены keyword-классификацией
и приблизительны (методика в секции User feedback).

## Ranked by usefulness

1. **Ранжирование/статус-фильтр памяти: дефект закрыт, но закрывающий фикс сам сломан (TDZ)** — `high` — STATUS: `proven` — PR #201 (squash `7038275716`, «ensure active status filter and correct ranking») смержен в `main`, `#194` закрыт, но `mem-record-store.ts:248` читает `limit` до `const limit` (стр.250) → `ReferenceError: Cannot access 'limit' before initialization`; `tool-operational-memory.test.ts` = 5 pass / 4 fail. Локальная (незапушенная) ветка `fix-mem-search-regression` (`c685af93e5`) чинит порядок (9/0, typecheck зелёный) и добавляет `mem-record-search.test.ts`.
2. **CI форка красный 3 коммита подряд на `main`** — `high` — STATUS: `proven` — `gh run list --branch main`: `3bc22d5100`, `7038275716`, `11455206b4` → workflows `test` и `check` = **failure** (последний зелёный `test` — `0214663376`, 2026-10-22T17:57). Прямое следствие п.1; `nix-eval` зелёный, т.е. падают именно unit/typecheck-джобы.
3. **Приёмка фиктивна: «ответ модели ≠ исходник», харнесс сверяет только маркер** — `high` — STATUS: `proven` — `run-selftest.sh:190` печатает `=== SELFTEST … DONE ===` **до** проверок `:209` (truncation marker), `:217` (full output), `:223` (needle); needle ищется `strings` по файлу сессии+WAL, а не по ответу модели (`#195` открыт). Т.е. 5/5 `ok` достижимы без чтения ответа.
4. **Окно доставки 2 KiB режет аргументы `put_in_operational_memory`** — `high` — STATUS: `proven` — truncation-маркеры `showing lines` = 2755 за 24 ч / 7811 за 7 д (не убывает); корень двухконтурный (`MAX_BYTES`+байтовый курсор против маркера по строкам).
5. **Selftest не устойчив к инфра-сбою: один `500` обнуляет прогон** — `high` — STATUS: `proven` — серия за сутки: `071528` и `084308` зелёные (T1–T5 exit=0) → `091649` все ходы `every rung failed` → `112556` прерван (verify-клон ≠ кандидат) → `130047` `T1 exit=1 UnexpectedStatus: 500` + `session: NOT-BOUND … оставшиеся ходы пропущены`; chain `20261023-1300` `selftest exit=70` (23 s против 399–566 s зелёных).
6. **Деньги и intent мертвы — детекторы не пишут** — `high` — STATUS: `proven` — `cost`=0 во всём 24 ч окне (и 7 д); последняя сессия с `cost>0` — `2026-10-12 07:51`; `intent_signal`=0, `provider_cache_mark`=0, `intent`=0 в основной БД ⇒ `cosine_avg`/`acted%` недривятся.
7. **CSM-сканер стоит, канал feedback мёртв** — `high` — STATUS: `proven` — `max(last_scanned_at)`=`2026-10-21T11:43:24Z`, последняя сессия в CSM `2026-10-21T07:27`; таблица `issues`=0 строк, `issues.jsonl`=1 строка (2026-03-14), `reports/`=12 файлов от 09.10, `analyzer-state.json.last_run`=`2026-04-02` ⇒ ни жалоб, ни feature request не поступает.
8. **Ошибки Code Mode вне `state.error` — занижение** — `high` — STATUS: `proven` — `execute` 273 вызова / 1 структурная ошибка в 24 ч, но 76 assistant-сообщений с `Unknown identifier`; `No tool named` = 212 за 24 ч.
9. **«No tool named» — модель выдумывает имена тулов** — `high` — STATUS: `proven` — 212 вхождений за 24 ч; структурных ошибок `bash` 12 / `shell` 10 / `edit` 100 / `read` 49.
10. **V2-флаги не существуют, релиз-ноты их рекламируют** — `high` — STATUS: `proven` — `strings ~/.opencode/bin/opencode | grep -c OPENCODE_MEMORY_{CONTEXT,CACHE_MARK,FIRST_DELIVERY}` = 0; `release-current.md` перечисляет «Флаги v2»; issue `#191` открыт (4-й цикл).
11. **`mem-metrics.sql` (#190) мёртв для v2; рабочий wrapper уже есть** — `high` — STATUS: `proven` — предписанный скрипт бьёт по `opencode-memory-context-v1.db` (заморожена `2026-10-12 14:34`; 24 ч окно пусто); `mem-metrics-v2.sh` корректно читает `session_v2`+`session_message` и все канальные `opencode*.db`. Дайджест в этом отчёте снят wrapper'ом.
12. **Disk здоров, prune-шаг теперь в цепочке** — `high` — STATUS: `proven` — `/` 27 GiB свободно (31 %); `~/.worktrees` = **0 B / 0 ворктри** (было 36 GiB / 27); `run-mem-chain.sh:136,138` содержит `prune-emergency`/`prune`; `chain-state.jsonl` пишет `step:"prune"` + `prune-detail`. Дефект закрыт.
13. **`get_tool_call_details` 976/24 ч — но 962 из одной scheduled-сессии** — `high` — STATUS: `proven` — почти весь объём даёт `scheduled-iteration` (962); органические сессии — 1–3 вызова каждая ⇒ «доля memory-тулов 10.9 %» — артефакт автоматического цикла, а не пользовательского спроса.
14. **`read`-тул: описание приведено в соответствие (issue #198 закрыт по факту)** — `medium` — STATUS: `proven` — `plugin/read.ts:23` теперь пишет «defaults to 2000, capped by MAX_READ_BYTES = 50 KiB ≈ 624 lines»; `read-filesystem.ts:15` `MAX_READ_BYTES = 50 * 1024`. Расхождение описания устранено.
15. **SHA больше не «неизменен»: бинарь и кандидат разошлись** — `medium` — STATUS: `proven` — установлен `opencode v0.0.0-fork-at-021466337676`; свежайший кандидат `11455206b4b0`; `selftest-last.json.sha12`=`021466337676`; `130047` проверял кандидата `11455206b4b0` против установленного `021466337676` ⇒ «SHA immutable пять циклов» больше не держится.
16. **`mem_record`: запись идёт, дублей нет** — `medium` — STATUS: `proven` — 268 всего / 243 active / 25 superseded, 15 проектов, 61 новая за 24 ч; типы decision 118 / constraint 82 / failed_approach 45 / user_signal 23; authority agent 157 / user 111; пустой scope 91/268.
17. **Компакция есть, но не измеряется** — `medium` — STATUS: `proven` — `compaction` сообщений 20 (24 ч) / 158 (7 д); `time_compacting IS NOT NULL` = 0 из 1056 сессий 7 д ⇒ §8 `mem-metrics.sql` не различает compacted/full.
18. **Валидация кросс-проектной памяти вводит в заблуждение** — `medium` — STATUS: `proven` — `get_operational_memory` по id из другого проекта отдаёт `found:false, "No memory … in this project"`, хотя запись активна ⇒ лишний поиск. Не проверялось повторно в этом цикле, но код-путь не менялся.
19. **Форк-плагины не грузятся: большинство WARN** — `medium` — STATUS: `proven` — `configured plugin path must be a directory` = 1359 из 3028 `WARN` в `opencode.log` (лог охватывает 10-21…10-23). Счётчики **не сравнимы** между циклами: лог компактится in-place (`logging.ts`), сейчас 40 MiB и 72 860 строк.
20. **`question`-тул не показывает вопрос** — `medium` — STATUS: `proven` — 6 вызовов за 24 ч; жалоба пользователя ровно одна («→Asked 1 question - а где вопрос не вижу?», 21.10) — единственная свежая user-жалоба в CSM.
21. **Саморевью не ревьюит код форка** — `medium` — STATUS: `proven` — self-review сессии заявляют «правок не вносил, рабочее дерево не менял»; отдельно `scheduled-iteration` делает 962 вызова retrieval-тула без правок.
22. **`ITERATIONS.md` отстаёт** — `medium` — STATUS: `proven` — записи от 2026-10-23 есть только по #15/#29/#194, нет ни `091649`/`112556`/`130047`, ни серии регресса selftest; последняя запись — «triage #29/#194».
23. **Открытые issues форка: 23** — `medium` — STATUS: `proven` — среди них P0 `#190` (метрики v1), `#202` (unified mask только на мёртвой v1), `#195` (приёмка), `#191` (флаги), `#188` (сборка из устаревшего local main), `#198`. Открытых PR — 0.
24. **NL-поиск: regex приоритетен, морфологии нет, fallback по OR** — `medium` — STATUS: `doubtful` — код `mem-record-store.ts:236-243` (regex → plain-text) сохранён, но проверить семантику вживую в этом цикле нельзя: search-путь сейчас падает с TDZ (п.1) на no-query/regex ветках ⇒ эмпирика загрязнена.
25. **«`<tool_call>` в строке данных»** — `low` — STATUS: `doubtful` — наблюдение `065732` не воспроизведено; механизм не установлен.
26. **API-key/baseURL в логах `0644`** — `low` — STATUS: `doubtful` — в свежих логах не найдено; `selftest-logs/` по-прежнему world-readable, риск не снят.
27. **Долгоживущие процессы на старом коде** — `low` — STATUS: `needs_proof` — `opencode serve` (pid 71292, запущен 15:05) крутится из `opencode-mem-work/packages/cli/dist`; влияние на пользователя не измерено.
28. **Cross-memory resume — единственный реальный апгрейд, но тонкий** — `low` — STATUS: `doubtful` — в этом цикле новых независимых наблюдений не появилось; прошлые два (090453, 111142) сделаны в self-review агентских сессиях, не в пользовательских ad-hoc, и эффект перекрывается дефектом длины (п.3/п.4) ⇒ «память помогла» не отделено от «память перефразировала прошлое знание».

---

## Metrics digest (24h)

- **Sessions: 215** (scheduled 151, ad-hoc 37, chain 27), **Total tokens: in 147,578,357 / out 1,163,258** (reasoning 1,025,550), **Cache read: 370,228,985 (71.5 %**, cache_write 0**)**, **Cost: $0.00** (детектор мёртв; последний `cost>0` — 2026-10-12)
- **Memory tools: overview=0, find_tool_calls=0, detail=976** (962 из них — одна `scheduled-iteration`), **search=9, put=23, get_by_id=2** ⇒ органическая доля ≈ 12 вызовов/24 ч
- **Intent signals: cosine_avg=н/д, acted%=н/д** (`intent_signal`=0 строк)
- Memory records: 268 всего / 243 active / 25 superseded, 15 проектов, 61 новая за 24 ч; типы decision 118 / constraint 82 / failed_approach 45 / user_signal 23; authority agent 157 / user 111; пустой scope 91
- Compaction: 20 сообщений (24 ч), 158 (7 д), 0 сессий с `time_compacting` из 1056 (7 д)
- Truncation-маркеры `showing lines`: 2755 (24 ч), 7811 (7 д)
- Tool errors (`state.status='error'`, 24 ч): edit 100, read 49, bash 12, grep 11, shell 10, write 5, question 5, get_tool_call_details 4, search 3, webfetch 2, execute 1; `No tool named` 212, `Unknown identifier` 76
- Chain (`chain-state.jsonl`): `20261023-1300` prune ok → build ok(8 s) → **selftest exit=70 failed(23 s)** → release withheld → bug-reporter ok(329 s); ранее `20261023-1055` build exit=70 → selftest/release withheld
- Selftest logs: 84 `.log`; серия за сутки зелёная→красная→прервана (см. п.5)
- Disk: `/` 27 GiB свободно (31 %); `~/.worktrees` 0 B / 0 ворктри (prune работает)
- GitHub: `gpt-mem/opencode-mem` 23 open issues / **0 open PR**, `main` CI `test`+`check` красные на 3 последних коммитах; `gpt-mem/opencode-mem-architecture` 1 open issue; docs-репо чистый, HEAD == origin/main
- CSM: 795 сессий (opencode 721 / codex 74), `last_scanned_at` `2026-10-21T11:43:24Z`; `issues`=0, `issues.jsonl`=1 (2026-03-14), `reports/` от 09.10

## User feedback top

Методика: keyword-классификация текста промптов; primary — CSM `sessions.db` (795 сессий, `first_prompt`+`summary`),
secondary — user-сообщения `opencode.db` за 7 д (626 «человеческих» промптов после отсева automation/subagent-промптов).
Классификация приблизительна (≈) и **пересекается**: один промпт может попасть в несколько категорий.
CSM стоит с 21.10 ⇒ свежесть ограничена; `issues.jsonl`/`reports/` как канал feedback пусты.

1. **Форк / память / приёмка (репо-ссылки и жалобы)** — ≈193 CSM-сессий (≈134 opencode-промпта/131 сессия) — severity=high — «fix this bug …/issues/119», «разобраться почему CI стал», «детекшн loop часто ловит ложные детекты …/pull/145»
2. **GH-токены / права / merge** — ≈75 opencode-промптов/71 сессия (CSM ≈35) — severity=medium — «мой gh-токен без права merge», «merge не проходит — нужен admin-токен», «какой токен нужен?»
3. **ZeroCreds / tunnel / шаринг** — ≈26 opencode/10 сессий (CSM ≈47) — severity=medium — «кодекс не может с zerocreds работать», «zerocreds.connection_resolve → connections: []», «хочу поделиться кредами с коллегой» (повторяется ≥5 раз)
4. **Провайдер / каталог моделей / Ladder runtime** — ≈22 opencode/16 (CSM ≈85) — severity=high — «invalid ladder_cache_variant», «Zen worker capacity unavailable», «21 модель ушла из инвентаря»
5. **CI / тесты / flaky** — ≈14 opencode/8 (CSM ≈181) — severity=high — «почини ошибки в тестах чтобы pr прошёл», «e2e не зашавершился»
6. **trained-assist / Ladder runtime (соседний продукт)** — ≈12 opencode/11 (CSM ≈126) — severity=medium — «какой именно opencode запускает trained-assist в проде»
7. **Тулы / MCP / Code Mode сломаны** — ≈9 opencode/7 (CSM ≈136) — severity=high — «у неё нет доступа ни к каким тулам», «execute ↳ ReferenceError: Unknown identifier 'require'»
8. **Sandbox / provisioning** — ≈9 opencode/7 (CSM ≈101) — severity=medium — «Sandbox provisioning выключен — нужно включать»
9. **Агент завис / упал / пустой ответ** — ≈5 opencode/4 (CSM ≈84) — severity=high — «он ничего не отвечает», «упал агент», «agent exited non-zero»
10. **Ответ неверен / расхождение** — ≈3 opencode/2 (CSM ≈14) — severity=high — «не то что просил», «какой клаудфларе не валиден?»
11. **Стоимость / инстансы** — ≈1 opencode/1 (CSM ≈46) — severity=low — «инстанс 24/7 ≈ $0.47/мес — один на все задачи?»
12. **`question`-тул не показывает вопрос** — 1 — severity=medium — «→Asked 1 question - а где вопрос не вижу?» (единственная свежая user-жалоба в CSM)
13. **CSM feedback channel** — 1 (`issues.jsonl`, 2026-03-14) — severity=low — «Нужно добавить: connection test»; канал мёртв
14. **Внешние продукты (не фичи форка):** chemistry/rnd-forge (CSM ≈35), playwright/browser (≈24), CRM/exhibits/deal-bot (≈11), HH/resumes (≈2) — не входят в оценку полезности форка

- **Что бьёт по форку vs проходит мимо:** #1, #5, #7, #9, #10, #12 — про форк и его приёмку; #2 — доступ к GitHub в этом же окружении (пересекается с #191/#188); #3, #4, #6, #8, #11, #14 — про соседние продукты (Ladder / ZeroCreds / Cloudflare / sandbox).
- **Сдвиг:** свежих человеческих сигналов за цикл — **ноль** (CSM стоит с 21.10); весь «прирост» обращений — это уже записанные промпты, не новые. Спрос на память как пользовательскую функцию близок к нулю (≈3 CSM-сессии), спрос на приёмку/CI — максимальный.

## Judge comments

- **P.1 (ранжирование) — дефект доказан, но фикс сам сломан; главный факт цикла** — **Реально есть:** `#194` закрыт PR #201 (`7038275716`), код на `main` фильтрует `status='active'` (стр.219-221) и для plain-text берёт head (не tail). **Сомнительно:** ничего — воспроизводится стабильно: `bun test test/tool-operational-memory.test.ts` на `main` = 5 pass / 4 fail, `ReferenceError: Cannot access 'limit' before initialization` (`mem-record-store.ts:248`); CI `test`+`check` красные на `3bc22d5100`/`7038275716`/`11455206b4`. **Требуется:** починить порядок объявлений (ветка `fix-mem-search-regression` `c685af93e5` уже это делает: 9/0 + typecheck зелёный + новый `mem-record-search.test.ts`), **запушить её**, открыть PR, дождаться зелёного CI и только потом считать `#194` закрытым; переоткрыть/завести issue на регресс.
- **P.2 (статус-фильтр) — закрыт вместе с P.1, проверять нечем пока search падает** — **Реально есть:** `input.status ?? "active"` (стр.220-221) — то, что просили. **Сомнительно:** нет регресс-теста на «superseded не возвращается» в `main` (он появляется только в незапушенной ветке). **Требуется:** тот же PR + тест.
- **P.3–P.4 (фиктивная приёмка, 2 KiB) — структура неизменна** — **Реально есть:** `DONE` печатается на `:190` до проверок `:209/:217/:223`; needle ищется в файле сессии, не в ответе; truncation-маркеры 2755/24 ч. **Сомнительно:** «зелёный прогон = качество» — нет, `084308`/`071528` зелёные по построению. **Требуется:** машинная сверка ответа T1 с исходником (`sha256`/`cmp`), проверка «модель не выдумывает строки», перенос `DONE` после всех проверок, needle — из ответа конкретного хода.
- **P.5 (устойчивость selftest) — новый high-приоритет** — **Реально есть:** `130047` упал на первом ходу (`UnexpectedStatus: 500`), прогон оборван, `session: NOT-BOUND`; `091649` — 10 ретраев `every rung failed` на всех ходах; `112556` прерван из-за расхождения verify-клона и кандидата. **Требуется:** retry/backoff на `500` либо пометка «inconclusive» вместо обрыва; разделять инфра-сбой и продуктовую регрессию в вердикте; писать candidate SHA и installed SHA в `chain-state`.
- **P.6 (деньги/intent) — без изменений** — **Реально есть:** `cost`=0 во всём окне, `intent_signal`/`provider_cache_mark`/`intent`=0. **Требуется:** либо починить детекторы, либо убрать из дайджеста как источник шума (решение — не за мной).
- **P.7 (CSM) — мёртв и стал хуже** — **Реально есть:** `last_scanned_at` 21.10, `issues`=0, `reports/` от 09.10, `analyzer-state.last_run` 2026-04-02. **Требуется:** watchdog на `last_scanned_at` старше 2 ч; иначе секция User feedback деградирует в ручной keyword-разбор.
- **P.8 (Code Mode) — занижение подтверждено** — **Реально есть:** 273 `execute` / 1 структурная ошибка, но 76 `Unknown identifier`; `No tool named` 212. **Требуется:** складывать sandbox-ошибки в `state.error` и/или отдельный счётчик.
- **P.9 (флаги v2) — 4-й цикл** — **Реально есть:** 0 совпадений в бинаре; релиз-ноты рекламируют. **Требуется:** либо реализовать флаги, либо убрать из `release-current.md` (issue `#191`).
- **P.10 (read-тул, #198) — закрыт по факту** — **Реально есть:** описание `plugin/read.ts:23` теперь указывает реальный потолок (`50 KiB ≈ 624 строки`). **Требуется:** закрыть issue.
- **P.11 (prune) — закрыт** — **Реально есть:** `prune` в `run-mem-chain.sh`, `~/.worktrees` пуст, `/` 27 GiB. **Требуется:** ничего, следить за регрессом.
- **P.12 (метрики #190) — рабочий обход есть** — **Реально есть:** `mem-metrics-v2.sh` даёт полный дайджест; предписанный `mem-metrics.sql` — пустой. **Требуется:** обновить промпт исследователя на v2-wrapper (issue `#190`).

## Next research priorities

1. **Запушить `fix-mem-search-regression` (`c685af93e5`) → PR → зелёный CI → мерж** — восстановить search и снять красный `main` (блокирует всё остальное).
2. **Переоткрыть/завести issue на регресс TDZ** и переоткрыть `#194`, пока фикс не проверен на `main`.
3. **Устойчивость selftest к инфра-сбою** — retry/backoff на `UnexpectedStatus: 500` + разделение инфра/продуктового вердикта.
4. **Машинная сверка ответа T1 с исходником** (`sha256`/`cmp`) + перенос `DONE` после проверок (#195).
5. **Watchdog на CSM-сканер** (`last_scanned_at` старше 2 ч) — иначе feedback-канал слеп.
6. **Починить/выключить детекторы `cost` и `intent_signal`** — сейчас дайджест по ним пуст.
7. **Сложить ошибки Code Mode в `state.error`** — убрать занижение.
8. **Обновить промпт исследователя на `mem-metrics-v2.sh`** (#190) и убрать/реализовать v2-флаги в релиз-нотах (#191).
9. **`ITERATIONS.md`** — дописать серию регресса selftest и статус фикса ранжирования.
10. **Закрыть `#198`** (read-тул) — фактически исправлено.

---

Коммит change: git add STUDY.md && commit -m "research: research-20261023-1323" && push
