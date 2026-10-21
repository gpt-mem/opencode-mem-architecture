# BUG-REPORTS — фактология из self-test логов

## BUG-REPORT 20261012-000748

Источник: `~/.opencode/scripts/selftest-logs/selftest-20261012-000748.log` (наибольший по mtime, 10 ходов T1–T4, T7–T12, session `ses_ed4cd38b3ffeK7k4E5K1bh2pmS`).

### Проблемы
- Ретрив записанного решения = 0 четвёртый проход подряд — «`find_tool_calls(query="форкать") → matched: 0`», «`find_tool_calls(query="принято решение") → matched: 0`», динамика `0→3→5→7→0→0→0→0` — high
- `put_in_operational_memory` недоступен 8 раз подряд, решение нигде не персистится — «`put_in_operational_memory` недоступен — восьмой раз подряд. Единственный носитель решения — текст текущего контекста; после рестарта он исчезнет» — high
- PII-утечка в индекс: e-mail в 3 bash-носителях от утечной маски, утечный вызов остаётся в индексе — «Все три порождены одной маской `NEEDLE|Release ID`»; «утечку контролирует конструкция запроса … свойство **оператора**, не системы» — high
- `find_pii` отсутствует, PII-тегов нет — «Тегов нет — `find_pii` отсутствует» — medium
- Агрегат overview не сходится: `groups_total: 2` при `total: 70` (сумма `groups` = 16) — «`groups_total: 2` по-прежнему не равно сумме `groups` (16) при `total` 70» — medium
- Статус вызова не отражает исход команды: `status: completed` при упавшей команде — лог: `ls: /var/folders/1m/.../tmp.te3n4xZTbR/: No such file or directory`; «Статусы неточны по смыслу: `status: completed` при упавшей команде» — medium
- Вложенные tool-results не индексируются: needle-факты доступны только с диска — «вызовы `Read` doc1–doc3 в индекс не попадают», «Содержательно сработал только `grep` по диску» — medium
- `truncated: false` не описывает данные — «`truncated: false` описывает индекс, не данные» — medium
- `pending` не попадает в выдачу 4 прохода подряд — «`pending` не появляется в `limit=5` — четвёртый проход подряд» — low
- Харнесс: TURN T5/T6 отсутствуют в логе (T4 → T7) — «--- TURN T7: Вспомни: какое решение…» сразу после T4 — low
- Харнесс: glob-опечатка живёт с первого прохода — «опечатка `pattern=**/*doc*"` живёт с первого прохода» — low

Регрессий vs предыдущих циклов (ITERATIONS) не зафиксировано: фиксы прошлых сессий держатся (см. Паттерны), оценка «ничего не прячем» стабильна 3/5 — «Оценка стабильна на 3/5 за восемь проходов».

