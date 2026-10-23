## BUG-REPORT 20261023-060854

### Проблемы
- T1 exit=0: модель отказала в выполнении команды cat (счла это "prompt injection attempt") — сам сценарий self-test не смог выполнить свой первый шаг; ни одного REAL-ошибка/сбой из лога — grep -E "FAIL|Error|panic|assert" → 0 совпадений, Critical: 0
- T3: в сессии T1-T3 нет работы bash-тула → к решению `"exit_code"/"failed"` из PR #69 нет live-покрытия, четвертый цикл подряд (самое начало отсутствует)
- T4: игла из промпта (`CM-5581-A`) найдена через read-тул напрямую, не через get_tool_call_details — retrieval-тул вообще не использовалась
- T5: ноль компакт-маркеров с `mem:` префиксом во всех успешных циклах (selftest-heavy) — компакция never включается; null/0/0 across cycle

### Паттерны
- Self-test scenario T1: модель определяет prompt injection — блокировка безопасности работает, но сценарий depends на выполнении bash-тул
- Нет tool-возврата/сохранения: grep/read вместо get_tool_call_details/обрезки; `mem:compacted` отсутствует в log
- Тот же последующий паттерн: T1-T3 uses only read/grep for needle (no bash), to PR #69, needle check structurally green (needle in T4), DONE before acceptance

### Идеи (as is)
- Сделать self-test T1 устойчивым к block'ам (не полагаться на безопасность model)
- Сценарий должен гарантировать использование get_tool_call_details → retrieval guard
- Критерий прогона should обрабатывать model refusal — EXIT должен быть >=1 для self-test T1 failure
- Проверка "качества" должна обрабатывать refusal — ножницами overlapping T1 and T3?

## BUG-REPORT 20261023-130047

Источник: `~/.opencode/scripts/selftest-logs/selftest-20261023-130047.log` (последний по mtime).

### Проблемы
- T1 провален ошибкой провайдера, прогон оборван на первом ходу — `Error: UnexpectedStatus: 500` → `--- TURN T1 exit=1`; в истории `selftest-logs/*.log` строка `UnexpectedStatus` встречается впервые — high
- Сессия не привязана к БД, оставшиеся ходы пропущены — `session: NOT-BOUND (sentinel 'ST-20261023-130047' не найден в opencode*.db[-wal]) — оставшиеся ходы пропущены`; T2–T5 не выполнялись, покрытия нет — high
- Цепочка не зелёная: chain-state `run=20261023-1300` — `build exit=0 (8 s) → selftest exit=70 (23 s) → release exit=77 withheld` — high
- Кандидат и установленный бинарь расходятся — `candidate: .../candidates/11455206b4b0/opencode (11455206b4b0)` / `installed binary: opencode v0.0.0-fork-at-021466337676`; проверялся не установленный бинарь — medium
- Отказ всех ступеней лестницы в тот же день — `Error: every rung failed` на всех ходах (091649, 010302, 010708) + `ход с дефолтной моделью пользователя (mem-gpt/build) не прошёл — форк не обслуживает модель по умолчанию` — high

### Паттерны
- Регресс серии за сутки: 084308 `T1–T5 exit=0` → 091649 `T1–T5 exit=1` → 112556 прерван до ходов (`verify-клон на 3bc22d510023, а кандидат на 021466337676 — проверялось бы не то`) → 130047 прерван на T1 — доказательство: exit-коды и строки `NOT-BOUND`/`UnexpectedStatus` по логам
- Лестница ретраит ход 10 раз и падает целиком: `> build · build` ×10 → `every rung failed` — доказательство: 091649/010302/010708
- Self-test не устойчив к инфра-сбою: один `500` на первом ходу обнуляет весь прогон (нет retry/partial) — доказательство: 130047
- Быстрый фейл вместо полного прогона: selftest 23 s против 399–566 s зелёных циклов — доказательство: chain-state 1300 vs 0253/0602
- Расхождение candidate/installed — норма пайплайна (кандидат собран, release withheld), но гард ловит только расхождение verify-клона — доказательство: 130047 vs 112556

### Идеи (as is)
- Retry/backoff на `UnexpectedStatus: 500` по ходу либо пометка прогона inconclusive вместо обрыва — контекст: 130047 T1
- Разделять инфра-сбой (`500` / `every rung failed`) и продуктовую регрессию в вердикте selftest — контекст: chain-state `selftest exit=70`
- Писать candidate SHA и installed SHA в chain-state для трассируемости — контекст: расхождение `11455206b4b0` / `021466337676`
- Разобраться, почему форк не обслуживает дефолтную модель `mem-gpt/build` — контекст: 091649 T5

