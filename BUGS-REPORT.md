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