### Паттерны
- Фиксы предыдущих циклов подтверждены: overview снова полон (`"total": 70`, блок `memory_tools` — PR #48, ITERATIONS 26/33); эхо-PII нет — «Ни одного `find_tool_calls` в выборке … хотя `memory_tools.find_tool_calls = 37`» (PR #44, ITERATIONS 23); новое поле `source` = ожидаемый PR #52 (ITERATIONS 33)
- Смена носителя (карьер-чёрнинг): 7 tmp-каталогов за серию, 6 удалены — «Носитель — седьмой по счёту, шесть предыдущих удалены», два вызова фиксируют смену каталога
- PII-счётчик стабилен: 3 носителя 4 прохода подряд, credential не попал ни разу — «носителей 3 (стабильно 4 прохода)», «credential `rbk_9f3a_deep_42` не попал ни разу»
- Маркеры чисты ≠ индекс чист: лог заканчивается `0 markers with pii=`, при этом 3 PII-носителя живут в индексе — проверка покрывает только маркеры
- Воспроизводимость безопасного пути: три разных grep-вызова дают идентичные 255 символов — «255 = 255 = 255», `truncated: false`
- Схема `details` изменилась посреди серии: поле `source: "full_original"` отсутствовало в прежних 6 вызовах — «поле `source` не было ни в одном из прежних 6 вызовов», появляется только в `details`, не в `overview`
- Четыре последних прогона (16:35, 18:44, 22:08, 00:07) — одна session id и байт-идентичный trailer (`in=41 out=36 cache_r=10688 cost=5.10664e-05` …) — хвостовая статистика не различает прогоны (ранние логи имели разные session и цифры)
- Агрегат недостаточен для аудита: «исчезнувшие записи неотличимы от непоказанных на уровне агрегата», «потерю 40→9 интерпретировать нельзя»

### Идеи (as is)
- Индексировать реплики ассистента с обратимостью как у `get_tool_call_details` — контекст: решение за 8 проходов в индексе не появлялось ни разу
- Индексировать внешние tool-results — контекст: doc1–doc3 модель видела 7 раз, `Read`-вызовы не записаны
- `find_pii` + read-only аудит «что я уже засветил» — контекст: «PII не детектируется. Обнаружение — ручной запрос по маске»
- Вынести `source` в `overview` + журнал очистки с причинами — контекст: массово определить состав индекса сейчас нельзя
- Согласовать `total` / `groups_total` / `memory_tools` — контекст: «`groups_total` вводит в заблуждение»
- Разделить статусы: «тул завершён» / «команда успешна», «индекс не усёк» / «данные полны» — контекст: `completed` при упавшей команде, `truncated:false` про индекс

(Все идеи — из финального отчёта T12 «что подняло бы до 5» при оценке 3/5; только констатация.)

## BUG-REPORT 20261012-023539

Источник: `~/.opencode/scripts/selftest-logs/selftest-20261012-023539.log` (наибольший по mtime, 10 ходов T1–T4, T7–T12, session `ses_ed4cd38b3ffeK7k4E5K1bh2pmS`, форк `379d4ac8db`).

### Проблемы
- Приёмка PR #53 не пройдена второй лог подряд: `find_pii` не в списке тулов, хотя в release notes объявлен — «`find_pii` недоступен», «Тегов нет — `find_pii` отсутствует»; список доступных из T2: `bash, edit, write, read, glob, grep, find_tool_calls, get_tool_call_overview, get_tool_call_details, task, todowrite, skill, webfetch, websearch` — high
- Ретрив записанного решения = 0 пятый проход подряд — «`find_tool_calls(query="форкать") → matched: 0`», «`find_tool_calls(query="принято решение") → matched: 0`», динамика `0→3→5→7→0→0→0→0→0` — high
- `put_in_operational_memory` недоступен 9 раз подряд, решение нигде не персистится — «`put_in_operational_memory` недоступен — девятый раз подряд. Единственный носитель решения — текст текущего контекста; после рестарта он исчезнет»; «⚠️ Девятая запись того же решения» — high
- PII-утечка в индексе: e-mail в 3 bash-носителях от утечной маски, утечный вызов остаётся в индексе — «Все три порождены одной маской `NEEDLE|Release ID`»; «утечку контролирует конструкция запроса … свойство **оператора**, не системы» — high
- Внедрённые tool-results не индексируются: needle-факты только с диска — «`Read` не индексируется, `bash` — индексируется»; «Содержательно сработал только `grep` по диску» — medium
- Пользовательская вставка в индекс не попадает: e-mail из T3 не создал носителя — «Текущая вставка в индекс не добавилась» — medium
- Статус вызова не отражает исход команды — «Статусы неточны по смыслу: `status: completed` при упавшей команде»; в логе: `ls: /var/folders/1m/…/tmp.rW2brL2Myk/: No such file or directory` — medium
- `truncated: false` описывает индекс, не данные — «`truncated: false` описывает индекс, не данные» — medium
- Агрегат: `groups_total` трактуется неоднозначно (2 ≠ сумма `groups` 18), хотя `total` сошёлся — «`groups_total: 2` по-прежнему ≠ сумме `groups` (18) при `total` 79» — medium
- Релиз-ноты против лога: заголовок `mem-v20261011-2208-1b9410798c`, в списке — коммиты до `379d4ac8db` (#53/#54/#55), а `find_pii` в сессии нет — строка релиза `14de53bdc9 feat(core,opencode): find_pii audits PII carriers with masked evidence (issue #11) (#53)` vs лог «`find_pii` отсутствует» — medium
- `pending` не попадает в выдачу 5 проходов подряд — «`pending` не появляется в `limit=5` — пятый проход подряд» — low
- Харнесс: TURN T5/T6 отсутствуют в логе (T4 → T7) — «--- TURN T7: Вспомни: какое решение…» сразу после T4 — low
- Харнесс: glob-опечатка живёт с первого прохода — «опечатка `pattern=**/*doc*"` живёт с первого прохода» — low
- Харнесс: «Вкладываю три документа», вложений нет — «**Вложений в сообщении нет**, документы найдены на диске» — low

Регрессий vs предыдущих циклов (ITERATIONS) по коду не найдено: `overview.total` снова полон и сходится (`79 = 16+2+42+10+9`, PR #48), поле `source: "full_original"` стабильно (PR #52), эхо-PII нет. Единственный провал приёмки — `find_pii`: приёмка сессии 35 «следующий selftest-лог — проверить, что модель нашла `find_pii`» не выполнена (лог 00:12 и лог 02:35 — оба «недоступен»), при этом ITERATIONS 37 фиксирует «`find_pii` закрыт PR #53». Оценка «ничего не прячем» стабильна 3/5 — «Оценка стабильна на 3/5 за девять проходов».

### Паттерны
- Обзор стабилен 4 прохода и сходится по сумме — `"total": 79`, `groups_total: 2`, `memory_tools: [find_tool_calls 42, overview 10, details 9]` (PR #48 держится)
- Схема `details` стабильна — «`source: "full_original"` присутствует — схема, добавленная в 8-м проходе, стабильна» (PR #52)
- PII-счётчик стабилен: 3 носителя 5 проходов подряд, credential ни разу — «носителей 3 (стабильно 5 проходов)», «credential `rbk_9f3a_deep_42` не попал ни разу»
- Маркеры чисты ≠ индекс чист: хвост лога `0 markers with pii=` при 3 PII-носителях в индексе — проверка покрывает только маркеры
- Смена носителя (карьер-чёрнинг): 8 tmp-каталогов, 7 удалены — «Носитель — восьмой по счёту, семь предыдущих удалены»
- Воспроизводимость безопасного пути: 4 вызова дают идентичные 255 символов — «255 = 255 = 255 = 255»
- Анти-echo #34 работает: memory-тулы в поисковую выборку не попадают — «Ни одного `find_tool_calls` в выборке … хотя `memory_tools.find_tool_calls = 42`»
- Пять последних прогонов (16:35, 18:44, 22:08, 00:07, 02:35) — одна session id и байт-идентичный trailer (`in=41 out=36 cache_r=10688 cost=5.10664e-05` …, `0 markers with pii=`) — хвостовая статистика не различает прогоны
- Асимметрия индексации: «`Read` не индексируется, `bash` — индексируется» — needle-факты ретривабельны только через диск
- 9-й проход без новых дефектов — «9-й проход не принёс новых дефектов — он подтвердил стабильность трёх ранее найденных структурных пробелов»

### Идеи (as is)
- Индексировать реплики ассистента с обратимостью как у `get_tool_call_details` — контекст: решение за 9 проходов в индексе не появлялось ни разу
- Индексировать внешние tool-results — контекст: doc1–doc3 модель видела 8 раз, `Read`-вызовы не записаны
- `find_pii` + read-only аудит «что я уже засветил» — контекст: «PII не детектируется. Обнаружение — ручной запрос по маске»
- Вынести `source` в `overview` + журнал очистки с причинами — контекст: массово определить состав индекса сейчас нельзя
- Согласовать `total` / `groups_total` / `memory_tools` — контекст: «`groups_total` вводит в заблуждение»
- Разделить статусы: «тул завершён» / «команда успешна», «индекс не усёк» / «данные полны» — контекст: `completed` при упавшей команде, `truncated:false` про индекс

(Все идеи — из финального отчёта T12 «что подняло бы до 5» при оценке 3/5; только констатация.)

## BUG-REPORT 20261012-045342

Источник: `~/.opencode/scripts/selftest-logs/selftest-20261012-045342.log` (наибольший по mtime, **86 байт, 1 строка** — прогон не выполнялся). Контекст: `chain-logs/chain-20261012-0452.log`, `chain-state.jsonl`, `chain-logs/launchd-stdout.log`, `releaser-logs/releaser-20261012-043740.log`, `releaser-logs/releaser-20261012-045257.log`, `run-selftest.sh`, `run-mem-chain.sh`.

### Проблемы
- Selftest не выполнен: лог целиком = одна строка `fork dirty (другая сессия работает) — selftest пропущен`, нет ни ходов, ни маркера `=== SELFTEST … DONE ===`; `grep -E "FAIL|Error|panic|assert"` — 0 совпадений — high
- Пропуск записан как успех: `{"step":"selftest","exit":0,"dur_s":1}` (chain-state) и `STEP selftest END exit=0 dur=1s` (launchd-stdout) против `dur=280s` (00:07) и `dur=286s` (02:35); источник — `run-selftest.sh:34` `exit 0` на ветке dirty — high
- Ни одного полного selftest на текущем коде: последний полный лог (02:35) начинается с `fork at 379d4ac8db`; после него слиты #56/#57/#59 (tip `642fc48162`), установлен бинарь `0.0.0-memory-context-v1-202610120153` (в бинарю присутствуют `get_operational_memory`, `put_in_operational_memory`, `search_operational_memory`, `find_pii`); приёмка сессии 42 «верификация следующим selftest-логом (~06:35)» этим прогоном не состоялась — high
- Причина пропуска — чужой WIP в форке: `git status` в `/tmp/opencode-mem` — `M packages/core/src/tool/builtins.ts`, `M packages/core/test/location-layer.test.ts`, `?? packages/core/src/tool/get-operational-memory.ts`, `?? packages/core/src/tool/put-in-operational-memory.ts`, `?? packages/core/src/tool/search-operational-memory.ts`, `?? packages/core/src/session/mem-record-store.ts`, `?? packages/core/test/tool-operational-memory-v2.test.ts` (V2-регистрация #13, по ISSUES — хвост без issue) — medium
- Третий пропуск в серии: 86-байтные логи `selftest-20261011-122850.log`, `selftest-20261011-205028.log`, `selftest-20261012-045342.log` — 3 из 13 файлов каталога; первые два уже зафиксированы в ITERATIONS («лог 12:28 пропущен», «лог 20:50 пропущен») — medium
- Дубль-релиз одного SHA за 15 минут: GitHub `MEM build mem-v20261012-0438-642fc48162` (2026-10-12T01:38:22Z) и `MEM build mem-v20261012-0453-642fc48162` (2026-10-12T01:53:39Z); оба прогона releaser пишут `New commits: 40 (last tag: mem-v20261012-0318-b4bb44a44c)`, в форке локально только 3 тега `mem-*` (последний — `0318`) — guard `run-releaser.sh:33-34` «релиз не нужен» не срабатывает — medium
- Разный TZ в идентификаторах одного билда: тег `…-0453` (локальный +03:00) vs версия бинаря `202610120153` и `created …T01:53:39Z` (UTC) — low
- critical: **0** — ни падений, ни ассертов, ни паник: их в логе нет вовсе

Регрессий vs предыдущих циклов (ITERATIONS) не установлено — прогон не выполнялся, данных для сравнения нет; открытые находки лога 02:35 (`find_pii` не в списке тулов, ретрив решения `0`, `groups_total` ≠ сумме `groups`) этим прогоном **не перепроверены**.

### Паттерны
- Skip-лог байт-в-байт одинаков во всех трёх случаях: 86 байт, та же строка пропуска — «fork dirty (другая сессия работает) — selftest пропущен»
- Порядок шагов цепочки: `run-mem-chain.sh:82` release → `:85` selftest → `:88` bug-reporter; в прогоне 0452 релиз опубликован (`release published: mem-v20261012-0453-642fc48162`, 44s) раньше selftest (1s, пропущен), bug-reporter запущен с пустым логом
- Дрейф покрытия: selftest-лог отстаёт от установленного бинаря на 3 коммита (#56/#57/#59); skip-лог не содержит `fork at …`, SHA приходится восстанавливать по прошлому логу
- Хвост полных прогонов не различает запуски: session `ses_ed4cd38b3ffeK7k4E5K1bh2pmS`, `in=41 out=36 cache_r=10688 cost=5.10664e-05`, `0 markers with pii=` — байт-идентичен 00:07/02:35; в логе 04:53 хвоста нет совсем
- Прогресс параллельной сессии виден в форке в реальном времени (V2-тулы в работе) — грязное дерево есть, selftest ждёт его завершения

### Идеи (as is)
- Отличимый статус `skipped` в chain-state и логах шага — контекст: `exit=0 dur=1s` неотличим от пройденного прогона, downstream не различает
- Отложенный/повторный selftest, когда дерево чистое — контекст: 3 пропуска из 13, причина — чужой WIP
- Порядок шагов selftest → release — контекст: релиз опубликован при пропущенном selftest
- Синхронизировать локальные теги форка с GitHub перед guard «релиз не нужен» — контекст: два GitHub-релиза одного SHA за 15 минут
- Единый TZ для имени тега и версии бинаря — контекст: `0453` vs `0153`/`01:53:39Z` у одного билда
- Записывать SHA/tip и в skip-ветку selftest-лога — контекст: skip-лог не содержит `fork at …`

(Только констатация фактов из логов цепочки 04:52; решения не предлагались.)

## BUG-REPORT 20261012-072607

Источник: `~/.opencode/scripts/selftest-logs/selftest-20261012-072607.log` (18799 байт, наибольший по mtime, 10 ходов T1–T4, T7–T12, форк `fork at 965a967aa4`), контекст: `chain-20261012-0725.log`, `chain-state.jsonl`, `releaser-20261012-072524.log`, `run-selftest.sh`, `run-mem-chain.sh`, `memory-context.log`, `opencode-local.db`.

### Проблемы
- Хвостовые метрики лога сняты с чужой сессии: `session: ses_ed1d95007ffeZgImojZVHZ95Ax` — это benchmark-сессия (создана 06:27, содержит `find_tool_calls -> {"query":"DEPLOY-CODE-NEEDLE"}` от 06:32, ровно 11 assistant-сообщений = 11 строк `assistant in=…` трейлера); фактическая selftest-сессия `ses_ed28a837effe5uMO6CTZa7J3e0` (T1-промпт в 07:26:10, `call_bfd990989b87404cb28dda22` из T10 в ней же, 44 assistant-сообщения, `cache_r=45184…69184`); источник — `run-selftest.sh`: `SELECT id FROM session ORDER BY time_created DESC LIMIT 1` (по времени создания, не по записи прогона) — high
- Проверка PII-маркеров структурно пустая: `0 markers with pii=` — запрос `part.data LIKE '%pii=%'` по всей `opencode-local.db` даёт 0 совпадений (маркеры не персистятся в parts; 4 части с `mem:` — цитаты `[mem:compacted]` из текста модели) — medium
- Статус вызова не отражает исход команды — `ls: /var/folders/1m/v4ljzvzx5x566w1r067w5vmw0000gn/T/tmp.l9fwT4AVP4/: No such file or directory` и таблица T9: `| 5 | call_7ae32ba3b0614313a12f2203 | bash | completed | ls старого tmp.l9fwT4AVP4 → No such file |` — medium (3-й лог подряд: 20261012-000748, 20261012-023539)
- Вложения не найдены glob'ом, старый носитель удалён — `✱ Glob "**/doc{1,2,3}.md" 0 matches`; документы найдены только `ls` в новом `tmp.ncI1LHFus5` — medium
- PII-ложный ноль в T3 при последующем 2: `find_pii 0 tool calls with email PII`, `find_tool_calls 0 matching tool calls`, `search_operational_memory 0 matching memories (2 match the filters)` на вставленной почте vs T12 `find_pii 2 tool calls with email PII` (counts: email ×2, phone ×1) — medium (видимость зависит от носителя: текст сообщения ≠ tool-call)
- Харнесс: TURN T5/T6 отсутствуют — `--- TURN T4` → сразу `--- TURN T7`, ход с вложением `--file doc1–doc3` в логе идёт без заголовка `--- TURN` — low
- critical: **0** — `grep -E "FAIL|Error|panic|assert"` → 0 совпадений; chain `selftest exit=0 dur=552s`, первый полный прогон после skip 04:53

Регрессий vs предыдущих циклов (ITERATIONS) по коду не найдено, напротив — закрыты прежние провалы приёмки: `find_pii` в списке тулов и работает (2 лога подряд «отсутствует» → приёмка «слито ≠ доступно» пройдена); hint PR #64 live (`0 matching memories (2 match the filters)` — закрывает «live-приёмка hint» сессии 48); ретрив решения работает (T2 `1 matching memories`, T7 `2 matching memories` против 0 ×9 проходов); `groups_total`-расхождение не воспроизводится (T1 `16 = 2 + 14`, T12 `29 = 7 + 22`, `groups_total: 2` = число групп в `groups`). Новое: корень паттерна «байт-идентичный хвост 5 прогонов» (BUG-REPORT 20261012-000748/023539) — трейлер всегда писал новейшую по созданию сессию (00:07 и 02:35 → `ses_ed4cd38b3ffe`, созданная 11.10 16:41, ровно 2 assistant-строки в обоих логах), то есть прошлые приёмки «`cache_r>0` / `0 markers with pii=`» сделаны на чужой сессии.

### Паттерны
- `--continue` копит харнесс-сессию между прогонами: T1-промпт лежит в `ses_ed28a837effe` и в прогоне 05:56, и в 07:26 (до 02:35 — в `ses_ed788d98effe`); отсюда `total: 16` уже на T1 — 14 memory-вызовов из прошлого прогона (`search 5, overview 4, find_tool_calls 2, find_pii 1, details 1, put 1`)
- Выбор сессии трейлера детерминирован временем создания: 05:56 → `ses_ed271578fffe` (созд. 00:41), 07:26 → `ses_ed1d95007ffe` (созд. 06:27) — обе benchmark-сессии (ITERATIONS 47/48), не selftest
- Карьер-чёрнинг носителей продолжается: `rm -rf "$DOC_DIR"` в конце каждого прогона, сессия живёт дальше — в истории остаются пути в удалённый `tmp.l9fwT4AVP4`, glob-результаты устаревают
- Утечка маской держится: grep `NEEDLE\|Release ID\|CM-\|escalation` индексируется вместе с email/phone → `find_pii` находит (`call_bfd990989b87404cb28dda22` — email + phone), выдача редактируется (`[REDACTED:email]`); при этом сам лог содержит сырые email ×3 и phone ×4, а `run-mem-chain.sh` шаг 7 заливает selftest-логи в `gs://opencode-mem-artifacts/chain/<stamp>/`
- Компакция на прогоне работала стабильно: `memory-context.log` — 21 строка `session=ses_ed28a837effe … compacted=1 first_delivery=true protected_from=Infinity mark=14`; `protected_from=Infinity` доминирует в логе в целом (3855 из 4662 строк)
- Порядок цепочки: `release 07:26:07 exit=0 dur=43` → `selftest 07:35:19 exit=0 dur=552`; в `run-mem-chain.sh:82` закреплено «релиз идёт ДО selftest» против guard'а `prompt.txt:45` «Релиз — только после полного selftest»; SHA-сверка при этом сошлась: `fork at 965a967aa4` == тег `mem-v20261012-0725-965a967aa4` == бинарь `0.0.0-memory-context-v1-202610120425`
- Дрейф tip после прогона: к моменту разбора `origin/memory-context-v1` = `e9d8b11d3f` (PR #65), selftest и релиз — на `965a967aa4`, т.е. установленный бинарь отстаёт на 1 коммит

### Идеи (as is)
- Фиксировать session id прогона в самом логе и брать трейлер-метрики по нему — контекст: `session:` в логе указывает на benchmark-сессию
- Не писать метрики молча, если сессия прогона не найдена, — контекст: 11 чужих assistant-строк выглядят как метрики selftest
- Считать PII-маркеры по debug-логу/по месту, а не по `parts` — контекст: `LIKE '%pii=%'` = 0 по всей БД
- Подписать ход с вложением `--- TURN T5` — контекст: T4 → T7 без промежуточного заголовка
- Пер-прогонный temp-каталог + инвалидация устаревших путей в активной сессии — контекст: удалённый `tmp.l9fwT4AVP4` и устаревший glob
- Привести порядок шагов chain к guard'у (или guard к факту) — контекст: релиз 07:26:07 раньше selftest 07:26–07:35 при `prompt.txt:45`
- Redact PII в selftest-логах перед заливкой в GCS — контекст: сырые email/phone в шаримом логе

(Только констатация фактов из лога 07:26, цепочки 0725 и смежных артефактов; решения не предлагались.)

## BUG-REPORT 20261012-103636

Источник: `~/.opencode/scripts/selftest-logs/selftest-20261012-103636.log` (18576 байт, наибольший по mtime, 10 ходов T1–T10, `fork at 8f1b12e1b4`, `=== SELFTEST 20261012-103636 DONE ===`, skip-маркера нет), контекст: `release-current.md`, `chain-20261012-1036.log`, `chain-state.jsonl`, `releaser-20261012-103915.log`, `memory-context.log`, ITERATIONS (последние 10 записей).

### Проблемы
- Компактация = 0 — регрессия к прошлому полному прогону: `compaction: log_lines=0` / `0 max_compacted=0 final_mark=0` против `compaction: log_lines=8 max_compacted=2 final_mark=12` в `selftest-20261012-083306`; модель в T9: «полный вывод `read` doc2.md сохранён», «Добор через `get_tool_call_details` не потребовался» — retrieve-путь из-под компакт-маркера в прогоне не упражнялся — high
- Оценка 4/5 выставлена прогону без единого сжатия — T10 «принцип „сжимаем но ничего не прячем“ — оценка 4/5» при `max_compacted=0` — повтор критики сессии 52 о прогоне 07:26 — medium
- 3 дубля одного решения без supersedes + provenance — T5 «есть ещё две более ранние записи с тем же содержанием», T10 «3 дубля одного решения в памяти без автодедупа, и мой записан `authority=agent` без `decided_by`, хотя вы задали формулировку как принятое» — трение с приёмкой I3a «user/agent decisions cannot be conflated» — medium
- Ложный ноль на user-paste — третий раз — T3 `find_pii 0 tool calls with email PII` + `find_tool_calls 0 matching tool calls` → после `read` T6 `find_pii 1 tool calls with email PII` — открытый #66 — medium
- Phone-PII: отчёт T10 утверждает «`+7-999-123-45-67` … детектор не распознал — реальная дыра», но оба вызова прогона — `find_pii -> {"type":"email"}` (строки 215, 222), `type=phone` не запрашивался, `REDACTED:phone`=0 (в 083306 тоже 0; ×1 был только в 072607 на grep-носителе) — утверждение логом не подкреплено, покрытие phone не проверено — medium
- Сценарий без единого bash-вызова (хвост лога: 7 memory-тулов + 3 `read`) → `exit_code`/`failed`-фильтр из PR #69 (верхушка release notes) без live-покрытия; рекуррентная проблема «`status: completed` при упавшей команде» этим прогоном не перепроверялась — medium
- Memory-тулы невидимы в find — T7 «В индексе `find_tool_calls` только 3 вызова … поэтому „последних 5“ нет» при `get_tool_call_overview 16 tool calls across 1 tools`; T10 «агрегат есть, а провенанс вызова не восстановить» — известное #34/#48 — low
- Группировка агрегата — T10 «`groups_total=1` вместо ожидаемого больше — группируются только не-memory вызовы» — low
- Харнесс: строка компакции рвётся (`compaction: log_lines=0`↵`0 max_compacted=0 final_mark=0`) и предупреждение `compaction: NONE — сцена не спровоцировала компактацию` не вывелось — `run-selftest.sh:189` `grep -c … || echo 0` даёт «0\n0», сравнение с `"0"` не проходит — low
- Харнесс: doc1 не «плотный» — «он короткий (4 строки), needle в нём на виду» (T4) — low
- critical: **0** — `grep -E "FAIL|Error|panic|assert"` → 0 совпадений; T10 «Технических ошибок: ноль. Все 16 вызовов `completed`»

Регрессия vs предыдущих циклов (ITERATIONS) — одна содержательная: компакция 8/2/12 → 0/0/0; между прогонами слиты только PR #68 (`run.ts`) и #69 (find-tool-calls core/opencode, `prompt.ts` shellImpl exit-code, `run.ts` finish) — сам хук `MemoryContext.projectV1` (`prompt.ts:1316`) дифф не трогал, в `memory-context.log` для `session=ses_ed0f52c0bffe…` 0 строк при 5339 строках файла (debug пишется только при `compacted>0`, `memory-context.ts:291,379`). Не воспроизводятся: T5/T6-пробел заголовков (все 10 TURN на месте), «completed при упавшей команде» (упавших нет — bash в сценарии отсутствует), `groups_total` ≠ сумме `groups`. Держатся: hint PR #64 (`search_operational_memory 0 matching memories (4 match the filters)` — 2-й прогон подряд, в 083306 «(3 …)»), find_pii email (3-й прогон: 072607 → 083306 → 103636), ретрив решения (`search_operational_memory 3 matching memories` против 0 ×9), sentinel-привязка (`session: ses_ed0f52c0bffe… (source=sentinel)`).

### Паттерны
- Релизные теги не указывают на релизный код: все 8 `mem-*`-тегов origin → один коммит `0112a92c4` («chore(triage): add vimtor to inference issue owners (#52425)» = tip `origin/dev`), в имени тега другой SHA; releaser пишет `New commits: 46 (last tag: mem-v20261012-0847-e9d8b11d3f)` — guard `run-releaser.sh:62` («rev-list = 0 → релиз не нужен») структурно не срабатывает, работает только проверка имени тега по SHA (`:57`)
- `release-current.md` (входной артефакт): «Что нового (с mem-v20261012-0847-e9d8b11d3f)» = 40 строк (`head -40` при `LOG_RANGE=$LAST_TAG..HEAD` = весь бранч) при фактическом дельта `e9d8b11d3f..8f1b12e1b4` = 2 коммита
- Приёмочная тройка не сходилась на момент прогона: `acceptance: verify_sha=8f1b12e1b4 binary=0.0.0-memory-context-v1-202610120546` (бинарь = e9d8b11d3f, без PR #68/#69; в 083306 тоже mismatch `e9d8b11d3f` vs `…0425`); сам прогон шёл на коде форка (`bun run packages/opencode/src/index.ts` в worktree); дрейф снят через 4 минуты — релиз `mem-v20261012-1040-8f1b12e1b4` (07:40:50Z), бинарь `0.0.0-memory-context-v1-202610120739` установлен
- Порядок цепочки держится (фикс сессии 52): chain-state `{"step":"selftest","exit":0,"dur_s":159,"status":"ok"}` (10:39:15) → `{"step":"release","exit":0,"dur_s":99,"status":"ok"}` (10:40:54)
- Самый быстрый полный прогон из записанных: 159s против 280/286/552; трейлер 21 assistant-строка, все `cache_r>0`, суммарно $0.00885 (083306: $0.01179, 22 строки)
- Сырой PII остаётся в локальном логе (email в 4 строках, phone в 3), наружу уходит редактированная копия (`run-mem-chain.sh:141` `redact_copy`) — фикс сессии 52 держится
- Смежные сессии в том же окне пишут `[mem-context] … compacted=45/30 …`, у сессии прогона 0 строк — ноль событий компакции, а не обрыв записи
- Индекс прогона содержит только email-плейсхолдеры: `redacted_placeholders=5 email_placeholders=5` (083306: 4/4), phone-плейсхолдеров нет
- Скоупинг op-memory работает: запись T2 `scope=ST-20261012-103636`; дубли прошлых прогонов остаются без supersedes

### Идеи (as is)
- Индексировать реплики пользователя для find/find_pii — контекст: T3 0 → T6 1; T10 «нарушается на границе чат↔тулы» (уже issue #66)
- Расширять детекцию phone-форматов и покрытие больших выводов — контекст: T10 «отсутствие match ≠ отсутствие PII», в прогоне ни одного phone-запроса
- Возвращать memory-тулы в find/details или отдельный провенанс-view — контекст: «агрегат есть, а провенанс вызова не восстановить»
- Автодедуп/supersedes-предложение при повторной записи того же решения — контекст: 3 дубля, модель сама: «Могу перезаписать через `supersedes`»
- `decided_by=user` при записи решения, сформулированного пользователем — контекст: T5 «корректнее было `decided_by=user`»
- bash-ходы в сценарии selftest + проверки exit_code/failed — контекст: 0 bash-вызовов, PR #69 без live-покрытия
- Проверять релиз по target-SHA тега, а не по имени — контекст: 8 тегов на одном коммите `origin/dev`
- Не выставлять оценку «сжимаем», пока `max_compacted=0` — контекст: 4/5 на прогоне без единого маркера

(Только констатация фактов из лога 10:36, цепочки 1036 и смежных артефактов; решения не предлагались.)

## BUG-REPORT 20261012-123843

Источник: `~/.opencode/scripts/selftest-logs/selftest-20261012-123843.log` (95012 байт / 1083 строки, наибольший по mtime, **1 ход из 10** — только T1, `fork at df078835d5`, `DONE`-маркера и трейлеров нет), контекст: `release-current.md`, `chain-logs/chain-20261012-1238.log`, `chain-state.jsonl`, ITERATIONS (последние 10 записей).

### Проблемы
- Привязка сессии по sentinel провалена сразу после T1 — 9 ходов из 10 пропущены — последняя строка лога: `session: NOT-BOUND (sentinel 'ST-20261012-123843' не найден) — оставшиеся ходы пропущены` — high
- Цикл selftest↔release оборван: chain-state `{"step":"selftest","exit":70,"dur_s":68,"status":"failed"}` → `{"step":"release","exit":77,"dur_s":0,"status":"withheld"}`; chain-log `RELEASE withheld: selftest exit=70 (status=failed) — верификация прогона не пройдена` — high
- Приёмочных трейлеров нет вовсе: нет `=== SELFTEST 20261012-123843 DONE ===`, `compaction:`, `acceptance:`; 0 строк `assistant in=`/`cache_r=`/`cost=` (в 103636 — 21 такая строка + оба трейлера) — medium
- Высокий вопрос прошлого отчёта остался без ответа: `compaction:` в этом прогоне не выдавался вообще — сравнение 8/2/12 (083306) ↔ 0/0/0 (103636) продолжить нечем — medium
- Live-покрытие приёмки нулевое: выполнен только T1 («Вызови get_tool_call_overview и покажи результат»); find_pii/find/details/put/search/needle и оценка 4/5 не перепроверялись — streak «find_pii live в 3 прогона подряд» (072607 → 083306 → 103636) оборван — medium
- Установленный бинарь отстаёт от тестируемого tip: `installed binary: 0.0.0-memory-context-v1-202610120739` (= 8f1b12e1b4) против `fork at df078835d5`; релиз withheld → «слито ≠ доступно» на момент прогона не снято — medium
- Входной артефакт `release-current.md` устарел: mtime 10:40, заголовок `Что нового (с mem-v20261012-0847-e9d8b11d3f)` при выпущенном `mem-v20261012-1040-8f1b12e1b4`; `4e46d4773a` (#71) и `df078835d5` (#72) в файле отсутствуют (grep 0) — medium (хвост #70)
- Сборочные предупреждения осели в логе selftest: `(node:17046) [DEP0205] DeprecationWarning: module.register()`, 3× vite «dynamic import will not move module into another chunk», `The emitted file "assets/wasm-CG6Dc4jp.js.map" overwrites a previously emitted file of the same name`, `(!) Some chunks are larger than 500 kB` (index-BTRjfMPb.js 2740 kB, ghostty-web 1381 kB) — low
- Харнесс: selftest-часть = строки 1061–1083 (23 строки), остальные ~1040 строк — git/bun/vite-вывод; 95 KB против 15–19 KB у здоровых прогонов — low
- critical: **0** — `grep -E "FAIL|Error|panic|assert"` → 0 совпадений; case-insensitive — только DeprecationWarning/Warning-строки сборки

Регрессия vs предыдущих циклов (ITERATIONS): (1) первый провал selftest после двух последовательных успешных — 083306 и 103636 оба sentinel-bound, 10 ходов, `exit=0` (сессии 52/56), цепочка 1036 `status:ok` ×2; в chain-state это **единственные** записи с `status ≠ ok` (28 строк); (2) NOT-BOUND — 2-й случай из 19 логов (14 полных, 3 skip «fork dirty», 2 NOT-BOUND; первый — 082958, разобран сессией 53); контракт фикса сессии 52 держится (явный `exit 70`, а не тихое присоединение к чужой сессии), но сама привязка упала впервые после его внедрения; (3) улучшение — впервые ходы шли на бинаре из verify-слона с SHA-гейтом: `run binary: /tmp/opencode-mem-verify/packages/opencode/dist/opencode-darwin-arm64/bin/opencode (0.0.0-memory-context-v1-df078835d5f5-202610120938) — SHA совпал с fork at df078835d5` (в 103636 трейлер фиксировал mismatch `verify_sha=8f1b12e1b4` vs `binary=…0546`, #70b); (4) не воспроизводятся/не проверены: hint #64, дубли op-memory, оценка 4/5 — прогон до T10 не дошёл; (5) tip `df078835d5` = PR #72 (`fix(script): embed git SHA in preview build version (#72)`, git log форка) не упомянут в ITERATIONS/ISSUES/BUGS-REPORT (grep 0).

### Паттерны
- NOT-BOUND даёт одинаковый силуэт в обоих случаях (082958, 123843): ровно 1 ход, 0 строк `assistant in=`, нет DONE/compaction/acceptance — против 10 ходов и 21–22 трейлер-строк в здоровых 083306/103636
- Единственный из 19 логов со сборкой: `grep -l "vite v7" *.log` → 1 файл; в прогон ушли git fetch, `bun add` ×3 («Saved lockfile» ×3), vite 14.91s и 9 платформенных сборок — до этого все прогоны шли на установленном бинаре
- Sentinel доставлен модели: T1-ответ «Метка ST-20261012-123843 принята» — провал не на стороне промпта, а на стороне поиска в БД
- Причина диагностирована постфактум в скрипте (mtime 12:43, прогона — 12:39): комментарий «бинарь с channel=memory-context-v1 пишет в opencode-memory-context-v1.db, source-запуск (channel=local) — в opencode-local.db, сток — в opencode.db → ищем sentinel во всех opencode*.db (issue #70, прогон 123843)»; в версии, гонявшей прогон, перебор был только `opencode-local.db` + `opencode.db` (git diff chain/run-selftest.sh, uncommitted) — текст ошибки в логе `не найден`, в текущей версии — `не найден в opencode*.db`
- Гард «релиз только после полного selftest» отработал: release exit=77, dur_s=0 (chain-log `RELEASE withheld`); skip-контракт (exit 78) в этот раз не понадобился
- Статус-строка `⚙ get_tool_call_overview 1 tool calls across 0 tools` байт-в-байт как в 103636 — memory-тулы считаются в `total`, не в `groups` (#48), поведение без изменений
- PII-хвост: сырых email/phone в логе нет (T3 не выполнялся), `REDACTED`=0; 3 совпадения regex на email — имена пакетов (`installed @opentui/core@0.4.5`, `@parcel/watcher@2.5.1`, `@ff-labs/fff-bun@0.9.4`)
- В шапке лога триада распадается на две строки: `installed binary: …202610120739` (строка 9) и `fork at df078835d5` (строка 8) — расхождение читается только по ним, acceptance-трейлер его не зафиксировал

### Идеи (as is)
- Автоповтор selftest при NOT-BOUND (или явный rerun-шаг) — контекст: 68 s, весь цикл withheld; 2 случая из 19
- Перебирать все `opencode*.db` при поиске sentinel (правка уже появилась в скрипте после прогона) — контекст: расхождение канала БД собранного бинаря и списка поиска; в логе — `не найден` без указания БД
- Печатать путь/канал БД до старта ходов, а не только в строке успеха — контекст: при провале канал, куда смотрел скрипт, из лога не восстановить
- Выносить вывод сборки из selftest-лога (отдельный лог или однострочное саммари) — контекст: ~1040/1083 строк — vite asset list, приёмочные строки тонут в конце
- Обновлять `release-current.md` на каждом release-шаге и сверять заголовок с последним тегом — контекст: заголовок 0847 при выпущенном 1040, #71/#72 отсутствуют
- Печатать acceptance-строку (`verify_sha`/`binary`/`installed`) и при провале привязки — контекст: трейлер не выдан, расхождение installed/fork восстанавливалось вручную из строк 8–9 и 1060

(Только констатация фактов из лога 12:38, цепочки 1238 и смежных артефактов; решения не предлагались.)

## BUG-REPORT 20261020-042801

Источник: `~/.opencode/scripts/selftest-logs/selftest-20261020-042801.log` (14 271 байт / 186 строк — наибольший по mtime в `selftest-logs/`), контекст: `release-current.md`, `selftest-last.json`, `chain-logs/chain-20261020-1623.log`, `build-logs/build-20261020-162342.log`, логи `selftest-20261020-022040` и `013057`, ITERATIONS (последние 10 записей), HANDOFF-2026-10-20.

### Проблемы
- Маркер ужатия не совпадает с показанным фрагментом: окно открывается обрезанной строкой — `[showing lines 2976-3000 of 3000; full output saved to …]` (стр. 36) против первой видимой строки `ig-output-line-2975 xxxxx…` (стр. 10, нет ведущей `b`); сам сохранённый файл цел — `SAVED OUTPUT == SOURCE (byte identical)` (стр. 68), т.е. режется байтовый хвост, а границы строк считаются отдельно — medium
- Вывод команды склеен со следующим заголовком там, где нет завершающего `\n`: `big-output-line-2999 xxxxx…xxx== byte/line stats ==` (стр. 55) и `NEEDLE-DOC: … CM-5581-A.--- grep NEEDLE ---` (стр. 120) — low
- В лог не попадает вывод read/grep-тулов — остались только следы вызовов: `→ Read /var/folders/…/tmp.QABap4BXVP/doc.md` (стр. 115) и `✱ Grep "big-output-line-2999" in … · 1 match` (стр. 141) без содержимого, тогда как вывод bash сохранён целиком; приёмочные `check: full output file present and complete — ok` (стр. 184) и `check: needle retrieved — ok (CM-5581-A)` (стр. 185) из лога не подтверждаются — medium
- Гейт selftest не считает ненулевой код хода провалом: в предыдущем прогоне того же дня `--- TURN T1 exit=1`, `--- TURN T2 exit=1`, `--- TURN T3 exit=1` с `Error: invalid ladder_cache_variant` (`selftest-20261020-022040.log`), а лог всё равно закрыт `=== SELFTEST 20261020-022040 DONE ===` и четырьмя `check: … — ok` (стр. 94–97); в текущем прогоне T1–T5 exit=0, дефект не проявился — high
- Текущий tip форка приёмки не имеет: цикл 16:23 упал на сборке — `[2026-10-20 16:24:20] STEP build END exit=70 dur=38s status=failed`, `SELFTEST withheld: build exit=70 (status=failed) — кандидата нет`, `RELEASE withheld: selftest exit=77 (status=failed) — верификация прогона не пройдена`; build-лог: `Error writing standalone module graph: Io` / `error: failed to write compiled executable opencode` / `BUILD FAILED — кандидата нет` (tip `260abb8810eb`) — разбираемый лог закрывает прошлого кандидата `7a12f66b4abc` — high
- Расхождение candidate/installed внутри прогона не проверяется ни одним check'ом: `installed binary: opencode v0.0.0-fork-at-6d9423b155` (стр. 4) против `candidate: /Users/vova/.opencode/candidates/7a12f66b4abc/opencode (7a12f66b4abc)` (стр. 2) и `candidate_sha=7a12f66b4abc` в трейлере (стр. 186); порядок selftest→release соблюдён (установка 04:31 после прогона 04:28), но лог этого не отмечает — low
- critical: **0** — `grep -E "FAIL|Error|panic|assert"` по логу → 0 совпадений (case-insensitive — тоже 0)

Регрессии vs предыдущих циклов: ITERATIONS (последние 10 записей) обрывается 2026-10-12 на v1-линии (`selftest fail 20261012-123843`, exit=70, NOT-BOUND, 1/10 ходов, релиз withheld) — сравнения с v2-линией форка там нет, база сравнения — логи `selftest-logs` за 20 октября. (1) Улучшение: 022040 (`T1–T3 exit=1`, `invalid ladder_cache_variant`) → 042801 (`T1–T5 exit=0`, стр. 110/137/152/174/180, `selftest-last.json status=ok`) — дефект маски снят (HANDOFF §A, PR #165). (2) Ухудшение: 042801 — первый v2-прогон без метрик памяти и без длительности, а следующий цикл (16:23) до selftest не дошёл вовсе (build exit=70). (3) Привязка sentinel в этом прогоне есть: `session: ses_selftest-20261020-042801 (bound in /Users/vova/.local/share/opencode/opencode.db)` (стр. 111) — контракт NOT-BOUND не повторён. (4) Не проверялись: hint, дубли op-memory, оценка 4/5 — в v2-прогоне этих метрик нет.

### Паттерны
- Пять ходов, все `exit=0`, ни одного `FAIL|Error|panic|assert` — прогон чистый (стр. 110/137/152/174/180; grep → 0 совпадений)
- Усечение v2 ведёт себя как заявлено: 25 строк в окне, полный вывод на диске (244 889 Б), `cmp` — побайтово идентичен исходнику; grep по сохранённому файлу доступен — T3 нашёл `big-output-line-2999` на строке 3000 (стр. 141–149)
- `wc -l` ≠ числу строк на обоих фикстурах (нет завершающего `\n`): `2999 /var/…/big.txt` (стр. 39) при 3000 строках и `401 /var/…/doc.md` (стр. 118) при needle на строке 402 (стр. 121) — модель оба раза опиралась на номера строк, а не на `wc -l`
- Тестовые данные пишутся в общий со стоком канал: `check: data namespace shared with stock — ok (/Users/vova/.local/share/opencode/opencode.db)` (стр. 5), сессия `ses_selftest-20261020-042801 (bound in …opencode.db)` (стр. 111); каталог сохранённых выводов `~/.local/share/opencode/shell/6076e6713333c0b0555eb63f25cd53d74bcf1246/` — тот же, что в прогоне 022040, изоляции прогонов нет
- Фикстуры после прогона не остались: каталога `/var/folders/…/tmp.QABap4BXVP/` нет
- PII в логе нет: email-совпадений 0, token-подобных 0, phone-подобных 1 — это `started_ms=1792459681000` (стр. 186); в логе остаются только абсолютные пути с домашним каталогом (`/Users/vova/…`)
- Ходы T1–T4 шли на `ladder/build`, проверка дефолта — на `mem-gpt/build` (`default model: mem-gpt/build`, стр. 175; `check: default model served — ok (mem-gpt/build)`, стр. 181): проверяется дефолт пользователя, а не путь ладдера форка
- Модель перепроверяла факты через bash, а не через read/grep, чей вывод в лог не попал (стр. 117–121, 141) — приёмочные check'ы опираются на артефакты, которых в логе нет
- Инструментальная асимметрия (отчёт T4, стр. 173): read отдал 402-строчный `doc.md` целиком, shell на 3000 строк режет до 25 — на больших объёмах остаётся только путь из маркера
- В трейлере только `started_ms=1792459681000` (стр. 186) — длительности нет, тогда как ITERATIONS для циклов 12.10 фиксировал `dur=68s` / `dur=159s`; по `selftest-last.json` (`checked_at 2026-10-20T01:29:35Z`) прогон занял ~94 c
- Ни одного замера памяти (`find_pii`, `compaction: log_lines=`, `cache_r=`) и ни одной оценки 4/5 — в прогоне только 4 артефактных check'а
- Сбой сборки 16:23 совпал с заполнением тома: `/System/Volumes/Data 228Gi 188Gi 788Mi 100%` (`df -h`); причина в build-логе не названа — деталь ошибки обрезана до `Error writing standalone module graph: Io`

### Идеи (as is)
- Указывать в маркере ужатия фактические границы показанного фрагмента (или не резать первую строку окна пополам) — контекст: `showing lines 2976-3000` против `ig-output-line-2975`
- Ставить перевод строки между выводом команды и следующим заголовком — контекст: `…xxx== byte/line stats ==` и `CM-5581-A.--- grep NEEDLE ---`
- Класть в лог вывод read/grep-тулов (хотя бы первые строки) — контекст: `check: needle retrieved` / `full output file present and complete` из лога не подтверждаются
- Считать ненулевой код хода провалом прогона — контекст: прогон 022040 (T1–T3 exit=1) закрыт как DONE/ok; в 042801 T1–T5 exit=0
- Писать рядом с `started_ms` длительность (`dur`) — контекст: в трейлере её нет, для сравнения циклов длительность восстанавливается только по `selftest-last.json`
- Явно отмечать в логе ожидаемость расхождения candidate/installed (или добавить check на совпадение) — контекст: `installed … 6d9423b155` против `candidate … 7a12f66b4abc` в одном прогоне
- Сохранять полный текст ошибки сборки в build-логе — контекст: `Error writing standalone module graph: Io` обрывается на 41 символе, и заполнение тома на 100% из лога не читается
- Класть рядом с логами сводку по прогонам (sha12/статус/dur/счётчики) — контекст: `selftest-last.json` хранит только последний прогон, для сравнения циклов нужен grep по каталогу

(Только констатация фактов из лога 04:28, логов цепочки/build 20.10 и смежных артефактов; решения не предлагались.)

## BUG-REPORT 20261020-164201

Источник: `~/.opencode/scripts/selftest-logs/selftest-20261020-164201.log` (14 186 байт / 182 строки — наибольший по mtime в `selftest-logs/`), контекст: `release-current.md`, `selftest-last.json`, `candidate-current.json`, логи `selftest-20261020-163531` и `042801`, `run-selftest.sh`, `packages/core/src/{shell,tool-output}.ts` форка, ROADMAP (cycle 8), ITERATIONS (последние 10 записей), BUGS-REPORT `20261020-042801`.

### Проблемы
- Приёмочный check на needle ищет строку по всей общей БД, а не в сообщениях проверяемой сессии: `strings -a "$SESSION_FOUND_IN" "$SESSION_FOUND_IN-wal" | grep -q "$NEEDLE"` (`run-selftest.sh:224`), тогда как соседний check на маркер ужатия скоупится сессией (`where session_id='$SESSION'`, стр. 202). В `opencode.db` строка `CM-5581-A` встречается в **24 разных сессиях** (`select count(distinct session_id) … like '%CM-5581-A%'` → 24), т.е. check `check: needle retrieved — ok (CM-5581-A)` (стр. 181) проходит и без ретрива в текущем прогоне — high
- Check «full output file present and complete» не проверяет полноту: это единственный `grep -q "big-output-line-2999"` по файлу (`run-selftest.sh:218`) — ни байт-идентичности, ни числа строк; в этом прогоне лог не содержит ни одного байтового замера (`grep -c "byte/line stats\|byte identical"` → 0 против 4 в прогоне 042801) — medium
- Маркер ужатия не совпадает с показанным фрагментом: окно объявлено как `[showing lines 2976-3000 of 3000; …]` (стр. 36), а первая видимая строка — обрезанный байтовый хвост `ig-output-line-2975 xxxxx…` (стр. 10, нет ведущей `b`); механизм — окно читается по байтам от конца (`output(info.id, { cursor: latest.size - maxBytes })`, `shell.ts:239`), поэтому первая строка окна всегда частичная — medium
- Вывод read/grep-тулов в лог не попадает: остались только следы вызовов `→ Read var/folders/…/tmp.tPxJLxDcrM/doc.md` (стр. 103) и `✱ Grep "big-output-line-2999" in … · 1 match` (стр. 118) без содержимого — приёмочные `check: full output file present and complete` (стр. 180) и `check: needle retrieved` (стр. 181) из лога не подтверждаются — medium
- Расхождение candidate/installed внутри прогона не проверяется ни одним check'ом: `installed binary: opencode v0.0.0-fork-at-7a12f66b4abc` (стр. 4) против `candidate: /Users/vova/.opencode/candidates/260abb8810eb/opencode (260abb8810eb)` (стр. 2) и `candidate_sha=260abb8810eb` в трейлере (стр. 182); расхождение уже заведено в ROADMAP как (a) low («внутри прогона `candidate=260abb8810eb` ≠ `installed=7a12f66b4abc` — расхождение не проверяется ни одним check'ом»), в этом прогоне оно воспроизведено в третий раз подряд — low
- critical: **0** — `grep -E "FAIL|Error|panic|assert"` по логу → 0 совпадений (case-insensitive — тоже 0)

Регрессии vs предыдущих циклов: ITERATIONS (последние 10 записей) обрывается 2026-10-12 на мёртвой v1-линии (`selftest fail 20261012-123843`, exit=70, NOT-BOUND, 1 ход из 10) — сравнения с v2-линией там нет, база сравнения — логи `selftest-logs` за 20 октября. (1) Регресс к 042801: лог 164201 потерял байтовые замеры, которые были в 042801 (`== byte/line stats ==`, `SAVED OUTPUT == SOURCE (byte identical)`, стр. 55–68 того лога) — при том же тексте хода T1 (промпт идентичен, отличается только имя ветки `v2-base`→`main`), т.е. модель в этот раз свёрку не выполнила; check «complete» остался единственным `grep` — medium. (2) Без ухудшения: T1–T5 `exit=0` (стр. 98/114/148/170/176), sentinel привязан `session: ses_selftest-20261020-164201 (bound in …/opencode.db)` (стр. 99), needle найден — контракт NOT-BOUND не повторён. (3) Дефект ужатия не снят: побайтовый отпечаток `ig-output-line-2975` + `showing lines 2976-3000 of 3000` идентичен в трёх подряд прогонах (042801, 163531, 164201) при разных кандидатах (`7a12f66b4abc` → `260abb8810eb`) — воспроизводится на новой сборке. (4) Плацдарм тот же, что и в 042801: `data namespace shared with stock — ok (/Users/vova/.local/share/opencode/opencode.db)` (стр. 5) — общая БД со стоком, изоляции прогонов нет. (5) Не проверялось (как и раньше): hint, дубли op-memory, оценка 4/5, метрики памяти — в прогоне ни одного memory-тула.

### Паттерны
- Пять ходов, все `exit=0`, ни одного `FAIL|Error|panic|assert` — прогон чист (стр. 98/114/148/170/176; grep → 0 совпадений)
- Усечение ведёт себя как заявлено: полный вывод на диске целиком — `sh_1598ced01001l9cV1rxeuMVTog.out`, 244 889 Б, `wc -l` = 2999 при 3000 строках (`head -3` → `big-output-line-0…2`, `tail -2` → `…2998`/`…2999`), `grep -c "big-output-line-2999"` = 1; T3 нашёл строку через grep по этому файлу (стр. 118–144) — «сжали, но ничего не прячем» подтверждено
- Расхождение `wc -l` (2999) и маркера («of 3000») объясняется отсутствием завершающего `\n` в фикстуре: `total = newlines + (endsWith("\n") ? 0 : 1)` (`shell.ts:244`) — это свойство фикстуры, не потеря строки; модель отметила расхождение сама (стр. 165) и сверилась через `head`/`tail`
- Инструментальная асимметрия (отчёт T4, стр. 166): read отдал все 402 строки `doc.md` без маркера ужатия, bash режет 3000 строк до 25 — и маркеры разной формы: shell `[showing lines 2976-3000 of 3000; …]` (`shell.ts:247`) против tool-output `[showing lines 1-N of M; …]` (`tool-output.ts:92`), у которых ещё и разная сторона отсечения (хвост против головы)
- Тестовые данные пишутся в общий со стоком канал: `check: data namespace shared with stock — ok (/Users/vova/.local/share/opencode/opencode.db)` (стр. 5), сессия `ses_selftest-20261020-164201 (bound in …opencode.db)` (стр. 99); каталог сохранённых выводов `~/.local/share/opencode/shell/e22c0befcd3aab577c593974d56decf884468691/` — тот же, что в прогоне 163531 (строка 7 младшего лога), изоляции прогонов нет
- Фикстуры после прогона не остались: каталога `/var/folders/…/tmp.tPxJLxDcrM/` нет (cleanup `rm -rf "$DOC_DIR"`, `run-selftest.sh:245`)
- Накопление артефактов: `run-selftest.sh` чистит только фикстуры, файлы `~/.local/share/opencode/shell/**/*.out` не удаляются — 414 файлов / 2,82 МиБ в 53 сессионных каталогах, 9 из них по 244 889 Б (по одному на каждый прогон `cat big.txt`); при этом `/System/Volumes/Data` = 99% (228Gi/185Gi/3.4Gi), а сборка 16:23 уже падала на заполненном томе
- PII в логе нет: email-совпадений 0, token-подобных 0, phone-подобных 2 — это `started_ms=1792503721000` и `20261020-164201`; в логе остаются только абсолютные пути с домашним каталогом (`/Users/vova/…`)
- Ходы T1–T4 шли на `ladder/build`, проверка дефолта — на `mem-gpt/build` (`default model: mem-gpt/build`, стр. 171; `check: default model served — ok (mem-gpt/build)`, стр. 177): проверяется дефолт пользователя, а не путь ладдера форка
- Поведение модели на одном и том же промпте нестабильно: в 042801 после ужатия модель сама выполнила `wc -c`/`awk`-статистику и `cmp -s` (байт-идентичность), в 164201 — только `wc -l`/`head`/`tail` (стр. 38–45); приёмочная полнота от этого зависит, а check её не проверяет
- В трейлере только `started_ms=1792503721000` (стр. 182) — длительности нет; по `selftest-last.json` (`checked_at 2026-10-20T13:46:45Z`) прогон занял ~284 c, тогда как ITERATIONS для циклов 12.10 фиксировал `dur=68s` / `dur=159s`
- Ни одного замера памяти (`find_pii`, `compaction: log_lines=`, `cache_r=`) и ни одной оценки 4/5 — в прогоне только 4 артефактных check'а
- Ход T1 сформулирован как «выведи результат как есть», что при текущем ужатии невыполнимо: полные 3000 строк в контекст не попадают, модель отвечает «вывод cat (как вернулся из bash-тула, дословно)» и перечисляет 24 усечённые строки (стр. 50–78) — сценарий не проверяет дословность, а гейт на это не смотрит

### Идеи (as is)
- Скоупить check на needle так же, как check на маркер (по `session_id`), либо искать в сообщениях текущей сессии, а не во всей общей БД — контекст: `grep -q "$NEEDLE"` по файлу БД + WAL (`run-selftest.sh:224`) при 24 сессиях с этим же needle
- Дополнить check «full output file present and complete» сравнением с исходником (байты/строки), а не только `grep` последней строки — контекст: стр. 218 скрипта и отсутствие байтовых замеров в этом логе
- Указывать в маркере ужатия фактические границы показанного фрагмента (или не резать первую строку окна пополам) — контекст: `showing lines 2976-3000` против `ig-output-line-2975`; механизм — байтовое окно от конца файла (`shell.ts:239`)
- Класть в лог вывод read/grep-тулов (хотя бы первые строки) — контекст: `check: needle retrieved` / `full output file present and complete` из лога не подтверждаются
- Явно отмечать в логе ожидаемость расхождения candidate/installed (или добавить check на совпадение) — контекст: `installed … 7a12f66b4abc` против `candidate … 260abb8810eb` в одном прогоне; в ROADMAP уже заведено как (a) low
- Писать рядом с `started_ms` длительность (`dur`) — контекст: в трейлере её нет, для сравнения циклов длительность восстанавливается только по `selftest-last.json`
- Чистить `~/.local/share/opencode/shell/**/*.out` после прогона (или хранить лимит) — контекст: 414 файлов / 2,82 МиБ, 9 × 244 889 Б от прогонов `cat big.txt`, том при этом на 99%
- Сделать формулировку хода T1 «выведи результат как есть» совместимой с ужатием (либо явно проверять дословность полного вывода) — контекст: при ужатии модель отвечает усечённым фрагментом, сценарий «как есть» не исполнен

(Только констатация фактов из лога 16:42, смежных логов за 20 октября, исходников форка и скриптов прогона; решения не предлагались.)

## BUG-REPORT 20261020-191311

Источник: `~/.opencode/scripts/selftest-logs/selftest-20261020-191311.log` (1 314 байт / 14 строк — наибольший по mtime), контекст: `~/.local/share/opencode/log/opencode.log` (строки 86610–86617), общая БД `~/.local/share/opencode/opencode.db`, `release-current.md` (16:47), `selftest-last.json`, `candidate-current.json`, `run-selftest.sh`, логи 18:38 / 16:42 / 16:35, `packages/core/src/database/migration/20261020143020_volatile_mister_fear.ts`, ITERATIONS (последние 10 записей).

### Проблемы
- Кандидат `03349ef2b2ed` (PR #179, порт op-memory) не поднимается: миграция `mem_record` падает на уже существующей таблице — лог прогона: «Error: Standalone server exited before reporting readiness» (стр. 7), «--- TURN T1 exit=1» (стр. 13); причина в `opencode.log`: `message="database migration started" migration=20261020143020_volatile_mister_fear role=server` → `level=ERROR … message="cli process failed" cause="Cause([Die(SQLiteError: table \`mem_record\` already exists)])"` (`timestamp=2026-10-20T16:13:14.694Z`) — critical
- Прогон оборвался на первом ходе, приёмка не получена — «session: NOT-BOUND (sentinel 'ST-20261020-191311' не найден в opencode*.db[-wal]) — оставшиеся ходы пропущены» (стр. 14); в логе нет ни «=== SELFTEST 20261020-191311 DONE ===», ни строки `acceptance:`, ни 4 артефактных check'ов (в логе 18:38 — все на месте) — critical
- Причина падения в лог прогона не попала — прогон содержит только симптом и стек из `$bunfs/root/chunk-*.js` (стр. 8–12); диагностика лежит в глобальном `~/.local/share/opencode/log/opencode.log` (40 МБ) и была найдена вручную по временной метке — high
- Состояние приёмки осталось зелёным после провала — `selftest-last.json` не обновлён (mtime 18:40, `sha12: 260abb8810eb`, `"status": "ok"`); провал 19:13 не записан ни в `selftest-last.json`, ни в `candidate-current.json` (в нём только `built_at: 2026-10-20T16:13:11Z`) — high
- Проверенный кандидат ≠ текущий релиз — «candidate: /Users/vova/.opencode/candidates/03349ef2b2ed/opencode (03349ef2b2ed)» (стр. 2) против «installed binary: opencode v0.0.0-fork-at-260abb8810eb» (стр. 4); `release-current.md` (16:47) описывает `260abb8810eb` — medium
- Фикстуры прогона не убраны на пути провала — `DOC_DIR` удаляется только в конце успешного пути (`rm -rf "$DOC_DIR"`, `run-selftest.sh:245`), а `fail()` выходит раньше (стр. 42); остался каталог `/var/folders/1m/…/T/tmp.nj6gDeajBa/` с `big.txt` (244 889 Б) и `doc.md` (22 358 Б) от 19:13 — medium
- Провал не внесён в трекер — `grep "20261020-191311\|03349ef2b2ed"` по `ITERATIONS.md` / `ISSUES.md` / `ROADMAP.md` → 0 совпадений — medium
- Прочих `FAIL|Error|panic|assert` нет: `grep -cE "FAIL|Error|panic|assert"` по логу → 1, и это сама строка ошибки старта (стр. 7) — critical: 0 дополнительных

Регрессии vs предыдущих циклов: (1) прогон 18:38 (candidate == installed == `260abb8810eb`) — полный: T1–T5 `exit=0`, «=== SELFTEST 20261020-183819 DONE ===», 4/4 check'а ok, строка `acceptance:` есть; прогон 19:13 (candidate `03349ef2b2ed` = tip `main` после PR #179) — падение на T1. Дельта — только смена кандидата: харнесс, общая БД, фикстуры и модель те же. (2) ITERATIONS (последние 10 записей) фиксирует обратное состояние: «build ok (exit=0, 47s, SHA `260abb8810eb`) → selftest **pass** (exit=0, 284s, T1–T5 exit=0, sentinel привязан, 4/4 артефактных check'а ok) → release ok (exit=0, 37s)» и порт описан как слитый («PR #179 смержен squash `03349ef2b2`») — прогон 19:13 опровергает «слито = поднялось». (3) Дефекты ужатия/маркера (дефект `ig-output-line-2975`, отсутствие байтовых замеров) в этом прогоне не проверялись — до T1 дело не дошло.

### Паттерны
- Миграция не идемпотентна к общей БД: в `opencode.db` таблица `mem_record` уже есть (31 запись, `time_created` 2026-10-14 13:21 … 2026-10-15 06:17, v1-эпоха), в таблице `migration` стоит v1-id `20261011235047_mem_record` (`time_completed` 2026-10-13 19:30:35), а нового id `20261020143020_volatile_mister_fear` там нет; файл новой миграции делает `CREATE TABLE \`mem_record\`` без `IF NOT EXISTS` (`packages/core/src/database/migration/20261020143020_volatile_mister_fear.ts:9`) → каждый старт кандидата на этой машине повторяет `CREATE TABLE` и умирает
- Плацдарм общий со стоком: «check: data namespace shared with stock — ok (/Users/vova/.local/share/opencode/opencode.db)» (стр. 5) — именно эта БД хранит остатки v1-линии, с которыми конфликтует новая миграция
- Трекер миграций и репозиторий разошлись: v1-файла миграции в v2-репозитории нет (`ls packages/core/src/database/migration/ | grep -i mem` → 0 совпадений), а его id остался в `migration` общей БД
- `candidate ≠ installed` в 8 из 10 последних прогонов (совпали только 02:01 и 18:38) — расхождение, заведённое в ROADMAP как (a) low, воспроизводится системно
- Объём в работе больше слитого: verify-clone HEAD = `03349ef2b2ed`, work-clone HEAD = `2eb7ad4531` «port operational memory store and tools to v2» (не слит) — тестировался меньший объём, чем в работе
- Артефакты ужатых выводов копятся: `~/.local/share/opencode/shell` — 490 `.out` / 4,5 МиБ против 414 / 2,82 МиБ в BUG-REPORT `20261020-164201` (тот же дефект, рост за цикл)
- Место на томе есть: `/System/Volumes/Data` — 97%, 6,7 GiB свободно (было 99% / 3,4 GiB в отчёте 164201); падение 19:13 не вызвано заполнением диска
- PII в логе нет: лог содержит только пути с домашним каталогом (`/Users/vova/…`), sentinel `ST-20261020-191311` и SHA — совпадений e-mail/token/phone

### Идеи (as is)
- Складывать в лог прогона причину падения старта (хвост серверного лога / stderr) — контекст: `SQLiteError: table mem_record already exists` нашлась только вручную в `opencode.log` по метке времени
- Писать в `selftest-last.json` и провал (sha, sentinel, код выхода, причина), а не только успех — контекст: после провала файл остался с `"status": "ok"` за 18:40
- Развести «миграция выполнена» и «таблица уже есть»: проверять наличие объекта перед `CREATE TABLE` — контекст: `mem_record` в общей БД с v1-эпохи, новая миграция создаёт безусловно
- Убирать фикстуры на любом выходе (cleanup в `fail`/`skip`) — контекст: 4 оставшихся tmp-каталога с `big.txt`/`doc.md` (960 КБ суммарно), один — от провалившегося прогона 19:13
- Вносить провал прогона в ISSUES/ITERATIONS с SHA кандидата — контекст: ST-20261020-191311 не упомянут ни в одном файле трекера
- Добавить гейт «candidate == installed» и помечать расхождение в логе — контекст: 8 из 10 прогонов; `release-current.md` описывает не тот SHA, что проверялся
- Чистить `~/.local/share/opencode/shell/**/*.out` по лимиту/возрасту — контекст: 490 файлов / 4,5 МиБ

(Только констатация фактов из лога 19:13, `opencode.log`, общей БД, смежных логов и исходников форка; решения не предлагались.)

## BUG-REPORT 20261020-204034

Источник: `~/.opencode/scripts/selftest-logs/selftest-20261020-204034.log` (229 байт / 3 строки — наибольший по mtime), контекст: `~/.opencode/scripts/selftest-stdout.log` (хвост), `~/.opencode/scripts/chain-state.jsonl`, `~/.opencode/scripts/candidate-current.json`, `~/.opencode/scripts/selftest-last.json`, `~/.opencode/scripts/build-logs/build-20261020-211525.log`, `~/.opencode/scripts/release-current.md`, `~/.local/share/opencode/log/opencode.log` (окно 17:40–17:55Z), reflog verify/work-клонов, `run-selftest.sh`, `run-build.sh`, ITERATIONS (последние 10 записей), BUG-REPORT `20261020-191311`.

### Проблемы
- Прогон упал на первом же гейте, до единого хода: лог из 3 строк, обрыв на строке 3 — «verify-клон на 256e068a4d59, а кандидат на 03349ef2b2ed — проверялось бы не то» (`run-selftest.sh:60`, ветка `fail` → exit 70); в логе нет ни `candidate version`, ни `installed binary`, ни `check: data namespace`, ни T1–T5, ни «=== SELFTEST 20261020-204034 DONE ===», ни строки `acceptance:` — critical
- Кандидат устарел относительно репозитория: `candidate: /Users/vova/.opencode/candidates/03349ef2b2ed/opencode (03349ef2b2ed)` (стр. 2) — PR #179, `built_at 2026-10-20T16:13:11Z`; verify-клон HEAD = `256e068a4d59` «fix(core): make the mem-record migration idempotent (#183)», work-клон HEAD = `b5535aff9ede` (#187). Фикс причины прошлого провала (#182/#183, идемпотентная миграция `mem_record`) слит в `main`, но в бинарь-кандидат не попал — critical
- `selftest-last.json` остался зелёным после двух подряд красных прогонов: mtime 18:40:34 MSK, `sha12: 260abb8810eb`, `"status": "ok"`, `session: ses_selftest-20261020-183819`; ни провал 19:13 (exit 70), ни провал 20:40 (exit 70) файл не обновили — `run-selftest.sh` пишет его только на успешном пути (`run-selftest.sh:231-241`) — high
- Прогон 20:40 не попал в журнал шагов цепочки: в `chain-state.jsonl` есть только `20261020-1913` (`build exit=0`, `selftest exit=70 failed`, `release exit=77 withheld`) и `20261020-2115` (`build exit=78 skipped`, `selftest exit=77 withheld`, `release exit=77 withheld`); записи о прогоне 20:40 (exit 70) нет — high
- Цепочка заблокирована диском: сборка 21:15 пропущена — «BUILD SKIPPED: мало места на диске (0 GiB свободно, нужно ≥5 GiB) — сборка упала бы на 'standalone module graph: Io'» (`build-20261020-211525.log`, `run-build.sh:37-42`, exit 78); `/System/Volumes/Data` — 100%, 678 MiB свободно (в отчёте 19:13 было 97% / 6,7 GiB) — high
- Параллельный `--standalone` на общей БД: в 20:40:33–20:40:34 одновременно стартовали живая приёмка (`ses_acc_a`, бинарь из verify-клонa `.../opencode-mem-verify/packages/cli/dist/cli-darwin-arm64/bin/opencode`, mtime бинаря 20:40) и selftest (`ses_selftest-20261020-204034`, бинарь-кандидат) — обе сессии пишут в общий `opencode.db` (WAL) — medium
- MCP-серверы приёмки не поднялись: 6 подряд `mcp connect failed … NotFound: ChildProcess.spawn (node …)` в 17:40:34.400–17:40:34.408Z — `engineering-checklists`, `web-navigation`, `search-skills`, `js-ts-code`, `engineering-skills` (+ ещё один в том же окне) — medium
- `release-current.md` (16:47) описывает SHA `260abb8810eb` — на 4 коммита позади `main` (`b5535aff9ede`); установленный бинарь тот же `260abb8810eb`, т.е. релиз-ноты и машина отстают от репозитория на 2 merges (#180, #183) и 1 PR (#187) — medium
- PII в логе прогона нет: 3 строки — путь к кандидату, SHA `03349ef2b2ed` и сообщение гейта; совпадений e-mail/token/phone — low

Регрессии vs предыдущих циклов: (1) прогон 18:38 (`candidate_sha=260abb8810eb`, `installed=opencode v0.0.0-fork-at-260abb8810eb`, T1–T5 `exit=0`, 4/4 check'а ok, `acceptance:` есть) → прогон 20:40 (3 строки, exit 70, ни одного хода): деградация не в харнессе, а в том, что к моменту прогона разъехался SHA кандидата и verify-клонa. (2) ITERATIONS (последние 10 записей) фиксирует: «PR #183 … merge `256e068a4d`; проверено на реальной базе: сервер поднимается, `/api/session` 200, строка миграции записана, 31 строка `mem_record` цела» и «живая приёмка ПРОЙДЕНА» — обе проверки сделаны на бинаре из verify-клонa, тогда как selftest-гейт сравнивает его с кандидатом `03349ef2b2ed` (без #183) и падает; «слито» ≠ «проверено кандидатом». (3) ITERATIONS от 20:10–21:10 (запись `bug` про #182/#183 и запись `fix` про #186) ни одного прогона selftest не породили — цепочка после 19:13 не пересобирала кандидата. (4) Дефекты ужатия/маркера (дефект `ig-output-line-2975`, «полный файл 2999 строк, в `.out` — 3000») в этом прогоне не проверялись — до T1 дело не дошло.

### Паттерны
- Verify-клон — общая рабочая область, а не замороженный стенд: reflog `/Users/vova/code/opencode-mem-verify` — `checkout: moving from main to mem-migration-idempotent` (20:24:58), `reset: moving to origin/main` (20:38:55 → `dfde60d616`), `reset: moving to origin/main` (20:39:39 → `256e068a4d59`); HEAD гейта (`run-selftest.sh:57-61`) — изменяемый другими процессами параметр, за 55 секунд до прогона он сменился на 2 коммита вперёд
- Кандидат ≠ установленный бинарь: в 9 из 11 последних прогонов (совпали только 02:01 и 18:38) — `installed binary: opencode v0.0.0-fork-at-260abb8810eb` (19:13) против кандидата `03349ef2b2ed`; в логе 20:40 строка `installed binary` не дошла (падение раньше), т.е. расхождение даже не зафиксировано
- «Зелёный `selftest-last.json`» ≠ истина: `chain-current.txt` уже фиксирует «после провала `selftest-last.json` остался `{"status":"ok","sha12":"260abb8810eb"}` → источник истины — последний лог в `~/.opencode/scripts/selftest-logs/` + `chain-state.jsonl`»; два провала подряд (19:13, 20:40) состояние файла не изменили
- Два подряд цикла цепочки без продвижения: 19:13 — `release exit=77 withheld`; 21:15 — `build exit=78 skipped` (диск) → `selftest exit=77 withheld` → `release exit=77 withheld`; `candidate-current.json` не менялся с 19:13:11
- Место тает быстро: свободно 6,7 GiB (19:13) → 678 MiB (21:15) при `~/.local/share/opencode/shell` = 535 `.out` / 4,7 МиБ (было 490 / 4,5 МиБ в отчёте 19:13) и 6 неубранных tmp-каталогов с `big.txt`/`doc.md` (включая `tmp.nj6gDeajBa` от провалившегося прогона 19:13)
- Артефакты ужатых выводов и stdout прогона копятся: `selftest-stdout.log` — 237 строк накопительным итогом, последний блок — обрыв 20:40 (`=== SELFTEST 20261020-204034 ===` + гейт + `LOG: …`); `run-selftest.sh` пишет в него и `tee`-ом, и `>>` из `run_turn`, т.е. один и тот же прогон дублируется
- Диагностика падения 20:40 доступна целиком (в отличие от 19:13): причина — в самой строке лога, в `opencode.log` по sentinel'у `ses_selftest-20261020-204034`/`ST-20261020-204034` нет ни одной записи → кандидат не запускался (падание до `run_turn`)

### Идеи (as is)
- Пересобирать кандидата, когда HEAD verify-клонa уходит вперёд кандидата (или фиксировать SHA verify-клонa на момент build) — контекст: `candidate-current.json` с 19:13:11, verify-клон с 20:39:39 на `256e068a4d59`, гейт падает
- Писать в `selftest-last.json` и провал (sha, sentinel, код выхода, причина, строка лога) — контекст: после двух красных прогонов файл остался с `"status": "ok"` за 18:40
- Записывать в `chain-state.jsonl` каждый запуск `run-selftest.sh`, а не только шаги цепочки — контекст: прогон 20:40 (exit 70) в журнале шагов отсутствует
- Планировать сборку до гейта места: порог skip 5 GiB срабатывает, когда цепочка уже встала — контекст: `build exit=78 skipped` при 678 MiB свободных
- Разделять бинарь для живой приёмки и бинарь-кандидат (или промоутить кандидата) — контекст: приёмка 20:40 шла на `opencode-mem-verify/packages/cli/dist/.../opencode` (с #183), selftest — на кандидате `03349ef2b2ed` (без #183)
- Помечать в логе прогона расхождение `candidate != installed` до гейтов — контекст: в логе 20:40 строки `installed binary` нет вообще, расхождение 9 из 11 прогонов
- Логировать путь к несуществующему исполняемому файлу MCP (а не только `NotFound`) — контекст: 6 `ChildProcess.spawn (node …)` в 17:40:34Z
- Убирать фикстуры на любом выходе (cleanup в `fail`/`skip`) и чистить `~/.local/share/opencode/shell/**/*.out` — контекст: 6 tmp-каталогов с `big.txt`/`doc.md`, 535 `.out` / 4,7 МиБ, том заполнен на 100%

(Только констатация фактов из лога 20:40, `chain-state.jsonl`, `opencode.log`, reflog'ов клонов, build-лога и состояния файлов; решения не предлагались.)

## BUG-REPORT 20261020-215946

Источник: `~/.opencode/scripts/selftest-logs/selftest-20261020-215946.log` (13 909 байт / 160 строк — наибольший по mtime), контекст: `release-current.md` (22:01), `selftest-last.json`, `candidate-current.json`, `chain-state.jsonl`, `build-logs/build-20261020-215939.log`, `releaser-logs/releaser-20261020-220058.log`, `~/.local/share/opencode/log/opencode.log` (окно 18:59–19:01Z), `~/.local/share/opencode/log/memory-context.log`, `run-selftest.sh`, `run-releaser.sh`, общая БД `~/.local/share/opencode/opencode.db`, verify-клон `/Users/vova/code/opencode-mem-verify`, ITERATIONS (последние 10 записей), BUG-REPORT `20261020-204034`.

### Проблемы
- critical: **0** — `grep -cE "FAIL|Error|panic|assert"` по логу → 0 совпадений (case-insensitive — тоже 0); T1–T5 `exit=0` (стр. 94/110/123/150/154), «=== SELFTEST 20261020-215946 DONE ===» (стр. 156), 4/4 check'а ok (стр. 157–159), трейлер `acceptance: candidate_sha=9fc966c73889 candidate=opencode v0.0.0-fork-at-9fc966c73889 installed=opencode v0.0.0-fork-at-260abb8810eb sentinel=ST-20261020-215946` (стр. 160) — прогон зелёный
- Приёмочный check на needle ищет строку по всей общей БД, а не в сообщениях проверяемой сессии: `strings -a "$SESSION_FOUND_IN" "$SESSION_FOUND_IN-wal" | grep -q "$NEEDLE"` (`run-selftest.sh:224`), тогда как соседний check на маркер ужатия скоупится сессией (`where session_id='$SESSION'`, стр. 202). В `opencode.db` строка `CM-5581-A` встречается в **186 сообщениях / 61 разных сессиях** (`select count(distinct session_id) … like '%CM-5581-A%'` → 61; в отчёте 164201 было 24 сессии) — «check: needle retrieved — ok (CM-5581-A)» (стр. 159) проходит и без ретрива в текущем прогоне — high
- Check «full output file present and complete» не проверяет полноту: единственный `grep -q "big-output-line-2999"` (`run-selftest.sh:218`) — ни байт-идентичности, ни числа строк; в логе нет ни одного байтового замера (`grep -c "byte identical|byte/line stats|SAVED OUTPUT"` → 0 против 4 в прогоне 042801) — medium
- Маркер ужатия не совпадает с показанным фрагментом: окно объявлено как `[showing lines 2976-3000 of 3000; full output saved to …]` (стр. 36), а первая видимая строка — обрезанный байтовый хвост `ig-output-line-2975 xxxxx…` (стр. 10, нет ведущей `b`); дефект тот же, что в 042801 / 163531 / 164201 / 183819 (67 вхождений `ig-output-line` в этом логе) — medium
- Расхождение candidate/installed внутри прогона не проверяется ни одним check'ом: `installed binary: opencode v0.0.0-fork-at-260abb8810eb` (стр. 4) против `candidate: /Users/vova/.opencode/candidates/9fc966c73889/opencode (9fc966c73889)` (стр. 2) и `candidate_sha=9fc966c73889` в трейлере (стр. 160); сошлись только после шага release (22:01:15, `installed: opencode v0.0.0-fork-at-9fc966c73889`) — low
- Вывод read/grep-тулов в лог не попадает: остались только следы вызовов `→ Read var/folders/…/tmp.seLbxkbCc6/doc.md` (стр. 99) и `✱ Grep "big-output-line-2999" in … · 1 match` (стр. 114) без содержимого — `check: full output file present and complete` и `check: needle retrieved` из лога не подтверждаются — medium
- Плагин-конфиг форка указывает на файлы, а не на каталоги: 9 WARN `configured plugin path must be a directory` в окне прогона (18:59:49.566Z … 19:00:54.348Z, по одному-два на каждый `--standalone`-старт ходов T1–T5) на пути `/Users/vova/code/zerocreds-server/opencode-plugin/zerocreds-events.js` и `/Users/vova/code/zerocreds-local-release/opencode-plugin/zerocreds-events.js` (`~/.config/opencode/opencode.json:192-207`); всего таких WARN в `opencode.log` 239 с 2026-10-19T15:14:00Z — плагин не грузится ни в одном ходе прогона — medium
- Лог релиза называет форк стоком: «stock: активный бинарь — форк (opencode v0.0.0-fork-at-260abb8810eb), бэкап стока не трогаем» (`releaser-20261020-220058.log`, ветка `*fork-at-*` в `run-releaser.sh:208`), тогда как реальный `~/.opencode/bin/opencode.stock-backup` — `opencode v2.0.32` — low
- PII в логе прогона нет: 0 совпадений по e-mail / `ghp_` / `github_pat_` / телефону; в логе остаются только абсолютные пути с домашним каталогом, sentinel `ST-20261020-215946` и SHA — low

Регрессии vs предыдущих циклов: (1) прогон 18:38 (`selftest-20261020-183819.log`, 173 строки) и прогон 21:59 (160 строк) — одинаковая форма: T1–T5 `exit=0`, DONE, 4/4 check'а, `acceptance:` есть; отличаются SHA (`260abb8810eb` → `9fc966c73889`) и то, что в 21:59 кандидат == `origin/main` == HEAD verify-клонa (`9fc966c73889`, дерево чистое) — гейт SHA (стр. 57-62), падавший в прогоне 20:40, в этот раз прошёл. (2) Дефекты ужатия/маркера не сняты: побайтовый отпечаток `ig-output-line-2975` + `showing lines 2976-3000 of 3000` идентичен в прогонах 042801, 163531, 164201, 183819, 215946 при разных сборках — воспроизводится и на `9fc966c73889`. (3) Дефект needle-check не снят и вырос: 24 сессии с `CM-5581-A` (отчёт 164201) → 61 сессия. (4) Байтовые замеры, которые были в 042801, не повторены ни в 164201, ни в 215946 — приёмочная полнота по-прежнему не проверяется. (5) Цепочка сдвинулась: 21:15 — build exit=78 skipped (диск), selftest/release withheld; 21:59 — build exit=0 (7 s), selftest exit=0 (72 s), release exit=0 (17 s), тег `mem-v20261020-2201-9fc966c73889`; релиз withheld 2-й цикл подряд снят. (6) ITERATIONS (последние 10 записей) на момент прогона утверждал «релиз withheld 2-й цикл подряд», «три SHA разошлись», «installed `260abb8810eb` (без memory-тулов)» — фактическое состояние после 22:01 иное: установленный бинарь = `9fc966c73889` (с memory-тулами, PR #180/#183/#187 в `main`), `release-current.md` соответствует, `~/.opencode/forever-install.json` обновлён (revision `9fc966c73889`, sha256 `6cbad19d…`, installed_at 2026-10-20T19:01:13Z). (7) Ни один memory-замер в прогоне не снят: `ses_selftest-20261020-215946` в `memory-context.log` не встречается (0 совпадений) — `find_pii`, `compaction:`, `cache_r` в логе нет.

### Паттерны
- Усечение ведёт себя как заявлено: полный вывод на диске целиком — `~/.local/share/opencode/shell/e22c0befcd3aab577c593974d56decf884468691/sh_15aaf36590018VZ0nnMaf7cSCt.out`, 244 889 Б, `wc -l` = 2999, `head -1` → `big-output-line-0 …`, `tail -1` → `big-output-line-2999 …`, `grep -c "big-output-line-2999"` = 1; T3 достал строку через grep по этому файлу (стр. 114–122) — «сжали, но ничего не прячем» подтверждено
- Расхождение `wc -l` (2999) и маркера («of 3000») — свойство фикстуры: последняя строка без завершающего `\n`; модель отметила расхождение сама (стр. 147) и сверилась через `head`/`tail` (стр. 42–46)
- Инструментальная асимметрия (отчёт T4, стр. 148): bash-тул режет 3000 строк до 25 с маркером `[showing lines 2976-3000 of 3000; …]`, read-тул отдал все 402 строки `doc.md` целиком без маркера — разные формы и разные стороны отсечения у двух тулов
- Модель выполняла сверку вывода по-разному на одном и том же промпте T1: в 042801 — `wc -c`/`awk`/`cmp -s` (байт-идентичность), в 164201 и в 215946 — только `wc -l`/`head`/`tail`; приёмочная полнота от этого зависит, а check её не проверяет
- Плацдарм общий со стоком: «check: data namespace shared with stock — ok (/Users/vova/.local/share/opencode/opencode.db)» (стр. 5), сессия `ses_selftest-20261020-215946 (bound in …/opencode.db)` (стр. 95) — изоляции прогонов нет; сток-бэкап (`v2.0.32`) ту же базу открывает, гейт проходит
- Ходы T1–T4 шли на `ladder/build`, проверка дефолта — на `mem-gpt/build` («default model: mem-gpt/build», стр. 151; «check: default model served — ok (mem-gpt/build)», стр. 155)
- Фикстура прогона убрана: каталога `/var/folders/…/tmp.seLbxkbCc6/` нет (cleanup `rm -rf "$DOC_DIR"`, `run-selftest.sh:245`); старые фикстуры остались — `tmp.nj6gDeajBa` (от провалившегося прогона 19:13, 264 K: `big.txt` 244 889 Б + `doc.md` 22 358 Б), `tmp.PnJis87Hkk` (02:01), `tmp.Ju6YgRF7Cx` (01:28), `tmp.leQfbZ16WV` (01:12) — по 264 K каждый
- Накопление артефактов: `~/.local/share/opencode/shell` — 538 `.out` / 5,2 МиБ (было 535 / 4,7 МиБ в отчёте 204034); `~/.opencode/builds` — 938 МиБ в 7 каталогах сборок (`260abb8810eb`, `2d96e3d9e570`, `663876427c7b`, `6d9423b15591`, `7a12f66b4abc`, `9fc966c73889`) + `current`/`previous`; том `/System/Volumes/Data` — 98%, 4,8 GiB свободно (в цикле 21:15 было 99% / 1,9 GiB, в отчёте 204034 — 100% / 678 MiB)
- `memory-context.log` (7 000 строк): 1 852 строки с `session=?` (идентификатор сессии не подставлен), 6 869 — с `mark=0` (кеш-метка не пишется) — обе величины без привязки к прогонам; в прогоне 21:59 сессия не попала в лог вовсе
- Ошибок в окне прогона в `opencode.log` нет: 0 записей `level=ERROR` для `ses_selftest-20261020-215946` (8 строк с этим id — только INFO: 5 × «cli starting» с `version=0.0.0-fork-at-9fc966c73889`); 52 «every rung failed» (`AI.Error.ProviderInternal`) в логе относятся к другим сессиям (`ses_ea55ff97…`, `ses_ea5671e04…` и далее), в окне 18:59–19:02Z их 0
- В трейлере только `started_ms=1792522786000`, длительности нет; фактическая длительность прогона 72 s (`chain-state.jsonl`) против 284 s у зелёного прогона 16:41 и 538 s у прогона 12.10 — при том же наборе ходов и моделей
- `selftest-last.json` обновлён верно (sha12 `9fc966c73889`, status `ok`, sentinel `ST-20261020-215946`, checked_at 2026-10-20T19:00:58Z) — после двух красных прогонов подряд зелёное состояние снова соответствует последнему прогону

### Идеи (as is)
- Скоупить check на needle по `session_id`, как check на маркер ужатия — контекст: `grep -q "$NEEDLE"` по файлу БД + WAL (`run-selftest.sh:224`) при 61 сессии с этим же needle в общей базе
- Дополнить check «full output file present and complete» сверкой с исходником (байты/строки), а не только `grep` последней строки — контекст: стр. 218 скрипта и отсутствие байтовых замеров в этом логе
- Указывать в маркере ужатия фактические границы показанного фрагмента (или не резать первую строку окна пополам) — контекст: `showing lines 2976-3000` против `ig-output-line-2975`; дефект воспроизводится в 5 подряд прогонах
- Класть в лог вывод read/grep-тулов (хотя бы первые строки) — контекст: оба артефактных check'а из лога не подтверждаются
- Проверять в прогоне равенство candidate/installed либо явно помечать расхождение в логе — контекст: `installed … 260abb8810eb` против `candidate … 9fc966c73889` в момент прогона; равенство возникло только после шага release
- Проверять, что пути плагинов в конфиге — каталоги, а не файлы — контекст: 9 WARN «configured plugin path must be a directory» в окне прогона, 239 за два дня
- Различать в логе релиза форк и сток (указать версию `opencode.stock-backup` рядом с активным бинарём) — контекст: строка «stock: активный бинарь — форк (…-260abb8810eb)» при реальном стоке `v2.0.32`
- Убирать фикстуры на любом выходе (cleanup в `fail`/`skip`) — контекст: 4 неубранных tmp-каталога по 264 K, один — от провалившегося прогона 19:13
- Чистить `~/.local/share/opencode/shell/**/*.out` и хранить ограниченное число сборок в `~/.opencode/builds` — контекст: 538 `.out` / 5,2 МиБ и 938 МиБ в 7 каталогах сборок при томе на 98%
- Подставлять идентификатор сессии в `memory-context.log` вместо `session=?` — контекст: 1 852 строки без id из 7 000; в прогоне 21:59 сессия не попала в лог вовсе
- Писать рядом с `started_ms` длительность (`dur`) — контекст: в трейлере её нет, длительность восстанавливается только по `chain-state.jsonl`
- Сделать формулировку хода T1 «выведи результат как есть» совместимой с ужатием (либо явно проверять дословность полного вывода) — контекст: полные 3000 строк в контекст не попадают, модель отвечает усечённым фрагментом

(Только констатация фактов из лога 21:59, `chain-state.jsonl`, `opencode.log`, `memory-context.log`, build/releaser-логов, общей БД, состояния файлов и скриптов прогона; решения не предлагались.)

## BUG-REPORT 20261020-233804

Источник: `~/.opencode/scripts/selftest-logs/selftest-20261020-233804.log` (3 175 строк / 259 КБ, наибольший по mtime), контекст: `release-current.md`, `selftest-last.json`, `chain-state.jsonl`, `~/.local/share/opencode/log/opencode.log`, `~/.local/share/opencode/log/memory-context.log`, общая БД `~/.local/share/opencode/opencode.db`, ITERATIONS (последние 10 записей), BUG-REPORT `20261020-215946`.

### Проблемы

- **Ответ модели «выведи результат как есть» не совпадает с исходником, но все check'и прошли** — T1: вывод `cat` усечён до 25 строк, модель вызвала `execute` с JS-циклом на 3 000 строк (`execute {"code":"const lines = [];\nfor (let i = 0; i < 3000; i++) …` , стр. 98) и вставила результат в ответ. В ответе: **8 строк с x=52** (стр. 824, 1162, 1259, 1260, 1920, 1960, 1969, 1970), **3 строки с x=68** (1671, 1865, 1869), **1 строка обрезана лимитом вывода** x=41 (стр. 2042, `big-output-line-2019`), **6 строк отсутствуют** (203–208, переход 202→209 на стр. 305–306), **1 строка с Unicode-дефектом** U+2010 вместо ASCII `-` (стр. 1031, `big-output-line‐933`) — **critical**
- **Маркер ужатия не совпадает с показанным фрагментом** — стр. 36: `[showing lines 2976-3000 of 3000; full output saved to …]`, первая видимая строка: `ig-output-line-2975 xxxxx…` (потерян ведущий `b`). Дефект воспроизводится в 7 подряд прогонах: 042801, 163531, 164201, 183819, 215946, 224034, 233804 — **high**
- **Check «needle retrieved» не скоупится по сессии** — `run-selftest.sh:224`: `strings -a "$SESSION_FOUND_IN" "$SESSION_FOUND_IN-wal" | grep -q "$NEEDLE"` ищет по всей общей БД; в `session_message` needle `CM-5581-A` встречается в **91 разных сессиях** (21:59 было 61). Check проходит без ретрива в текущем прогоне — **high**
- **Check «full output file present and complete» проверяет только `grep -q "big-output-line-2999"`** — нет сверки байтов/строк с исходником; файл `.out` — 2 999 строк по `wc -l` (последняя без `\n`) против 3 000 логических — **medium**
- **Вывод read/grep-тулов в лог не попадает** — остаются только маркеры вызовов (`→ Read …`, `✱ Grep …`); содержимое отсутствует, артефактные check'и из лога не подтверждаются — **medium**
- **Плагин-конфиг указывает на файлы, а не на каталоги** — 13 WARN `configured plugin path must be a directory` в окне прогона (318 за всё время) на путях `/Users/vova/code/zerocreds-server/…/zerocreds-events.js` и `/Users/vova/code/zerocreds-local-release/…/zerocreds-events.js`; плагин не грузится ни в одном ходе — **medium**
- **Параллельный прогон 22:40 не в `chain-state.jsonl`** — `selftest-20261020-224034.log` (262 КБ, зелёный, T1–T5 exit=0, 4/4 check'а) в журнале цепочки отсутствует — **medium**
- **Долгоиграющий интерактивный сервер на устаревшем билде** — `run=72aba505` (версия `0.0.0-fork-at-7a12f66b4abc`, старт 2026-10-20T01:41) в окне прогона даёт 3 ERROR `Failed to drain Session / AI.Error: every rung failed` (20:40:00, 20:43:25, 20:46:55 UTC); всего 78 таких ошибок в логе — **medium**
- **`memory-context.log`: идентификатор сессии не подставлен** — 0 совпадений `ses_selftest-20261020-233804`; 1 852 из 7 000 строк имеют `session=?` — **low**
- **В трейлере только `started_ms`, длительности нет** — `dur` отсутствует; длительность (467 с) восстанавливается только по `chain-state.jsonl` — **low**
- **Неубранные tmp-фикстуры** — 4 каталога с `big.txt`/`doc.md` от прошлых прогонов: `tmp.Ju6YgRF7Cx` (01:28), `tmp.PnJis87Hkk` (02:01), `tmp.leQfbZ16WV` (01:12), `tmp.nj6gDeajBa` (19:13), по 264 КБ каждый — **low**
- **Новый источник артефактов: `~/.local/share/opencode/tool-output/`** — 1 276 файлов / 63 МБ от Code Mode `execute` (ранее не отслеживался) — **low**
- **Неточность модели в T1** — заявлено «каждая — `big-output-line-N` + 64 x-символа» (стр. 78), позже `awk` дал 60 — **low**

### Паттерны

- Маркер ужатия детерминированно неверен: `showing lines 2976-3000` при видимом `ig-output-line-2975` — воспроизводится в 7 подряд логах при разных сборках и моделях.
- Счётчик ложных срабатываний needle-check растёт: 61 сессия (21:59) → 91 сессия (23:38) в `session_message` — достоверность check'а падает по мере наполнения общей базы.
- Усечение накрывает и `execute`: возврат из Code Mode-рантайма тоже режется до 25 строк (`showing lines 1-25 of 3000`), поэтому модель восстанавливает содержимое по формуле, а не читает его.
- Воспроизведение дефекта ответа в соседнем прогоне: в логе 22:40 в ответе модели — 4 строки с x=52, 1 с x=68, разрыв 2501–2975 (475 строк) — тот же класс, что и в 23:38.
- Длительность прогона выросла: 467 с (23:38) против 72 с (21:59) и 284 с (16:41) — коррелирует с ручным воспроизведением 3 000 строк в ответе модели.
- `chain-state.jsonl` не фиксирует все вызовы `run-selftest.sh`: 22:40 прогон отсутствует (как 20:40 в предыдущем цикле).
- Общая БД `opencode.db` разделяется со стоком («check: data namespace shared with stock — ok») — изоляции прогонов нет, needle-check уязвим к переполнению общей базы.
- Ни одного memory-тул вызова в прогоне (`find_tool_calls`, `put_in_operational_memory`, `search_operational_memory`, `find_pii` — по 0), замеры памяти (`cache_r`, `compaction`) в логе отсутствуют.
- `candidate == installed == 1b3dc3065485` впервые внутри прогона (стр. 2–4 и трейлер) — расхождение SHA, державшееся 9 прогонов из 11, в этом цикле не проявилось.

### Идеи (as is)

- Скоупить needle-check по `session_id` (как check на маркер ужатия: `where session_id='$SESSION'`).
- Дополнить check «full output file present and complete» побайтовой сверкой с исходником (`diff -q` / `cmp -s` / `wc -l` + `wc -c`).
- Исправить маркер ужатия: указывать фактические границы показанного фрагмента либо не резать первую строку окна пополам.
- Проверять в прогоне содержимое ответа модели, а не только файлы на диске (например, `grep -c "^big-output-line-[0-9]\+ x\{60\}$"` по stdout модели) — контекст: 12 дефектных строк, 6 пропусков и 1 Unicode-дефект в ответе при зелёных check'ах.
- Логировать вывод read/grep-тулов в selftest-лог хотя бы первыми строками.
- Валидировать пути плагинов в конфиге: требовать каталоги, отвергать файлы.
- Писать `dur_ms` в acceptance-трейлер рядом с `started_ms`.
- Убирать tmp-фикстуры на любом выходе (`fail`/`skip`/`exit`).
- Ограничивать накопление `~/.local/share/opencode/tool-output/` и `~/.local/share/opencode/shell/**/*.out`.
- Записывать в `chain-state.jsonl` каждый запуск `run-selftest.sh`, а не только шаги цепочки.
- Изолировать пространство имён selftest в БД либо скоупить все проверки по `session_id`.
- Синхронизировать интерактивный сервер с установленным бинарём — контекст: `run=72aba505` живёт с 01:41 на `7a12f66b4abc` при установленном `1b3dc3065485`.

(Только констатация фактов из лога 23:38, `chain-state.jsonl`, `opencode.log`, `memory-context.log`, общей БД, состояния файлов и скриптов прогона; решения не предлагались.)

## BUG-REPORT 20261021-053941

Источник: `~/.opencode/scripts/selftest-logs/selftest-20261021-053941.log` (762 строки / 62 КБ, наибольший по mtime на момент разбора), контекст: `~/.opencode/scripts/release-current.md` (SHA `1b3dc3065485`), `chain-state.jsonl`, `run-selftest.sh`, `~/.local/share/opencode/log/opencode.log`, общая БД `~/.local/share/opencode/opencode.db`, ITERATIONS (последние 10 записей), BUG-REPORT `20261020-233804`. Сопутствующий прогон того же цикла: `selftest-20261021-052127.log` (2323 строки / 180 КБ, mtime 05:31 — на 9 мин раньше).

### Проблемы

- **Ответ модели «выведи результат как есть» обрезан и содержит мусор, все check'и при этом зелёные** — T1, стр. 679: `big-output-line Pennsylvania` (в исходнике такой строки нет); модель признаёт: «последние строки в приведённом блоке искажены (в частности, строка `big-output-line-586` заканчивается мусором `Pennsylvania`…)», стр. 748: «генерация оборвалась на строке ~586». При этом `check: full output file present and complete — ok`, `check: needle retrieved — ok` — **critical**
- **Дефектная длина x-прогона в воспроизведённом ответе** — стр. 443: `big-output-line-353 xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` (52 `x` вместо 60; факт в исходнике установлен в этом же логе на стр. 46–65: `1: len=60` … `20: len=60`, и на стр. 71–73: `total lines: 3000` / `mismatches: 0`) — **medium**
- **Пропущено 2411 строк из 3000 в ответе T1** — блок ответа содержит только индексы 0–588 (589 строк), индексов 589–2999 в ответе нет (в логе остаются лишь превью окна 2976–2999 из вывода харнесса и отдельный повтор 2998–2999 в T3); модель сама: «ответ не поместился в лимит генерации» (стр. 682) — **high**
- **Маркер ужатия не совпадает с показанным фрагментом** — стр. 37: `[showing lines 2976-3000 of 3000; full output saved to …]`, при этом первая видимая строка — `ig-output-line-2975` (потерян ведущий `b`, стр. 11). Воспроизводится в 9 подряд прогонах: 042801, 163531, 164201, 183819, 215946, 224034, 233804, 052127, 053941 — **high**
- **Ложные «mismatch» в диагностике из-за сравнения строк, а не чисел** — стр. 67: `mismatch at 1 big-output-line-0` (awk сравнивает `$1` с `NR-1`, т.е. строку с числом), при этом корректная проверка на стр. 71–73 даёт `total lines: 3000` / `mismatches: 0`. Модель в T4 утверждает «проверено awk: 0 расхождений» — **medium**
- **Ложное «MISMATCH»/«X MISMATCH» из-за неверного offset в проверке** (соседний прогон 052127) — стр. 51–80: 30 строк `MISMATCH num at NR=2986…` и `MISMATCH len at NR=…: 60` (awk с `substr($0,19,…)` вместо 16 для префикса `big-output-line-`), стр. 108: `X MISMATCH at 1` (perl с ожиданием 61 вместо 60). Исходник при этом корректен: `VERIFIED: … + 60*"x", i=0..2999; no trailing newline; 244889 bytes` (стр. 116) — **medium**
- **В предыдущем прогоне цикла ответ на 2099 строк, все с неверной длиной x-прогона** (052127) — распределение по ответу: 54 `x` (366 строк), 55 `x` (900 строк), 56 `x` (833 строки) при факте 60 `x` (проверено в том же логе: `VERIFIED: … + 60*"x", i=0..2999`); модель в T4 сама признаёт: «я постепенно „укорачивал“ под число цифр (63/62/61/60)» (стр. 2306) — **critical**
- **Check «full output file present and complete» проверяет только `grep -q "big-output-line-2999"`** — `run-selftest.sh:218` (`grep -q "big-output-line-2999" "$OUT_FILE"`), подтверждение на стр. 221; побайтовой сверки нет. Файл `.out` — 244 889 байт, `wc -l` = 2999 (последняя строка без `\n`) против 3000 логических — **medium**
- **Check «needle retrieved» не скоупится по сессии** — `run-selftest.sh:224`: `strings -a "$SESSION_FOUND_IN" "$SESSION_FOUND_IN-wal" | grep -q "$NEEDLE"` ищет по всей общей БД; `CM-5581-A` встречается в **149 разных сессиях** `session_message` (377 сообщений) — рост с 91 (23:38) и 96 (по ITERATIONS) — **high**
- **Вывод read/grep-тулов в лог не попадает** — остаются только маркеры вызовов (`→ Read …`, `✱ Grep …`); содержимое отсутствует, артефактные check'и из лога не подтверждаются — **medium**
- **Плагин-конфиг указывает на файлы, а не на каталоги** — 13 WARN `configured plugin path must be a directory` в окне прогона (469 за всё время в `opencode.log`) на путях `/Users/vova/code/zerocreds-server/opencode-plugin/zerocreds-events.js`, `/Users/vova/code/zerocreds-local-release/…`, `/Users/vova/code/.worktrees/zerocreds-server/session-…/…` — **medium**
- **Долгоиграющий интерактивный сервер на устаревшем билде** — `run=72aba505` в окне прогона даёт ERROR `Failed to drain Session / AI.Error: every rung failed` (02:41:29 UTC); всего 133 таких ошибки в логе, в окне 05:21-прогона — ещё 4 — **medium**
- **Неубранные tmp-фикстуры** — 9 каталогов `tmp.*` в `/var/folders/…/T/`, из них 4 с `big.txt`/`doc.md` от прошлых прогонов (`tmp.Ju6YgRF7Cx`, `tmp.PnJis87Hkk`, `tmp.leQfbZ16WV`, `tmp.nj6gDeajBa`), по 264 КБ каждый; каталог текущего прогона `tmp.NqJeLSaBpJ` уже удалён — **low**
- **Накопление артефактов tool-output** — `~/.local/share/opencode/tool-output/`: 1278 файлов / 63 МБ; `~/.local/share/opencode/shell/**/*.out`: 597 файлов / 6,7 МБ — **low**
- **В трейлере только `started_ms`, длительности нет** — `acceptance: … sentinel=ST-20261021-053941 started_ms=1792550381000`; длительность прогона (575 с для 052127) берётся только из `chain-state.jsonl` — **low**

### Паттерны

- **Дефект «ответ модели ≠ исходник при зелёных check'ах» воспроизводится в 6 подряд прогонах и нарастает по объёму**: 22:40 — 4 строки x=52, 1 x=68, разрыв 2501–2975; 23:38 — 12 дефектных строк, 6 пропусков, 1 Unicode-дефект; 00:46 — 64 строки эмита, все корректные; 05:21 — 2099 строк эмита, все 2099 с неверной длиной x-прогона + 900 строк (2100–2999) не выведены; 05:39 — 589 строк эмита в ответе, 1 с x=52 + строка-мусор `big-output-line Pennsylvania` + 2411 строк пропущено.
- **Один и тот же сценарий T1 даёт разный масштаб дефекта при идентичном харнессе** — в прогоне 05:21 модель вывела 2099 строк ответа (все с неверной длиной x-прогона, индексы 0–2099 подряд, кроме обрезанной 1366), в прогоне 05:39 — 589 строк (0–588) и обрыв с мусором; длительность прогона 575 с против 169 с (`started_ms=1792550381000` → 05:42:30).
- **Харнесс режет вывод всегда одинаково** — `showing lines 2976-3000 of 3000` (25 строк) и `showing lines 5970-6001 of 6001` (32 строки) — граница окна подрезается по первой букве (`ig-output-line-2975` вместо `big-output-line-2975`), воспроизводится в 9 логах подряд при разных сборках/моделях.
- **Модель решает задачу «выведи как есть» воспроизведением по формуле, а не чтением** — она сама констатирует это в обоих прогонах: «Собственная неточность… x-суффикс я постепенно „укорачивал“» (052127, стр. 2306), «Правильный путь: не дублировать файл в чат, а ссылаться на сохранённый `.out`» (053941, стр. 748). Оба раза харнесс при этом показывает только хвост.
- **Ложные срабатывания растут вместе с базой**: needle-check 64 → 91 → 96 → **149 сессий**; счётчик сессий в `session_message` по `CM-5581-A` = 377 сообщений. Проверка проходит без ретрива и без привязки к текущей сессии.
- **Проверка «полный вывод сохранён» структурно не может отличить «сжато» от «потеряно»** — сравнение только по наличию одной строки `big-output-line-2999`; фактический `.out` прогона 05:39 (244 889 байт, `md5 = 147c2f70c37d97fd3221d00e2f799734`) действительно полон, но сама проверка этого не устанавливает — сверки с исходником в ней нет.
- **`read`-тул и shell ведут себя по-разному на одном файле** — `read` отдал `doc.md` целиком (402 строки, без ужатия), `cat` большого файла режется до 25 строк (отмечено моделью: стр. 751).
- **Один и тот же неверный offset в проверках воспроизводится дважды за цикл** — `substr($0,19,…)` в awk (052127) и сравнение строки с числом в awk (053941) дают массовые ложные «MISMATCH»/«mismatch» при корректном исходнике; модель в обоих случаях строит выводы на ложных проверках.
- **Прогон 05:39:41 не записан в `chain-state.jsonl`** — в журнале цепочки есть только `run 20261021-0521` (build/selftest/release); selftest 05:39 вне цепочки (запущен вручную, `run-selftest.sh` в ps) — **medium**
- **Общая БД `opencode.db` разделяется со стоком** («check: data namespace shared with stock — ok») — изоляции прогонов нет; needle-check уязвим к переполнению общей базы.
- **Ни одного memory-тул вызова в прогоне** (`put_in_operational_memory`, `search_operational_memory`, `find_pii` — по 0), замеры памяти (`cache_r`, `compaction`) в логе отсутствуют.
- **`candidate == installed == 1b3dc3065485`** подтверждён в обоих прогонах (стр. 2–4 и трейлер) — расхождение SHA, державшееся 9 прогонов из 11, в этом цикле не проявилось.
- **Секретов/PII в логах прогонов не найдено** — grep по `ghp_`, `github_pat_`, `sk-`, `token=`, `password`, `api_key`, `secret` по обоим логам даёт 0 совпадений; в `opencode.log` пути плагинов и `run=72aba505` содержат только локальные пути.

### Идеи (as is)

- Проверять в прогоне содержимое ответа модели, а не только файлы на диске (например, `grep -c "^big-output-line-[0-9]\+ x\{60\}$"` по stdout модели) — контекст: 2099 строк с неверной длиной x-прогона и 2411 пропусков в ответе при зелёных check'ах.
- Скоупить needle-check по `session_id` (как check на маркер ужатия: `where session_id='$SESSION'`) — контекст: 149 сессий с `CM-5581-A` в общей БД.
- Дополнить check «full output file present and complete» побайтовой сверкой с исходником (`cmp -s` / `md5` / `wc -l` + `wc -c`) — контекст: текущая проверка ловит только одну строку.
- Исправить маркер ужатия: указывать фактические границы показанного фрагмента либо не резать первую строку окна пополам (детерминированно теряется первый символ).
- Формулировать T1 так, чтобы «выведи результат как есть» не требовала дублирования 245 КБ в чат (модель дважды обрывалась на лимите генерации) — контекст: 05:21 и 05:39.
- Логировать вывод read/grep-тулов в selftest-лог хотя бы первыми строками.
- Валидировать пути плагинов в конфиге: требовать каталоги, отвергать файлы (469 WARN, 13 в окне прогона).
- Писать `dur_ms` в acceptance-трейлер рядом с `started_ms`.
- Убирать tmp-фикстуры на любом выходе (`fail`/`skip`/`exit`) — 4 осиротевших каталога с `big.txt`/`doc.md`.
- Ограничивать накопление `~/.local/share/opencode/tool-output/` (1278 файлов / 63 МБ) и `~/.local/share/opencode/shell/**/*.out` (597 файлов).
- Записывать в `chain-state.jsonl` каждый запуск `run-selftest.sh`, а не только шаги цепочки — прогон 05:39:41 в журнале отсутствует.
- Изолировать пространство имён selftest в БД либо скоупить все проверки по `session_id`.
- Синхронизировать интерактивный сервер с установленным бинарём — контекст: `run=72aba505` живёт с 01:41 на `7a12f66b4abc` при установленном `1b3dc3065485`, 133 ошибки `every rung failed`.

(Только констатация фактов из логов 05:39:41 и 05:21:27, `chain-state.jsonl`, `run-selftest.sh`, `opencode.log`, общей БД и состояния файлов; решения не предлагались.)

## BUG-REPORT 20261021-082939

Источник: `~/.opencode/scripts/selftest-logs/selftest-20261021-082939.log` (1328 строк / 103 889 Б, наибольший по mtime — 2026-10-21 08:34), цепочка `20261021-0829` (`build` 12 с → `selftest` 299 с exit=0 → `release` 20 с exit=0 → `bug-reporter`), контекст: `~/.opencode/scripts/release-current.md` (SHA `1b3dc3065485`), `run-selftest.sh`, `chain-state.jsonl`, `chain-logs/chain-20261021-0829.log`, `~/.local/share/opencode/log/opencode.log`, общая БД `~/.local/share/opencode/opencode.db`, ITERATIONS (последние 10 записей), BUG-REPORT `20261021-053941`. Явных `FAIL`/`Error`/`panic`/`assert` в логе нет ни одного — все check'и зелёные.

### Проблемы

- **Ответ модели T1 не совпадает с исходником: во всех 1019 строках ответа x-прогон короче на 4 символа (56 вместо 60), при зелёных check'ах** — в исходнике x-прогон 60 (`.out`: `head -1 … | sed 's/^big-output-line-[0-9]* //' | tr -d '\n' | wc -c` = 60; распределение длин строк 78/79/80/81 для 10/90/900/2000 строк), в ответе — 56 на всех 1019 строках; `diff` ответа с первыми 1019 строками `.out` даёт 1019 расхождений. Check'и при этом: `check: truncation marker present — ok`, `check: full output file present and complete — ok`, `check: needle retrieved — ok` (стр. 1325–1327) — **critical**
- **Ответ T1 обрезан на 1019-й строке из 3000 (1981 строка, 66% исходника, потеряна)** — стр. 1255: `big-output-line[TRUNCATED]`; в ответе индексы 0–1018; `--- TURN T1 exit=0` (стр. 1256) и зелёные check'и — **critical**
- **Маркер усечения ответа ассистента неотличим от строки исходника** — `big-output-line[TRUNCATED]` (стр. 1255) выглядит как строка `big-output-line-N`, без указания «показано N из M» — **medium**
- **Маркер ужатия не совпадает с показанным фрагментом, первая строка окна режется пополам** — стр. 37: `[showing lines 2976-3000 of 3000 …]`, первая видимая строка — `ig-output-line-2975 xxxx…` (стр. 11, потерян ведущий `b`); стр. 187: `[showing lines 175-200 of 200 …]`, первая видимая строка — обрывок из 22 символов `xxxxxxxxxxxxxxxxxxxxxx` (стр. 159) без признака фрагмента; воспроизводится и на выводе всего в 200 строк — **high**
- **Check «full output file present and complete» проверяет одну строку** — `run-selftest.sh:218` `grep -q "big-output-line-2999" "$OUT_FILE"`; побайтовой сверки нет (модель сделала `cmp`/`cksum` вручную, вне check'ов) — **medium**
- **Check «needle retrieved» ищет по всей общей БД, а не по сессии прогона** — `run-selftest.sh:224` `strings -a "$SESSION_FOUND_IN" "$SESSION_FOUND_IN-wal" | grep -q "$NEEDLE"`; `CM-5581-A` встречается в **198 сессиях** / 470 сообщениях общей БД (было 149 / 377 в отчёте `20261021-053941`) — **high**
- **Вывод read-тулов в selftest-лог не попадает** — стр. 1261: `→ Read var/folders/…/tmp.K6gK28g2Il/doc.md` (только вызов, без результата); фактически needle получен через `tail -n 1` в bash (стр. 1263). Требование T2 «через read-тул» по логу не верифицируется — **medium**
- **Прогон пишет в production-память общей БД** — в T4 модель вызвала `put_in_operational_memory` (стр. 1298) → запись `mem_15cf41cab001enM6DfbeKbquwc` в `opencode.db`, общей со стоком (стр. 5 «check: data namespace shared with stock — ok»). В той же БД лежат записи прошлых прогонов: `ST-20261020-220907`, `ST-20261021-075854` (×2), `self-review/ST-20261021-082939`; уборки нет — **medium**
- **Путь read-тула показан без ведущего слэша** — стр. 1261: `→ Read var/folders/…/doc.md` (в предыдущем прогоне так же: `→ Read Users/vova/…`) — **low**
- **tmp-фикстуры не убираются на путях `fail`/`skip`** — `run-selftest.sh:41-42`: `skip()`/`fail()` делают `exit` без `rm -rf "$DOC_DIR"` (уборка только в строке 245 в конце); 4 осиротевших каталога с `big.txt`/`doc.md` (от 2026-10-20: 01:12, 01:28, 02:01, 19:13), по 264 КБ каждый; каталог текущего прогона удалён (прогон зелёный) — **low**
- **Накопление артефактов tool-output** — `~/.local/share/opencode/tool-output/`: 1282 файла / 62 МБ; `~/.local/share/opencode/shell/**/*.out`: 653 файла / 7,7 МБ (было 1278 / 63 МБ и 597 / 6,7 МБ) — **low**
- **В трейлере только `started_ms`, длительности нет** — стр. 1328: `acceptance: … sentinel=ST-20261021-082939 started_ms=1792560579000`; фактические 299 с есть только в `chain-state.jsonl` — **low**
- **Плагин-конфиг указывает на файлы, а не на каталоги** — 580 WARN `configured plugin path must be a directory` в `opencode.log` за всё время (было 469 в отчёте `20261021-053941`, 486 по ROADMAP цикла 14) — **medium**
- **Долгоиграющий интерактивный сервер на устаревшем билде** — `run=72aba505`, старт 2026-10-20T01:41:38Z, `version=0.0.0-fork-at-7a12f66b4abc` при установленном `1b3dc3065485`; 3 ошибки `AI.Error: every rung failed` в окне прогона (05:29–05:35Z), 182 за всё время (было 133) — **medium**

### Паттерны

- **Дефект «ответ модели ≠ исходник при зелёных check'ах» воспроизводится 7-й прогон подряд, и сигнатура дефекта каждый раз другая**: 05:21 — 2099 строк с неверной длиной x-прогона; 05:39 — 589 строк + мусор `big-output-line Pennsylvania`; 08:29 — 1019 строк, все с равномерным −4 (56 вместо 60), без мусора и без сдвинутых индексов. Общее одно: check'ы остаются зелёными.
- **Харнесс режет вывод по границе символа, а не по строке, и одинаково портит первую строку окна** — окна `2976-3000 of 3000` (25 строк), `2938-3006 of 3006` (69 строк), `175-200 of 200` (26 строк); размер окна плавает, а первая строка каждого окна срезана посередине: в первом окне потерян ведущий `b` (`ig-output-line-2975`, стр. 11), в третьем виден только хвост `output` строки `MISMATCH at line 2938: output` (стр. 75), во втором — 22 символа вместо 78 (стр. 159).
- **Ответ ассистента усекается тем же маркером `[TRUNCATED]`, что и вывод тула, но без указания границ** — стр. 1255 `big-output-line[TRUNCATED]`; в ответе модели границы («показано 1019 из 3000») нет нигде.
- **Модель в этом прогоне впервые проверяет захват байт-в-байт и описывает его как лосслесный** — стр. 228–231: `cmp` → `IDENTICAL: byte-for-byte equal to the cat result`, `cksum 3201049549 244889` совпал для `big.txt`, регенерации и `.out`. Но сверялся только файл, а не её собственный ответ: длина x-прогона в ответе (56) с исходником (60) не сверялась, при этом в T4 модель утверждает «checked that all 3000 lines conform to the pattern `big-output-line-N <60 x>`» (стр. 233) — утверждение верно про исходник, но не про её ответ.
- **Ложные срабатывания растут вместе с общей базой** — needle-check 149 → **198 сессий**, 377 → **470 сообщений**; всего в общей БД 414 сессий / 24 688 сообщений (база общая со стоком и продолжает расти). Проверка проходит без привязки к текущей сессии.
- **Собственные баги диагностики модели воспроизводятся каждый прогон** — первый awk с `-F'[- ]'` дал 68 ложных `MISMATCH at line 2933…3000: output` (стр. 76–143) при корректном `mismatches: 0` во втором awk (стр. 148–150); на macOS не работают `stat -c` (стр. 190), `cat -A` (стр. 193), `md5` (стр. 212, 215) — отдельные вызовы тратятся на подбор `stat -f` / `cksum`; модель сама называет это «Мои собственные баги в проверках» (стр. 1313).
- **Регенерация исходника расходилась с оригиналом на 1 байт из-за отсутствующего финального `\n`** — стр. 219 (`250890`), 224 (`244890`) против `244889` у исходника; сошлось только после ручной правки `printf` (стр. 227–230) — признак того, что у self-test нет эталонного способа пересоздать входной файл.
- **Продолжительность selftest упала почти вдвое при том же объёме работы** — 575 с (05:21) → 299 с (08:29), при этом T1 в этом прогоне всё равно не уложился в лимит генерации.
- **Общая БД `opencode.db` разделяется со стоком** (стр. 5) — прогоны пишут в production-хранилище (сессии, memory-записи, needle-факты) без изоляции и без уборки; каждый прогон оставляет `mem_record` со scope прогона.
- **Каталог выводов shell общий для всех сессий пользователя** — `.out` прогона лежит в `~/.local/share/opencode/shell/e22c0befcd3aab577c593974d56decf884468691/` рядом с выводами живых сессий; с прошлых прогонов осталось 19 файлов >100 КБ (18 по 244 889 Б + один 401 687 Б); запасной путь check'а (`run-selftest.sh:207-210`) сканирует всю БД и берёт первый файл с `big-output-line-2999` — то есть может подхватить файл чужого прогона.
- **Секретов/PII в логе прогона не найдено** — grep по `token|secret|password|api_key` = 0 совпадений; в логе только локальные пути, внутренние ключи (`CM-5581-A`, `go/mimo`) и имя пользователя в путях.

### Идеи (as is)

- Проверять в прогоне содержимое ответа модели, а не только файлы на диске (например, сверка x-прогона и числа строк в stdout модели с исходником) — контекст: 1019/1019 строк ответа T1 с x=56 против x=60 в исходнике при зелёных check'ах.
- Скоупить needle-check по `session_id` (как check на маркер ужатия: `where session_id='$SESSION'`) — контекст: 198 сессий / 470 сообщений с `CM-5581-A` в общей БД (было 149 / 377).
- Дополнить check «full output file present and complete» побайтовой сверкой с исходником (`cmp -s` / `cksum` / `wc -l` + `wc -c`) — контекст: проверка ловит только одну строку, хотя в этом же прогоне `cmp`/`cksum` показали лосслессность захвата.
- Исправить маркер ужатия: указывать фактические границы показанного фрагмента либо не резать первую строку окна пополам — контекст: стр. 11 (`ig-output-line-2975`) и стр. 159 (обрывок из 22 символов) при окне в 200 строк; идея зафиксирована в отчёте `20261021-053941` и воспроизводится.
- Формулировать T1 так, чтобы «выведи результат как есть» не требовала дублирования 245 КБ в чат — контекст: 08:29, обрыв на `big-output-line-1018 [TRUNCATED]`, потеряно 1981 строка; ранее 05:21 и 05:39; идея зафиксирована в отчёте `20261021-053941` и воспроизводится.
- Логировать вывод read/grep-тулов в selftest-лог хотя бы первыми строками — контекст: стр. 1261, контент `doc.md` в логе отсутствует, needle получен через `tail -n 1`.
- Изолировать память прогонов от production-памяти либо убирать записи со scope прогона после прогона — контекст: 4 записи `mem_record` со scope прогонов (`ST-20261020-220907`, `ST-20261021-075854` ×2, `self-review/ST-20261021-082939`) в общей БД.
- Убирать tmp-фикстуры на любом выходе (`fail`/`skip`/`exit`) — контекст: `run-selftest.sh:41-42` выходит без `rm -rf "$DOC_DIR"`; 4 осиротевших каталога с `big.txt`/`doc.md` от 2026-10-20.
- Ограничивать накопление `~/.local/share/opencode/tool-output/` (1282 файла / 62 МБ) и `~/.local/share/opencode/shell/**/*.out` (653 файла / 7,7 МБ).
- Писать `dur_ms` в acceptance-трейлер рядом с `started_ms` — контекст: 299 с есть только в `chain-state.jsonl`.
- Валидировать пути плагинов в конфиге: требовать каталоги, отвергать файлы — контекст: 580 WARN `configured plugin path must be a directory` (было 469).
- Синхронизировать интерактивный сервер с установленным бинарём — контекст: `run=72aba505` живёт с 2026-10-20 01:41 на `7a12f66b4abc` при установленном `1b3dc3065485`, 182 ошибки `every rung failed` (было 133).

(Только констатация фактов из лога `20261021-082939`, `chain-20261021-0829.log`, `chain-state.jsonl`, `run-selftest.sh`, `opencode.log`, общей БД и состояния файлов; решения не предлагались.)

## BUG-REPORT 20261021-110731

Источник: `~/.opencode/scripts/selftest-logs/selftest-20261021-110731.log` (1058 строк / 60 921 Б, наибольший по mtime — 2026-10-21 11:18), цепочка `20261021-1107` (`chain-state.jsonl`: build exit=0 7 с → selftest exit=0 649 с → release exit=0 18 с → bug-reporter), контекст: `~/.opencode/scripts/release-current.md` (SHA `1b3dc3065485`), `run-selftest.sh`, `~/.local/share/opencode/log/opencode.log`, общая БД `~/.local/share/opencode/opencode.db`, локальный клон форка `/Users/vova/code/opencode-mem`, ITERATIONS (последние 10 записей), BUG-REPORT `20261021-082939`. Явных `FAIL`/`panic`/`assert` в логе нет ни одного, все ходы T1–T5 `exit=0`, все 4 check'а зелёные.

### Проблемы

- **Self-review проверял не тот исходник: установленный бинарь = `origin/main@1b3dc3065485`, а локальное дерево форка — detached `ef8a090233`, на 28 коммитов впереди и грязное** — стр. 1042: «рантайм, который реально исполнялся в этой сессии (не форк, а установленный бинарь `~/.opencode/bin/opencode`), выдал классический маркер `showing lines X-Y of N`»; стр. 1045: «`M packages/core/src/plugin.ts` (+283/−143), непроиндексированные `perf/ci-speed.md`, `specs/v2/scheduling-and-child-sessions.md`, `specs/v2/system-prompt-proposal.md`, ветка detached»; проверка: `git ls-remote origin main` = `1b3dc3065485aa6aa1ce81220182fe87df6791eb`, `git rev-list --count origin/main..HEAD` = **28** — **high**
- **Формат маркера усечения в рантайме и в коде форка разный — marker-check'ы проверяют устаревший контракт** — рантайм: `[showing lines 2976-3000 of 3000; full output saved to …/sh_15d8063610013XWb4KDtmGQA1w.out]` в `~/.local/share/opencode/shell/<session-dir>/` (стр. 36, 419, 1055); код форка: `output = \`...output truncated...\n\nFull output saved to: ${file}\n\n\` + output` (`packages/opencode/src/tool/shell.ts:578`, цитата стр. 752) и `TRUNCATION_DIR = path.join(Global.Path.data, "tool-output")` (`packages/opencode/src/tool/truncation-dir.ts:3`, цитата стр. 766); коммит `2804c59f69 refactor(core): unify tool output spilling and remove legacy truncation (#127)` **не является предком** собранного SHA (`git merge-base --is-ancestor 2804c59f69 1b3dc3065485` → false) — **high**
- **Check «needle retrieved» ищет иглу по всей БД, а не в сессии прогона** — `run-selftest.sh:224`: `strings -a "$SESSION_FOUND_IN" "$SESSION_FOUND_IN-wal" | grep -q "$NEEDLE"`; игла сейчас в **249 сессиях** из 469 в `session_message` (было 200 по циклу 15; в живой таблице `part` — только 8 сессий / 9 частей). Проверка прошла бы и при нулевом попадании текущего прогона — **high**
- **Check «full output file present and complete» проверяет одну строку** — `run-selftest.sh:218` `grep -q "big-output-line-2999" "$OUT_FILE"`; побайтовой сверки в харнессе нет — её вручную сделала модель: `cmp` → `IDENTICAL` (стр. 43), `cksum 3201049549 244889` совпал (стр. 362-368), `sha256 1b2f9b77…8c65` совпал (стр. 364, 368) — **medium**
- **Запасной путь поиска файла вывода может взять файл чужого прогона** — `run-selftest.sh:207-210`: сканирует всю БД по `full output saved to /…` и берёт первый файл, где есть `big-output-line-2999` — **medium**
- **Check `candidate == installed` отсутствует** — `run-selftest.sh:65-67` только печатает `installed binary: opencode v0.0.0-fork-at-1b3dc3065485` (стр. 4 лога), гейт (стр. 68-70) проверяет лишь, что SHA кандидата есть в его собственной версии; в трейлере (стр. 1058) обе версии равны `1b3dc3065485`, но равенство не проверяется — **medium**
- **Прогон пишет память в общую с production БД** — `mem_record` **37 → 40**: `ST-20261021-110731` ×2 (стр. 404, 489), `self-review/ST-20261021-110731` ×1; записей со scope прогонов всего 7 (`ST-20261021-110731` ×2, `ST-20261021-075854` ×2, `self-review/ST-20261021-110731`, `self-review/ST-20261021-082939`, `ST-20261020-220907`); БД общая со стоком — стр. 5 «check: data namespace shared with stock — ok» — **medium**
- **Вывод read/MCP-тулов в selftest-лог не попадает** — стр. 465 `→ Read var/folders/…/tmp.NJ9F7Rs9bc/doc.md` (только вызов, без результата), стр. 532 `→ Read …/sh_15d8063610013XWb4KDtmGQA1w.out [offset=3000, limit=1]` (без содержимого), стр. 290 `⚙ execute {…}` и стр. 349 `⚙ search_operational_memory {…}` — тоже только вызовы, результаты MCP-тулов лежат в `~/.local/share/opencode/tool-output/tool_…` (стр. 351). Требование T2 «через read-тул» и факт ретрива по логу не верифицируются — **medium**
- **Харнесс режет вывод по границе символа, а не по строке** — стр. 10: первая видимая строка окна — `ig-output-line-2975 xxxx…` (потерян ведущий `b`) при маркере «showing lines 2976-3000 of 3000» (стр. 36); воспроизводится в прогоне `075854`, стр. 10 — **medium**
- **Плагин-конфиг указывает на файлы, а не на каталоги** — 705 WARN `configured plugin path must be a directory` в `~/.local/share/opencode/log/opencode.log` (было 583 на цикле 15, 580 в отчёте `20261021-082939`) — **medium**
- **Провайдерские ошибки в логе рантайма: 211 `every rung failed`** (было 182 в отчёте `20261021-082939`); последняя — `2026-10-21T08:19:59.522Z`, `run=58c39c03`, `AI.Error.ProviderInternal: every rung failed` — **medium**
- **Накопление артефактов вывода** — `~/.local/share/opencode/tool-output/`: 1295 файлов / 59 МБ (было 1282 / 62 МБ); `~/.local/share/opencode/shell/**/*.out`: 750 файлов / 8,7 МБ (было 653 / 7,7 МБ) — **low**
- **tmp-фикстуры не убираются на путях `fail`/`skip`** — 4 осиротевших каталога с `big.txt`/`doc.md` от 2026-10-20 (01:12, 01:28, 02:01, 19:13); каталог текущего прогона `tmp.NJ9F7Rs9bc` удалён — зелёный путь чистит — **low**
- **В трейлере только `started_ms`, длительности нет** — стр. 1058: `acceptance: candidate_sha=1b3dc3065485 … sentinel=ST-20261021-110731 started_ms=1792570051000`; фактические 649 с есть только в `chain-state.jsonl` — **low**
- **Пять собственных сбоев диагностики модели (не дефект продукта, но съедают ходы)** — `md5` отсутствует в zsh (стр. 363, 367: `zsh:3: command not found: md5`); zsh-глобинг ломает `grep --include=*.ts` (стр. 581, 584, 587: `no matches found: --include=*.ts`, ещё стр. 657, 917); `awk` с `sprintf("%60s","")` → `awk: syntax error at source line 3` (стр. 309-313); python-скрипт → `AttributeError: 'str' object has no attribute 'get'` (стр. 254-256); `which opencode` → `opencode not found` (стр. 897). Модель перечисляет их сама (стр. 1036-1039) — **low**

### Паттерны

- **Дефект «ответ модели ≠ исходник» не воспроизвёлся в 9-й прогон подряд при неизменной формулировке T1** — T1 в `110731` (стр. 6) и в `082939` (стр. 6) текстово совпадают (различаются путь и sentinel); в этом прогоне модель не дублировала дамп, а сослалась на файл, дала 6 дословных цитат (стр. 438-445) и таблицу сверок (стр. 426-434); в `082939` ответ обрывался на `big-output-line-1018 [TRUNCATED]`. Значит дефект зависит от поведения модели, а не только от формулировки T1 — гипотеза цикла 15 («корень в формулировке хода T1») не подтверждена: формулировку между прогонами не меняли
- **Первый прогон, где лосслессность захвата подтверждена машинно внутри самого прогона** — `cmp` → `IDENTICAL` (стр. 43), `cksum 3201049549 244889` совпал для исходника и `.out` (стр. 362-368), `sha256 1b2f9b77…8c65` совпал (стр. 364, 368), построчная сверка python: `all 3000 lines match 'big-output-line-<N> ' + 60 x : True` (стр. 346), `ends with newline: False` (стр. 347)
- **Игла в общей БД продолжает самораздуваться** — 153 → 200 → **249** сессий из 469 в `session_message`; в живой `part` — 8 сессий / 9 частей; `strings` по файлу БД+WAL находит 1104 вхождения литерала (в основном мёртвые страницы) — check не скоупится и будет проходить на остаточном мусоре
- **Длительность selftest выросла в 2,2 раза при том же объёме работы** — 575 с (05:21) → 299 с (08:29) → **649 с** (11:07, `chain-state.jsonl`), все ходы `exit=0`, 4/4 check'а зелёные
- **Почти половина прогона ушла в «разведку репозитория» внутри финального хода** — T4: стр. 554-1048 из 1058 строк лога (≈47%) — 20+ shell-вызовов к `/Users/vova/code/opencode-mem` (стр. 555-1004) при задании «Ответь по-русски, кратко» (стр. 552)
- **Расхождение рантайма и форка впервые попало в отчёт прогона как «удивило», а не как «дефект»** — стр. 1042-1045; в предыдущем прогоне (`075854`, стр. 373-377) отчёт был «ничего не сломалось»
- **Регрессионная сверка с прошлыми циклами** — не воспроизвелись: «ответ ≠ исходник» (см. выше) и «сервер на устаревшем билде» (`opencode serve --service` pid 47846, старт 2026-10-21 10:59:32, установлен тот же SHA `1b3dc3065485`); воспроизвелись и выросли: игла без скоупа (200 → 249 сессий), плагин-WARN (583 → 705), `every rung failed` (182 → 211), накопление артефактов (tool-output 1282 → 1295 файлов, `.out` 653 → 750)
- **База памяти выросла 37 → 40, и все три новые записи — от прогона** (scope `ST-20261021-110731` ×2, `self-review/ST-20261021-110731` ×1); органических memory-вызовов по-прежнему 0; тип `user_signal` уже не новый (введён на цикле 15)
- **Секретов/PII в логе не найдено** — только ссылка на файл токена (`"apiKey": "{file:~/agent-tokens/llm-ladder/token}"`, стр. 213) и пути к `admin-token` (стр. 232-235); значений нет
- **Цепочка пересобрала тот же SHA** — build 11:07 (exit=0, 7 с) собрал `1b3dc3065485`, release 11:18 (exit=0, 18 с) опубликовал тот же SHA; `release-current.md` не изменился по сути — нового кода в цикле нет, `#188` открыт

### Идеи (as is)

- Привязывать self-review к той ревизии, которую реально собрали: печатать в трейлер SHA рабочего дерева форка и `git status --porcelain` рядом с `candidate_sha` — контекст: стр. 1042-1045; локальное дерево на 28 коммитов впереди `origin/main` и грязное
- Добавить check «формат маркера усечения совпадает с кодом форка» (сам маркер + каталог артефакта) — контекст: стр. 36 (рантайм, `shell/<session-dir>/sh_*.out`) против стр. 752/766 (код: `...output truncated...`, `Global.Path.data/tool-output`)
- Скоупить needle-check по `session_id` — контекст: `run-selftest.sh:224` (вся БД), игла в 249 сессиях из 469
- Дополнить check «full output file present and complete» побайтовой сверкой с исходником (`cmp -s` / `cksum`) — контекст: `run-selftest.sh:218` (одна строка), в этом же прогоне сверка руками дала `IDENTICAL` (стр. 43)
- Убрать fallback-поиск файла вывода по всей БД — контекст: `run-selftest.sh:207-210`
- Добавить check `candidate == installed` — контекст: `run-selftest.sh:65-70` (только печать версии)
- Логировать вывод read/MCP-тулов в selftest-лог — контекст: стр. 465, 290, 349 (только вызовы, результатов нет)
- Убирать tmp-фикстуры на любом выходе (`fail`/`skip`/`exit`) — контекст: `run-selftest.sh:41-42`; 4 осиротевших каталога от 2026-10-20
- Писать `dur_ms` в acceptance-трейлер рядом с `started_ms` — контекст: стр. 1058; фактические 649 с только в `chain-state.jsonl`
- Изолировать память прогонов от production-БД либо убирать записи со scope прогона — контекст: `mem_record` 37 → 40, записей прогонов 7
- Валидировать пути плагинов в конфиге (требовать каталоги, отвергать файлы) — контекст: 705 WARN (было 583)
- Перезапускать долгоживущий `opencode serve --service` при смене установленного бинаря — контекст: pid 47846 старт 2026-10-21 10:59:32 vs переустановка бинаря релизом в 11:18
- Проверить гипотезу «корень дефекта "ответ ≠ исходник" — формулировка T1»: формулировка между прогонами `082939` и `110731` не менялась (стр. 6 в обоих), а дефект не воспроизвёлся
- Ограничивать рост `~/.local/share/opencode/tool-output/` и `~/.local/share/opencode/shell/**/*.out` — контекст: 1295 / 59 МБ и 750 / 8,7 МБ

(Только констатация фактов из лога `20261021-110731`, `chain-state.jsonl`, `run-selftest.sh`, `opencode.log`, общей БД, состояния локального клона форка и `release-current.md`; решения не предлагались.)

## BUG-REPORT 20261021-121221

Источник: `~/.opencode/scripts/selftest-logs/selftest-20261021-121221.log` (390 строк / 26 302 Б, наибольший по mtime — 2026-10-21 12:13), контекст: `~/.opencode/scripts/release-current.md` (SHA `1b3dc3065485`), `run-selftest.sh`, `~/.opencode/scripts/chain-state.jsonl`, `~/.opencode/scripts/selftest-last.json`, `~/.local/share/opencode/log/opencode.log`, общая БД `~/.local/share/opencode/opencode.db`, исходники собранного SHA в `/Users/vova/code/opencode-mem-verify` (`1b3dc3065485`, чистый, 0 коммитов впереди `origin/main`), `ISSUES.md`, ITERATIONS (последние 10 записей), BUG-REPORT `20261021-110731`. Явных `FAIL`/`Error`/`panic`/`assert` в логе **ноль** (`grep -n -E 'FAIL|Error|panic|assert'` — пусто), все ходы T1–T5 `exit=0`, все 4 check'а зелёные.

### Проблемы

- **Харнесс отдаёт модели только хвост вывода — начало команды в контекст не попадает никогда** — стр. 143: маркер «[showing lines 2911-3011 of 3011]» при том, что в начале вывода были `wc -l`, `head -3`, `tail -3` (в сохранённом файле это строки 1–6, см. стр. 173-177); модель в T4 назвала это само: стр. 373 «У второго вызова обрезалась **середина**: `wc -l`, `head -3`, `tail -3` потерялись»; механизм в собранном исходнике: `packages/core/src/shell.ts:239` `page = output(info.id, { cursor: Math.max(0, latest.size - maxBytes), limit: maxBytes })` (читается **последние** `MAX_BYTES = 2 * 1024` Б, `packages/core/src/tool-output.ts:16`) и `shell.ts:243` `lines.slice(-maxLines)`; маркер `shell.ts:247` `[showing lines ${total - shown + 1}-${total} of ${total}; …]` — окно всегда хвостовое — **medium**
- **Граница окна режется по байту, а не по строке — первая показанная строка бывает обрезана** — стр. 11: первая видимая строка `ig-output-line-2975 xxxx…` (потерян ведущий `b`) при маркере «showing lines 2976-3000 of 3000» (стр. 37); причина — `cursor = latest.size - maxBytes` (`shell.ts:239`) попадает внутрь строки, а счётчик строк в маркере считается от байтового среза — **medium**
- **Гонка при чтении файла полного вывода: сразу после хода файла ещё нет, через секунду он есть** — стр. 147: `grep: /Users/vova/.local/share/opencode/shell/e22c0befcd3aab577c593974d56decf884468691/sh_15dbbd44c001aQ5QNBEMT3vUbt.out: No such file or directory`; стр. 149-167 `ls -la` того же каталога показывает этот же файл (`62603` Б, 12:12); повтор через стр. 171-172 отработал. Модель в T4: стр. 374 «Первый `grep` … вернул `No such file or directory`, хотя `ls` сразу после показал файл существующим … Файл, видимо, ещё не успел смэк-флюшнуться» — **medium**
- **`release-current.md` обещает несуществующие флаги v2** — `~/.opencode/scripts/release-current.md`: «## Флаги v2 — `OPENCODE_CACHE_MASK=0` … `OPENCODE_CACHE_MARK_IDLE_MS`»; в исходниках собранного SHA (`opencode-mem-verify@1b3dc3065485`) `grep -rn 'OPENCODE_CACHE_MASK|OPENCODE_CACHE_MARK_IDLE_MS' packages/` даёт **ровно одно попадание — юнит-тест** `packages/core/test/session-model-request-hooks.test.ts:164`, озаглавленный «ignores a legacy warm ledger and mask flag on consecutive requests», т.е. в проде флаг **игнорируется**; таблица `provider_cache_mark` в живой БД — **0 строк** — **high**
- **Харнесс экспортирует и проверяет эти же мёртвые флаги, считая их действующими** — `run-selftest.sh:38-39` `export OPENCODE_CACHE_MASK=1` / `export OPENCODE_CACHE_MARK_IDLE_MS=600000`; комментарий `run-selftest.sh:129` «так флаги форка (OPENCODE_CACHE_MASK и т.п.) действуют именно на эту проверку»; в вендоренной проверке (стр. 120) «> 2 КиБ (лимит v2) и > 2000 строк (лимит v2)» — фактические лимиты в коде есть (`tool-output.ts:13,16` = 2000 строк / 2 КиБ), а сами флаги — нет — **medium**
- **Игла `CM-5581-A` не нова — ретрив не создал новой записи памяти** — стр. 314: «активная запись `mem_15d859f2b0012ESZl5GBVCwl7P` (subject: `cache-mark ledger`), извлечённая в прогоне ST-20261021-075854 и перепроверенная в ST-20261021-110731»; стр. 318: «Новую запись в `put_in_operational_memory` **не создавал** … это бы создало дубль»; в БД `mem_record` **49** записей, со scope `ST-20261021-121221` — **0** (предыдущий прогон дал 3 записи: `ST-20261021-110731` ×2 + `self-review/ST-20261021-110731` ×1) — **medium**
- **Check `candidate == installed` отсутствует** — `run-selftest.sh:64-71` печатает обе версии (стр. 66-67) и гейтит только наличие SHA в версии кандидата; равенство не проверяется, хотя в трейлере (стр. 390) `candidate=…1b3dc3065485 installed=…1b3dc3065485` — **medium** (перенесено из `20261021-110731`)
- **Check «needle retrieved» ищет иглу по всей БД, а не в сессии прогона** — `run-selftest.sh:224` `strings -a "$SESSION_FOUND_IN" "$SESSION_FOUND_IN-wal" | grep -q "$NEEDLE"`; в живой БД игла лежит в **296 сессиях из 522** (`session_message`, было 249 из 469 в цикле `110731`) — **high** (перенесено)
- **Check «full output file present and complete» проверяет одну строку** — `run-selftest.sh:218` `grep -q "big-output-line-2999" "$OUT_FILE"`; побайтовой сверки нет (её вручную сделала модель: `cmp` → `IDENTICAL`, стр. 202, md5 `147c2f70…` совпал, стр. 200-201) — **medium** (перенесено)
- **Запасной путь поиска файла вывода сканирует всю БД** — `run-selftest.sh:207-210` (берёт первый файл с `big-output-line-2999` из всех найденных маркеров) — **medium** (перенесено)
- **Вывод read/MCP-тулов в selftest-лог не попадает** — стр. 277-279 `→ Read var/folders/…/tmp.Gk22jUKlxF/doc.md` (только вызов, без результата), стр. 281 `⚙ search_operational_memory {"query":"cache mark go/mimo|CM-5581-A|provider go/mimo"}` (только вызов) — **medium** (перенесено)
- **tmp-фикстуры не убираются на путях `fail`/`skip`** — `run-selftest.sh:245` `rm -rf "$DOC_DIR"` стоит только на успешном пути (после всех check'ов), `fail()` (стр. 42) и `skip()` (стр. 41) уходят без уборки; осиротевшие каталоги на диске: 4 от 2026-10-20 (01:12, 01:28, 02:01, 19:13) + 4 от 2026-10-19 (23:40–23:42); каталог текущего прогона `tmp.Gk22jUKlxF` удалён — зелёный путь чистит — **low** (перенесено)
- **Цепочка `20261021-1351` не зелёная: сборка пропущена, selftest и release withheld** — `chain-state.jsonl`: `{"ts":"2026-10-21T13:51:28+03:00","run":"20261021-1351","step":"build","exit":78,"dur_s":1,"status":"skipped"}`, `selftest exit=77 withheld`, `release exit=77 withheld`; `build-logs/build-20261021-135127.log`: «BUILD SKIPPED: мало места на диске (4 GiB свободно, нужно ≥5 GiB) — сборка упала бы на 'standalone module graph: Io'»; `df` на момент проверки: 4.5 GiB avail на `/System/Volumes/Data` (98%) — предыдущий цикл `20261021-1107` был зелёный 4/4 — **medium**
- **Плагин-конфиг указывает на файлы, а не на каталоги** — 772 WARN `configured plugin path must be a directory` в `~/.local/share/opencode/log/opencode.log` (было 705 в отчёте `20261021-110731`, 583 на цикле 15) — **medium** (перенесено)
- **Провайдерские ошибки в логе рантайма растут** — 245 строк `AI.Error.ProviderInternal: every rung failed` (было 211 в отчёте `20261021-110731`); последняя — `2026-10-21T10:53:21.270Z` — **medium** (перенесено)
- **Накопление артефактов вывода** — `~/.local/share/opencode/tool-output/`: 1323 файла / 60 МБ (было 1295 / 59 МБ); `~/.local/share/opencode/shell/**/*.out`: 829 файлов / 9,5 МБ (было 750 / 8,7 МБ) — **low** (перенесено)
- **В ответе модели появился смешанный алфавит (китайские иероглифы в русском тексте)** — стр. 373: «осталась только尾部-часть» (尾部 = «хвост») — в предыдущих отчётах такого не встречалось — **low**
- **В трейлере только `started_ms`, длительности нет** — стр. 390: `acceptance: candidate_sha=1b3dc3065485 … sentinel=ST-20261021-121221 started_ms=1792573941000`; фактической длительности в трейлере нет вовсе — **low** (перенесено)

### Паттерны

- **Явных падений в прогоне нет ни одного** — `grep -n -E 'FAIL|Error|panic|assert'` по логу `20261021-121221` пуст; все ходы T1–T5 `exit=0` (стр. 272, 321, 340, 380, 384), все 4 check'а «ok» (стр. 385-389), `selftest-last.json` = `status: ok`, `session: ses_selftest-20261021-121221`, `sentinel: ST-20261021-121221`
- **Дефект «ответ модели ≠ исходник» не воспроизвёлся в 10-й прогон подряд** — модель в T1/T4 сослалась на файл, дала дословные цитаты (стр. 220-244, 336) и машинную сверку `md5`/`cmp` (стр. 200-202: `IDENTICAL: saved output == source file`, оба `147c2f70c37d97fd3221d00e2f799734`), формат линий и нумерация проверены awk'ом (стр. 212-213: «OK: 3000 lines, format uniform, index 0..2999 strictly sequential»); формулировка T1 между прогонами `110731` и `121221` не менялась (стр. 6 в обоих)
- **Лосслессность захвата подтверждена машинно внутри самого прогона** — стр. 199-202: `md5 -q` исходника и сохранённого `.out` совпали, `cmp -s` → `IDENTICAL`; полный вывод действительно лежит в файле (244 889 Б, 3000 строк), т.е. «сжали, но ничего не прячем» — в этом прогоне подтверждено
- **Селftest `20261021-121221` шёл вне цепочки** — в `chain-state.jsonl` нет ни одной записи с этим stamp'ом (записи идут `20261021-1107` → 11:51, затем `20261021-1351` → 13:51), при этом `selftest-last.json` обновлён в 12:13 — прогон был ручным, а не шагом цепочки
- **Харнесс в этом прогоне работал на правильном исходнике** — `run-selftest.sh:21` `VERIFY=/Users/vova/code/opencode-mem-verify`, клон чистый на `1b3dc3065485` (0 коммитов впереди `origin/main`), кандидат = `~/.opencode/candidates/1b3dc3065485/opencode` (стр. 2-4), ходы идут через `--standalone` на кандидате (`run-selftest.sh:101,133`); грязный клон `/Users/vova/code/opencode-mem` (`ef8a090233`, 28 коммитов впереди, `M packages/core/src/plugin.ts` + 3 untracked) харнессом **не используется** — это тот самый клон, который в `20261021-110731` читала модель в финальном ходе, и на нём же в отчёте `20261021-110731` был заведён ложный «high» про несовпадение формата маркера
- **Формат маркера в рантайме и в собранном исходнике совпадает** — рантайм: `[showing lines 2976-3000 of 3000; full output saved to … — read or grep that file instead of re-running the command]` (стр. 37, 143, 350); исходник собранного SHA: `packages/core/src/shell.ts:247` — та же строка; расхождение, заявленное в `20261021-110731` («`...output truncated...` + `TRUNCATION_DIR` в `packages/opencode/src/tool/shell.ts:578`»), в SHA `1b3dc3065485` не воспроизводится: `grep -rn 'output truncated|TRUNCATION_DIR' packages/` даёт только совпадения в TUI-мини-транспорте, а каталог артефактов — `Global.Path.data/shell/<project>/sh_*.out` (`shell.ts:34,86,97,279`)
- **Fixture без завершающего перевода строки → `wc -l` на единицу меньше числа строк** — `big.txt`: 3000 строк, `wc -l` = 2999 (стр. 173, 260), `doc.md`: 402 строки, последний байт — `.` (стр. 288, 308); причина — `run-selftest.sh:118,124` пишет через `'\n'.join(lines)`; счётчик в рантайме это учитывает: `shell.ts:244` `total = newlines + (page.output.endsWith("\n") ? 0 : 1)`
- **Органика памяти по-прежнему нулевая, а объём БД памяти растёт не от прогонов** — `mem_record`: 40 → **49**, из них 35 записей с пустым scope, 4 — `research-20261021-1138`, 2 — `issue-161`, 2 — `ST-20261021-110731`, 2 — `ST-20261021-075854`, по 1 — `self-review/ST-20261021-110731`, `self-review/ST-20261021-082939`, `issue-158-research`, `ST-20261020-220907`; записей со scope `ST-20261021-121221` нет вовсе
- **Модель в прогоне осознанно не дублировала запись — дедуп по содержанию, а не по id** — стр. 314-318: найденная активная запись `mem_15d859f2b0012ESZl5GBVCwl7P` совпала по ключу `CM-5581-A`, источнику (`doc.md`, строка 402, маркер `NEEDLE-DOC`), sha256 `351840ca…` и размеру 22 358 Б — модель предложила `supersedes` (версия → 2) или новый `scope` вместо дубля
- **Запрос к памяти в прогоне был, но записи не было** — стр. 281 `⚙ search_operational_memory {"query":"cache mark go/mimo|CM-5581-A|provider go/mimo"}` — единственный memory-вызов в логе; `get_operational_memory` не вызывался
- **Легаси-фича «cache mark» в v2 мертва** — `provider_cache_mark` в живой БД: 0 строк; прод-код v2 не читает `OPENCODE_CACHE_MASK` (только тест, который это игнорирование и фиксирует); при этом `run-selftest.sh:38-39` и `release-current.md` продолжают ссылаться на неё как на рабочую
- **Ретенция артефактов работает, но объём монотонно растёт** — `packages/core/src/shell.ts:33` `RETENTION = Duration.days(7)`, `tool-output.ts:17` то же, чистка ежечасно (`shell.ts:110`); старейший `.out` в `shell/` — 2026-10-19 (2 суток), всего 829 файлов / 9,5 МБ на 133 каталога
- **Секретов/PII в логе не найдено** — сканирование лога на e-mail, телефон, `ghp_`/`github_pat_`/`sk-`/`Bearer` — пусто; в логе только пути к tmp-фикстурам и хэши
- **Длительность прогона в трейлере не фиксируется** — ни `dur_ms`, ни иных метрик времени в стр. 390 нет; `selftest-last.json` содержит только `checked_at` (`2026-10-21T09:13:52Z`)

### Идеи (as is)

- Показывать в маркере усечения, что окно — хвост (или отдавать начало вывода, а не конец) — контекст: `shell.ts:243,247` (`slice(-maxLines)`, окно `${total-shown+1}-${total}`); в прогоне модель читала потерянные `wc -l`/`head -3` как «обрезалась середина»
- Резать страницу вывода по границе строки, а не по байтовому курсору — контекст: `shell.ts:239` (`cursor: latest.size - maxBytes`) → стр. 11 (`ig-output-line-2975` без ведущего `b`)
- Гарантировать появление файла полного вывода до возврата результата хода (или явно документировать ретрай) — контекст: стр. 147 (`No such file or directory`) против стр. 149-167 (файл есть, 62 603 Б)
- Ввести гейт `candidate == installed` — контекст: `run-selftest.sh:64-71`, стр. 390 трейлера
- Скоупить needle-check по `session_id` — контекст: `run-selftest.sh:224`, игла в 296 сессиях из 522
- Заменить check «full output file present and complete» на побайтовую сверку (`cmp`/`cksum`/`sha256`) — контекст: `run-selftest.sh:218`, ручная сверка в прогоне дала `IDENTICAL` (стр. 200-202)
- Убрать fallback-поиск файла вывода по всей БД — контекст: `run-selftest.sh:207-210`
- Логировать вывод read/MCP-тулов в selftest-лог — контекст: стр. 277-281 (только вызовы)
- Убирать tmp-фикстуры на любом выходе (`fail`/`skip`/`exit`) — контекст: `run-selftest.sh:245` только на успешном пути; 8 осиротевших каталогов на диске
- Убрать из `release-current.md` несуществующие флаги `OPENCODE_CACHE_MASK`/`OPENCODE_CACHE_MARK_IDLE_MS` либо реализовать их — контекст: `release-current.md` раздел «Флаги v2» vs `packages/core/test/session-model-request-hooks.test.ts:164` («ignores a legacy warm ledger and mask flag») и `provider_cache_mark` = 0 строк
- Убрать из `run-selftest.sh` экспорт мёртвых флагов и комментарий про их действие — контекст: `run-selftest.sh:38-39,129`
- Писать `dur_ms` в acceptance-трейлер рядом с `started_ms` — контекст: стр. 390; фактической длительности нет нигде в артефактах прогона
- Изолировать память прогонов от production-БД либо убирать записи со scope прогона — контекст: `mem_record` 40 → 49, записей прогонов 7
- Валидировать пути плагинов в конфиге (требовать каталоги, отвергать файлы) — контекст: 772 WARN (было 705)
- Разобрать рост `AI.Error.ProviderInternal: every rung failed` (211 → 245) — контекст: `~/.local/share/opencode/log/opencode.log`, последняя запись `2026-10-21T10:53:21.270Z`
- Ограничивать рост `~/.local/share/opencode/tool-output/` и `~/.local/share/opencode/shell/**/*.out` — контекст: 1323 / 60 МБ и 829 / 9,5 МБ (ретенция 7 дней работает, но объём растёт монотонно)
- Разобрать смешанный алфавит в ответе модели (китайские иероглифы в русском тексте) — контекст: стр. 373 («только尾部-часть»)

(Только констатация фактов из лога `20261021-121221`, `chain-state.jsonl`, `selftest-last.json`, `run-selftest.sh`, исходников собранного SHA `1b3dc3065485` в `opencode-mem-verify`, `opencode.log`, общей БД, `release-current.md` и `ISSUES.md`; решения не предлагались.)

## BUG-REPORT 20261021-165204

Источник: `~/.opencode/scripts/selftest-logs/selftest-20261021-165204.log` (390 строк / 26 576 Б, наибольший по mtime — 21 Oct 16:58), `~/.opencode/scripts/release-current.md` (SHA `1b3dc3065485`), `~/.opencode/scripts/run-selftest.sh`, `~/.opencode/scripts/chain-state.jsonl` (run `20261021-1651`), `~/.opencode/scripts/selftest-last.json`, живая БД `~/.local/share/opencode/opencode.db`, форк `/Users/vova/code/opencode-mem-work` (`1b3dc3065485aa6aa1ce81220182fe87df6791eb`), `ISSUES.md`, ITERATIONS (последние 10 записей, до цикла `20261021-1351`).
`FAIL`/`Error`/`panic`/`assert` в логе **ноль** (`grep -n -E 'FAIL|Error|panic|assert'` — пусто), все ходы T1–T5 `exit=0`, все 5 check'ов «ok».

### Проблемы

- **Маркер усечения и его полезная нагрузка расходятся: первая показанная строка обрезана по байту, маркер этого не отражает** — стр. 9–10: `$ cat .../big.txt` → `ig-output-line-2975 xxxx…` (потерян первый байт `b`), стр. 36: `[showing lines 2976-3000 of 3000; …]` — заявлено начало 2976, фактически показана частичная 2975. Механизм в форке: `packages/core/src/shell.ts:239` `page = output(info.id, { cursor: Math.max(0, latest.size - maxBytes), limit: maxBytes })` — курсор в байтах, `packages/core/src/tool-output.ts:16` `MAX_BYTES = 2 * 1024`. Воспроизведено **во всех 11 логах self-test за 2026-10-21** (проверено: ровно одна обрезанная первая строка в каждом). — **medium** (перенесено из BUG-REPORT `20261021-121221`)
- **Вывод read-тула в лог не попал ни одной строкой, хотя занял контекст модели** — стр. 58 `→ Read var/folders/…/big.txt [limit=3000]` → стр. 59 сразу `> build · build`; между ними нет ни одной строки вывода. Модель в T4 (стр. 376) сообщает: «read-тул обрезал вывод на 633 строках, несмотря на `limit=3000`, и показывал нумерацию строк». Документированный кап read-тула — 2000 строк (`packages/core/src/tool/plugin/read.ts:23`), т.е. 633 этим капом не объясняется; причина в логе не видна. — **medium** (перенос из цикла 17: «вывод read/MCP-тулов в лог не попадает»)
- **Три ложных «ANOMALY/MISMATCHES=3000» подряд — дефект проверочного скрипта модели, а не форка** — стр. 72–90 (`ANOMALY at line 2983: …`, `MISMATCHES=3000`), стр. 109–177 (`PAD-ANOMALY line 2934 len=60`, `MISMATCHES=3000`); модель сама диагностировала причину: стр. 99 «первая версия проверки дала ложные ANOMALY на всех 3000 строках — в awk приоритет выше у `-`, чем у конкатенации», стр. 374. Итог верен (стр. 198 `len=60 count=3000`, стр. 204 `records=3000 OK`, стр. 240 `0` несовпадений). Цена — 3 лишних хода внутри T1. — **low**
- **`md5` в macOS-окружении отсутствует — команда падает прямо в ходе прогона** — стр. 94: `zsh:11: command not found: md5`; модель перешла на `shasum -a 256` (стр. 108 → стр. 216). — **low**
- **Check `candidate == installed` по-прежнему отсутствует** — в логе 5 check'ов (стр. 5, 385, 387, 388, 389), ни один не сверяет кандидата с установленным бинарём; равенство видно только глазами (стр. 2–4: `1b3dc3065485` / `opencode v0.0.0-fork-at-1b3dc3065485`). В `run-selftest.sh` (строки 189, 213, 221, 227, 243) такого гейта нет. — **medium** (перенесено)
- **Check «full output file present and complete» = один `grep -q` по одному файлу, найденному фолбэком по всей БД** — `run-selftest.sh:218` `grep -q "big-output-line-2999" "$OUT_FILE"`, фолбэк `run-selftest.sh:207-210` сканирует `strings` по всей БД. В этом прогоне полнота всё же подтверждена независимо (см. «Паттерны»), но сам check этого не делает. — **low** (перенесено)
- **Needle-check не скоуплен по сессии — игла в БД размножилась до 355 сессий из 591** — `run-selftest.sh:224-225` `strings -a "$SESSION_FOUND_IN" "$SESSION_FOUND_IN-wal" | grep -q "$NEEDLE"`; в живой БД `CM-5581-A` встречается в **355** различных `session_id` из **591** в `session_message` (в цикле 17 было 296→303 из 522/530). Check `check: needle retrieved — ok (CM-5581-A)` (стр. 389) не доказывает ретрив в этой сессии: в `mem_record` нет **ни одной** записи со `session_id = ses_selftest-20261021-165204`. — **high** (перенесено)
- **Дефект реестра памяти не закрыт: 3 активные записи об одном факте `CM-5581-A`, цепочка `supersedes` неполна** — живая БД `mem_record`: `mem_15ab84a680010KlXCh5El0kDhB` (subject «cache mark key for provider go/mimo», active, v1, scope `ST-20261020-220907`, `supersedes` пусто, content «…stored under key CM-5581-A»), `mem_15e2ec85a001yOPeNVpm4Ree3h` (subject «cache-mark ledger», active, v2, `supersedes=mem_15d859f2b…`), `mem_15e2ec85c001GJiR2bZLb1nZCk` (subject «cache-mark ledger (дубликат консолидирован)», active, v2, `supersedes=mem_15cd768c8…`) — ни одна из трёх не вытесняет первую, `mem_15ab84a68…` остаётся активной и не вытесненной никем. — **medium** (перенос из цикла 17)

### Паттерны

- **Прогон полностью зелёный** — `grep -n -E 'FAIL|Error|panic|assert'` по логу пуст; T1–T5 `exit=0` (стр. 290, 326, 361, 380, 384); 5 check'ов «ok» (стр. 5, 385, 387, 388, 389); `selftest-last.json` = `status: ok`, `session: ses_selftest-20261021-165204`, `sentinel: ST-20261021-165204`, `checked_at 2026-10-21T13:58:37Z`.
- **Прогон впервые за два цикла прошёл ВНУТРИ цепочки** — `chain-state.jsonl`, run `20261021-1651`: `16:52:04 build exit=0 dur=11`, `16:58:37 selftest exit=0 dur=393`, `16:59:11 release exit=0 dur=34`. В цикле 17 полные прогоны `121221` и `141352` были ручными и вне `chain-state.jsonl`. Шаг `bug-reporter` в состоянии цепочки пока отсутствует (выполняется в момент написания отчёта).
- **Дефект «ответ модели ≠ исходник» не воспроизвёлся в 12-й прогон подряд** — T1: стр. 213 `bytes=  244889  lines_wc=    2999  records_awk=3000`, стр. 216 `sha256=1b2f9b77d9806aa10e32605d1d5ac88047b294661d9aefab42b635f1d34a8c65` (совпадает со стр. 178), стр. 198 `len=60 count=3000`, стр. 204 `records=3000 OK`, стр. 236 `records=3000 OK: field2 == whole-line-after-prefix, all 3000`, стр. 240 `0` несовпадений с `^big-output-line-[0-9]+ x{60}$`; ответ T4 стр. 249 — «ровно 60 символов "x"», стр. 257 — «`wc -l` 2999 → нет завершающего перевода строки на EOF (последний байт `0x78` = `x`)». Цикл 17 фиксировал «не воспроизвёлся в 11-й прогон» — теперь 12-й.
- **Лосслессность захвата подтверждена независимо от модели, по файлу на диске** — сохранённый `sh_15ebbe4e9001rRMJHcjd7EhS04.out`: 244 889 Б, 3000 записей, `sha256 1b2f9b77d9806aa10e32605d1d5ac88047b294661d9aefab42b635f1d34a8c65`, последний байт `0x78` — байт-в-байт совпадает с исходником `big.txt` (sha256 из стр. 216), т.е. «сжали, но ничего не спрятали» в этом прогоне действительно выполняется.
- **Пять источников по-прежнему дают один и тот же SHA — нового кода в цикле нет** — `release-current.md` SHA `1b3dc3065485`; стр. 2–4 candidate = installed = `1b3dc3065485`; `selftest-last.json.sha12 = 1b3dc3065485`; форк `/Users/vova/code/opencode-mem-work` HEAD = `1b3dc3065485aa6aa1ce81220182fe87df6791eb` (2026-10-20 21:57). Тот же SHA, что в циклах 12–17.
- **Органических вызовов memory-тулов по-прежнему 0** — в логе нет ни одного `put_in_operational_memory` / `search_operational_memory` / `get_operational_memory`; в `mem_record` нет ни одной записи со `session_id = ses_selftest-20261021-165204` (совпадает с «memory-тулы = 25 из 8049 (0.31 %) — вся органика 0» из цикла 17).
- **Диск: `~/.worktrees` = 36 GiB (то же значение, что в цикле 17 — prune не делали), свободно 6.2 GiB при пороге 5 GiB** — `du -sh ~/.worktrees` = 36 GiB; `df -h /` → `228Gi 12Gi 6.2Gi 66%`; build в этой цепочке пропущен не был (exit=0, 11 s) — запас до порога 1.2 GiB.
- **Плагины: WARN продолжает расти** — `grep -c WARN ~/.local/share/opencode/log/opencode.log` = 1121 (было 583 → 711 → 714 в циклах 15–17); в топе — `configured plugin path must be a directory`.
- **Накопление вывода на диске: 24 копии одного и того же файла по 244 889 Б (≈5.9 MiB) за 2 суток, по одной на каждый прогон** — 16 копий в каталоге `~/.local/share/opencode/shell/e22c0be…/` (мт 20 Oct 16:35 … 21 Oct 16:52) и ещё 8 в остальных 133 каталогах; всего 1015 файлов / 11 MiB, самый старый — 19 Oct 20:33. Очистка есть (`shell.ts:33` `RETENTION = Duration.days(7)`, ежечасно), но внутри окна хранения дубли не удаляются; за окно прогона 16:52–16:58 записано 9 файлов / 644 039 Б.
- **В логе нет ни одного секрета/персональных данных** — `grep -nEi 'api[_-]?key|bearer |secret|password|token'` по логу даёт только совпадения по слову `token` в шаблонных строках данных; email/телефонов нет; единственные абсолютные пути — локальные (`/Users/vova/.local/share/opencode/…`, `/Users/vova/.opencode/candidates/…`).

### Идеи (as is)

- «Т1 просит `выведи результат как есть`, но харнесс отдаёт модели только последние 2 KiB вывода (25 строк) — дословный вывод невозможен по построению» — контекст: стр. 6 (задание T1) против стр. 36 (маркер) и `packages/core/src/tool-output.ts:16`.
- «Проверка `candidate == installed` как отдельный гейт» — контекст: стр. 2–4 (обе версии совпадают) и `run-selftest.sh` (гейта нет).
- «Скоупить needle-check по `session_id` прогона» — контекст: стр. 291 `session: ses_selftest-20261021-165204`, игла в 355 сессиях из 591.
- «Заменить check «full output file present and complete» на побайтовую сверку (`sha256`/`cmp`) с исходником» — контекст: `run-selftest.sh:218` и стр. 216/178.
- «Печатать в маркере усечения, что окно начинается с байтовой границы и первая строка может быть обрезана» — контекст: стр. 10 (`ig-output-line-2975`) против стр. 36 (`showing lines 2976-3000`).
- «Логировать вывод read/MCP-тулов в selftest-лог» — контекст: стр. 58–59 (вывода нет), при модели, реально видевшей 633 строки (стр. 376).
- «Регулярный prune `~/.worktrees` вместо реакции на порог диска» — контекст: 36 GiB в `~/.worktrees`, свободно 6.2 GiB, порог 5 GiB.
- «Дедуп записей памяти по факту (`CM-5581-A`) при записи, а не при чтении» — контекст: 3 активные записи в `mem_record`, одна из них (`mem_15ab84a68…`) не вытеснена никем.
- «Проверка доступности `md5` в харнесс-окружении (или использование только `shasum`)` — контекст: стр. 94.
- «Сократить число проверочных ходов модели на однородном файле (7 bash-вызовов на 1 файл в T1)` — контекст: стр. 39, 60–70, 100–108, 184–196, 206–212, 230–235.

(Только констатация фактов из лога `20261021-165204`, `chain-state.jsonl`, `selftest-last.json`, `run-selftest.sh`, исходников форка `1b3dc3065485` в `opencode-mem-work`, `opencode.log`, живой БД (`mem_record`, `session_message`), `release-current.md`, `ISSUES.md` и последних 10 записей ITERATIONS; решения не предлагались.)