## BUG-REPORT 20261023-205059

Источник: `~/.opencode/scripts/selftest-logs/selftest-20261023-205059.log` (последний по mtime). Цепочка: `chain-state.jsonl` run `20261023-2050`.

### Проблемы
- Три из пяти ходов упали, лестница не подняла ни одного ранга — `Error: every rung failed` → `--- TURN T3 exit=1` / `--- TURN T4 exit=1` / `--- TURN T5 exit=1` — critical
- Дефолтная модель пользователя не обслуживается — `ход с дефолтной моделью пользователя (mem-gpt/build) не прошёл — форк не обслуживает модель по умолчанию` (T5) — high
- Прогон оборван без вердикта: лог кончается строкой 169 без `=== SELFTEST 20261023-205059 DONE ===` и без `check: truncation marker present` / `check: needle retrieved` / `acceptance:` — high
- Расхождение кандидата и установленного бинаря — `candidate: .../candidates/f62df808f332/opencode (f62df808f332)` vs `installed binary: opencode v0.0.0-fork-at-9db2ce9a375d` — medium
- Цепочка не зелёная — `{"run":"20261023-2050","step":"selftest","exit":70,"dur_s":640,"status":"failed"}` и `{"step":"release","exit":77,"status":"withheld"}` — high
- T1 `exit=0` при невыполненной инструкции «выведи результат как есть»: harness обрезал вывод до 25 строк (`[showing lines 2976-3000 of 3000; ...]`), модель отказалась вставлять текст целиком — medium
- Needle найден не через retrieval-тул: T2 вернул `CM-5581-A` через `read` напрямую, `get_tool_call_details` не вызывался ни разу — medium

### Паттерны
- Лестница ретраит ход и падает целиком: в логе 55 вхождений `> build · build`, сгруппированных по 10 перед каждым `every rung failed` (T3/T4/T5) — доказательство: строки 128-138, 142-152, 157-167
- Регресс серии за сутки по числу упавших ходов: 164511 `T1–T5 exit=0` → 172641 `T3 exit=1` → 183352 `T1–T3 exit=1` (`Error: unauthorized`) → 193612 `T1 exit=1` → 205059 `T3,T4,T5 exit=1` — доказательство: `TURN T* exit=` в логах
- Длительность прогона растёт с числом ретраев лестницы: selftest `640 s` (2050, 3 упавших хода) против `196 s` (1833) и `23–24 s` (1300, 1543) — доказательство: `chain-state.jsonl`
- Симптом отказа лестницы меняется между прогонами: `unauthorized` (183352) → `every rung failed` (193612, 205059) — доказательство: строки `Error:` в логах
- Асимметрия лимитов вывода: `shell`/`cat` обрезается до 25 строк, а `read` отдал `doc.md` целиком (402 строки) в том же прогоне — доказательство: T1 маркер обрезки vs T2 `всего 402 строки`
- Компакт-маркеры с префиксом `mem:` отсутствуют во всех ходах — доказательство: `grep mem:` → 0 совпадений в логе
- Привязка сессии к БД в этом прогоне сработала (регресса `NOT-BOUND` нет) — доказательство: `session: ses_selftest-20261023-205059 (bound in /Users/vova/.local/share/opencode/opencode.db)`

### Идеи (as is)
- Не обрывать прогон на провале хода: писать финальные acceptance-проверки и вердикт даже при `exit=1`, чтобы лог не оставался без `DONE` — контекст: 205059
- Разделять инфра-сбой лестницы (`every rung failed` / `unauthorized`) и продуктовую регрессию в вердикте selftest — контекст: `selftest exit=70`
- Retry/backoff на `every rung failed` либо пометка прогона inconclusive — контекст: T3–T5
- Писать candidate SHA и installed SHA в chain-state для трассируемости — контекст: `f62df808f332` / `9db2ce9a375d`
- Сделать T1 устойчивым к усечению: не требовать «вывести как есть» для вывода, который harness гарантированно обрезает — контекст: T1 `showing lines 2976-3000 of 3000`
- Разобраться, почему лестница не обслуживает `mem-gpt/build` — контекст: T5

## BUG-REPORT 20261023-234346

