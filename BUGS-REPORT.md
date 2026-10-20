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
