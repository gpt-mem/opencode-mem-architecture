# BUG-REPORTS — фактология из self-test логов

## BUG-REPORT 20261022-223640

Источник: `~/.opencode/scripts/selftest-logs/selftest-20261022-223640.log` (наибольший по mtime, 5 ходов T1–T5, `fork at 021466337676`, `=== SELFTEST 20261022-223640 DONE ===`), контекст: `release-current.md`, `chain-logs/chain-20261022-2003.log`, `chain-state.jsonl`, ITERATIONS (последние 10 записей).

### Проблемы
- T1 exit=1: `get_tool_call_details` вызван с неверным именем аргумента — модель передала `{"call":"call-8f5d49a3-4543-4455-8e87-8a62d707c5bf"}` вместо `{"call_id":"..."}`; ошибка: `Invalid arguments for tool "get_tool_call_details": - call_id: Missing key`; на ретрае с правильным аргументом прошло — **high**
- Компакция отсутствует: `compaction: log_lines=0`, `max_compacted=0`, `final_mark=0` — в T1 3000-строчный bash-вывод отдался целиком, маркер `[showing lines 2976-3000 of 3000; full output saved to …]` не сработал как компакт-маркер (нет `mem:` префикса) — **high**
- Оценка 4/5 (T5) при нуле компакции — «сжимаем но ничего не прячем» 4/5 при `max_compacted=0`; маркер усечения есть, но компакт-маркеров с `call_id`/`retrieve` нет — **medium**
- Сценарий T1–T3 использует только `read`/`grep` для needle — bash-тул не вызывался → фильтр `exit_code`/`failed` из PR #69 без live-покрытия 4-й цикл подряд — **medium**
- Needle-check структурно зелёный по построению: игла `CM-5581-A` вставлена в промпт T4 (`:125`), ищется `grep`-ом по всей БД (`:139`); в T3 модель нашла её через `grep` файла на диске, не через ретрив — **medium**
- `read`-тул обещает 2000 строк и отдаёт ~624 (MAX_READ_BYTES = 50 KiB) — модель в T3 пошла по offset'ам 1/1001/2001, получила дырявые куски — **medium** (ITERATIONS 261)
- Харнесс: `DONE` печатается ДО трёх последних check'ов (`run-selftest.sh:194` vs `:213/:221/:227`); `acceptance:` строка в логе после `DONE` — **low**
- critical: **0** — `grep -E "FAIL|Error|panic|assert"` → 0 совпадений (ошибка T1 — валидация аргументов тула, не падение)

Регрессий vs предыдущих циклов (ITERATIONS): компакция 0/0/0 — 3-й полный прогон подряд (123843: оборван на T1; 103636: 0/0/0; 083306: 8/2/12); оценка 4/5 на нуле компакции — 2-й прогон подряд (103636); needle-check самораздувается (ITERATIONS 261: 599/855 сессий); модель выдумывает строки (`big-output-line CORPORATE`) — 16-й зелёный прогон подряд (ITERATIONS 263); `read` даёт ~624 вместо 2000 строк — воспроизводится; `bash` вместо `shell` — 75/24ч (ITERATIONS 261); PR #206 (порт memory-context в v2) в 候选ном SHA `021466337676` — shell-фичTURE 3000 строк не окупился при 2 KiB пороге (ITERATIONS 268).

### Паттерны
- T1 ошибка — не новый дефект: модель путает `call`/`call_id` при первом вызове `get_tool_call_details` (наблюдалось в dogfooding сессиях 30/41/48); ретрай с правильным именем проходит
- Маркер усечения shell-вывода (`[showing lines X-Y of Z; full output saved to …]`) не превращается в компакт-маркер с `call_id`/`retrieve` — `MemoryContext.project` (PR #206) не сработал на 3000-строчном выводе при пороге 2048 (флаг `OPENCODE_MEMORY_CONTEXT` off по умолчанию, `release-current.md:17-19`)
- Хвостовые метрики корректны: `check: truncation marker present — ok`, `check: full output file present and complete — ok`, `check: needle retrieved — ok (CM-5581-A)`, `acceptance:` с верным `candidate_sha=021466337676`
- `cache_r>0` на каждом ходу (логах нет, но `acceptance` не жалуется); PII-утечек в маркеры нет (`0 markers with pii=`)
- Цепочка 2003: build→selftest→release→bug-reporter — все `exit=0` (ITERATIONS 271)

### Идеи (as is)
- Сделать маркер усечения shell-вывода компакт-маркером с `call_id` + `retrieve` — контекст: T1 3000 строк ушло целиком, ретрив через `grep` файла, а не через тул
- Поднять порог компакции shell выше 4000 (чанк `get_tool_call_details`) — контекст: PR #206, ITERATIONS 268 «порог должен быть выше 4000-char-чанка»
- Не выставлять оценку «сжимаем», пока `max_compacted=0` — контекст: 4/5 на прогоне без единого компакт-маркера (2-й цикл)
- Добавить bash-ход в сценарий selftest для live-покрытия `exit_code`/`failed` (PR #69) — контекст: 4 цикла без баша
- Скоупить needle-check по `session_id` прогона — контекст: игла в 599/855 сессий, зелёный по построению
- Исправить `read`-тул: 2000 строк обещано, ~624 доставлено (MAX_READ_BYTES = 50 KiB) — контекст: ITERATIONS 261, модель получает дырявое покрытие
- Печатать `acceptance:` ДО `DONE` — контекст: порядок строк в логе вводит в заблуждение

(Только констатация фактов из лога 22:36, цепочки 2003 и смежных артефактов; решения не предлагались.)