Источник: `~/.opencode/scripts/selftest-logs/selftest-20261023-234346.log` (последний по mtime, 12490 б). Цепочка: `chain-state.jsonl` run `20261023-2343` (prune/build/selftest/release — все `exit=0`). Прогон зелёный: `T1–T5 exit=0`, все `check:`/`acceptance:` на месте. `grep -E "FAIL|Error|panic|assert"` → 0 совпадений. `ITERATIONS.md` содержит 3 записи без сравнительного анализа — регрессии сверялись по `selftest-logs/*.log` и `chain-state.jsonl`.

### Проблемы
- Кандидат и установленный бинарь расходятся (повтор цикла) — `candidate: .../candidates/f62df808f332/opencode (f62df808f332)` / `installed binary: opencode v0.0.0-fork-at-9db2ce9a375d` — medium
- T1 `exit=0` при невыполненной инструкции «выведи результат как есть» — harness отдал только хвост: `[showing lines 2976-3000 of 3000; full output saved to .../sh_16a829455001UOIRNJZN6lp1si.out ...]` (244889 б / 3000 строк) — medium
- Усечение сработало дважды за прогон — T1 `cat`, затем T3: «сам grep-вывод в этом ходе тоже был обрезан харнессом (та же тема с маркером `[showing … of …]`)» — low
- Retrieval-тул не вызывался ни разу: `get_tool_call_details` встречается только внутри текста маркера (`[retrieve the original output with get_tool_call_details(call_id="call_d5772a296f0b4fe5ba49d96d")]`), needle в T2 взят напрямую `read` — medium
- Компакт-маркеры с префиксом `mem:` отсутствуют во всём логе — `grep -c 'mem:'` → 0 — medium
- Шум Code Mode в каждом ходу — «Каждый ход приходил `system-update` о смене каталога Code Mode (4 раза, то «complete», то «partial») — для этой задачи шум, ни один из этих тулов не понадобился» (T4) — low

### Паттерны
- Восстановление после падения: 214529 `T5 exit=1` (`Error: every rung failed`) → 234346 `T1–T5 exit=0`, цепочка `20261023-2343` вся `exit=0` — доказательство: exit-коды и `chain-state.jsonl`
- Дефолтная модель снова обслужена, но нестабильно — `check: default model served — ok (mem-gpt/build)` (T5), против падений `mem-gpt/build` в 205059/214529 — доказательство: строка 165 лога
- Тренд упавших ходов за день вниз: 205059 `3` → 214529 `1` → 234346 `0` — доказательство: `grep -c 'TURN T[0-9] exit=1'`
- Длительность прогона падает вместе с числом ретраев: selftest `327 s` (2343, 0 падений) против `640 s` (2050, 3 падения) — доказательство: `chain-state.jsonl`
- Bash-тул в этом цикле реально отработал (в отличие от 060854, где модель отказалась) — `$ cat /var/.../big.txt` → `[showing lines 2976-3000 of 3000 ...]`, есть `call_id` — доказательство: строки 21, 48-49
- Асимметрия лимитов вывода сохраняется: `shell`/`cat` обрезан до 25 строк, а `read` в том же прогоне отдал `doc.md` целиком (402 строки, без маркера) — доказательство: T1 маркер vs T2 «402 строки»
- Маркер рекламирует ретрив, модель им не пользуется: `retrieve the original output` присутствует, но вызовов тула — 0 (T2/T3 — `read`/`grep`) — доказательство: строки 49, 104, 118
- Привязка сессии к БД в норме, регресса `NOT-BOUND` нет — `session: ses_selftest-20261023-234346 (bound in /Users/vova/.local/share/opencode/opencode.db)` — доказательство: строка 96

### Идеи (as is)
- Писать candidate SHA и installed SHA в `chain-state.jsonl` для трассируемости — контекст: `f62df808f332` / `9db2ce9a375d` (третий цикл подряд)
- Логировать факт вызова `get_tool_call_details` отдельным `check:` — контекст: маркер есть, вызовов 0
- Не требовать «вывести как есть» для вывода, который harness гарантированно обрезает — контекст: T1 `showing lines 2976-3000 of 3000`
- Разбираться, почему `mem:`-компакция не включается ни в одном прогоне — контекст: `grep -c 'mem:'` → 0
- Оценить шум `system-update` Code Mode в selftest-сценарии — контекст: T4, 4 сообщения за прогон