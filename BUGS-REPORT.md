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