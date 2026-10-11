# STUDY — ранжированный список находок (стартовая точка учёного)

> Обновляется сессией researcher (chain, каждые 2ч). Формат пункта:
> `[rank] <польза> STATUS — <обоснование>`. STATUS: `proven` | `doubtful` | `needs_proof`.

Цикл 2: researcher, SQL-метрики 24ч + BUGS-REPORT `20261012-000748` + CSM feedback.
`STAMP: research-20261012-0021`

## Ranked by usefulness

1. **First-delivery + cache-mark ledger-политика (ISSUE-23, PR #27+#32+#33+#36, прод-конфиг `CONTEXT=1 CACHE_MARK=1`)** — `high` — STATUS: `proven` — A/B GO: needle-cost −48.5%, summary-cost −92.3%, needle-recall 100%, 0 инвалидаций кеша; live-e2e fdmark −93.8% vs off (mimo) и −55% provider-visible (ladder/free); политика «FD при включённом ledger» слита и покрыта parity-тестами.
2. **Cache-stable boundary (batch, MIDTURN off by default — PR #21+#22)** — `high` — STATUS: `proven` — из замеров выведена прайсинг-модель `cost = 1.412e-7×uncached + 3.06e-9×cache_read` (cache_read ≈ 2.2% uncached); A/B: паритет одноповоротный, −1.2% cost / −19.1% provider-visible трёхповоротный; sliding-поведение задокументировано как +67–70% стоимости (ловушка).
3. **`get_tool_call_details` (полный ретрив, offset/full, evidence `source` — PR #1/#24/#52)** — `high` — STATUS: `proven` — 130 вызовов за 24ч = **единственный реально используемый memory-тул** (3.21% всех tool-вызовов); маркер → ретрив → ответ подтверждён selftest-сериями и A/B (модель сама уходила `offset=36000` к игле).
4. **Индексация реплик ассистента/решений и вложенных tool-results** — `high` — STATUS: `needs_proof` — не реализовано: решения не появлялись в индексе ни разу за 8 проходов selftest, `Read` doc1–doc3 индекс не попали; `put_in_operational_memory` недоступен подряд 8 раз (I3a/#13) — единственный носитель решения = текст текущего контекста.
5. **PII в индексе + `find_pii` (issue #13)** — `high` — STATUS: `needs_proof` — BUG-REPORT `20261012-000748`: e-mail в 3 bash-носителях от утечной маски живёт в индексе; `find_pii` отсутствует; «0 markers with pii=» ≠ индекс чист (проверка покрывает только маркеры).
6. **`find_tool_calls` (discover-петля — PR #6+#44)** — `medium` — STATUS: `doubtful` — механика работает, anti-echo (#34/#44) закрыт red/green'ом, но ретрив решений = 0 находок 4 прогона подряд (`matched: 0` по «форкать»/«принято решение»); практическая отдача пока только по явным query.
7. **Context projection v1 (`OPENCODE_MEMORY_CONTEXT` — PR #7/#19)** — `medium` — STATUS: `doubtful` — прод-путь V1 подключён и e2e-проверен (cache_r −54%, needle ALPHA-DELTA-42), но флаг default off, dollar-экономия через plain projection отрицательна на cache-прайсинге (была причина ISSUE-20), production-замеров нет; в БД за 24ч `time_compacting` не заполнен ни у одной сессии (метрика ненадёжна).
8. **Intent-switch detector (precision-first — PR #26+#28+#30+#40)** — `medium` — STATUS: `doubtful` — детектор на фикстурах точен (3/3 TP, 0 FP на 38 ходах против 13 FP у v1), за 24ч 42 production-сигнала (cosine_avg 0.168, acted=1); но экономика intent-руки NO-GO (S1 +18.4%, спред одинаковых конфигов до +136%), n=1, stage-5 (#43: n≥3, прогрев ledger) не начат.
9. **`get_tool_call_overview` (PR #17+#48)** — `medium` — STATUS: `doubtful` — вызывается только selftest'ом, из 24ч метрик — 0 вызовов; PR #48 вернул полный `total`, но свежий BUG-REPORT: `groups_total: 2` ≠ сумма `groups` (16) при `total: 70` — агрегат не годится для аудита «ничего не спрятано».
10. **Ledger resilience (reset на отказ/таймаут — PR #41+#47+#50)** — `medium` — STATUS: `doubtful` — покрыто юнит/интеграционными тестами (V1+V2, fail-safe hash-mismatch, idle 30 мин), ledger живёт в dogfood-канале (`opencode-local.db`: 2 строки, mimo `mark=258048/idx=12` @00:12), но денежный A/B с инъекцией отказов не запускался.
11. **PII redaction model-visible + тегирование маркеров (PR #18)** — `medium` — STATUS: `proven` — 5+ selftest-прогонов подряд: `0 markers with pii=`, credential `rbk_9f3a_deep_42` не утёк ни разу, `query=<точной секрет>` матчится при редактированном preview, haystack остаётся сырым для поиска.
12. **Compaction на single user-prompt (BUG-3, PR #19)** — `medium` — STATUS: `proven` — «ноль компакции на одноповоротном сценарии» закрыт (второе окно защиты), все A/B сценарии после фикса показывают ненулевую компакцию.
13. **Evidence-ref виды / never-compact безвозвратного (PR #52)** — `medium` — STATUS: `proven` — `source: full_original|managed_output_file|bounded_stored_output|unavailable` виден в details у selftest; маркеры перестали утверждать «полный текст в SQLite» для pointer-выводов; открытые дыры соседних полей — см. BUG-REPORT (статус `completed` при упавшей команде).
14. **Эвристика `filename` в detectKind** — `low` — STATUS: `doubtful` — в A/B деградирует, кандидат на замену content-based/LLM-judge.
15. **LLM-judge для evaluate** — `low` — STATUS: `needs_proof` — не реализован; эту роль сейчас исполняет сессия researcher (STATUS-комментарии ниже).
16. **Memory-first context replacement (I5)** — `low` — STATUS: `needs_proof` — отдельный эксперимент; замена полного диалога на memory-тулы не начиналась.

## Metrics digest (24h)
Источник: `sqlite3 ~/.local/share/opencode/opencode-memory-context-v1.db < mem-metrics.sql`, окно 24ч на 2026-10-12 00:21.

- Sessions: 44 (scheduled 15 / ad-hoc 27 / chain 2; bug-reporter/researcher/architect — 0, chain-2 = только что стартовавший researcher) — Total tokens: in 7.71M, out 0.49M, cache read 172.03M (95.7% input-side), cache write 0 — Cost: $0.69 (scheduled $0.64 / ad-hoc $0.03 / chain $0.02); cache hit: 98.1% / 93.4% / 85.9%.
- Дневная динамика: 2026-10-11 — 42 сессии, $0.67; 2026-10-12 — 2, $0.02. Топ cache-read — scheduled-iteration (13.4M / 11.0M / 10.0M cache_r), но их cost мал за счёт hit ≈ 98%.
- Memory tools: `get_tool_call_details` = 130 (calls_24h = calls_total — первый день с ненулевой статистикой), `find_tool_calls` = 0, `get_tool_call_overview` = 0, `operationalMemory`/`find_pii` = отсутствуют как тулы. Доля memory-тулов среди всех tool-вызовов: 3.21% (доминирует bash — 3083).
- Cache-mark ledger: в memory-context-v1.db — 0 строк (этот канал ledger не пишет); в dogfood-канале `opencode-local.db` — 2 строки: `opencode-go/mimo-v2.6-flash` mark=258048 mark_index=12 (2026-10-12 00:12), `ladder/free` mark=17920 mark_index=1 (2026-10-11 07:49). Общий hit по local-каналу за 24ч: 93.2%, $0.46, 45 сессий.
- Intent signals: 42 за 24ч, cosine_avg=0.168, labeled_switch=0, acted=1 (llm_conf не заполняется).
- Context projection: `time_compacting` NULL у всех 44 сессий за 7 дней — колонка-сигнал не работает/не заполняется, экономия по compacted vs full не измеряется этим запросом.

## User feedback top
Источник: CSM `sessions.db` (218 сессий; human-промпты ~38, остальное — цепочки/бенчмарк-харнесс/агентские system-промпты), `issues.jsonl` (1 запись), `reports/` (6 аналитических отчётов). Ранжирование по частоте human-сессий.

1. **Feature requests / «настрой-добавь»** — count=8 — severity=low/medium — в основном инфраструктурные: keychain-креды, opencode-forever + llm-ladder, MCP-авторизация; прямых MEM-реквестов нет — спрос на memory формулируется как боль потери контекста (п.3), не как фича-реквест.
2. **Конфиги/секреты не настроены** — count=5 — severity=medium — `deepgram_api_key not configured` ×4 (один и тот же промпт в 4 сессиях), github key в key store; все — CSM/infra, к ядру MEM отношения не имеют.
3. **Потеря контекста между сессиями (memory-handoff)** — count=4 — severity=**high** — «его вчера сессия вела и я подзапутался че кого она делала», «дай саммари, я в новой сессии запущу», «продолжим эту разработку — какие итоги последних запусков»; это единственный паттерн, который напрямую валидирует миссию MEM (durable memory + handoff), и он живой в течение всего окна.
4. **Сессии умирают / не видны в UI** — count=3 — severity=medium — «сессия сдохла», «почему в сессион менеджер не видно его?», «далеко не все сессии видны… многие не могу найти»; косвенный, но частый триггер: сессия прервалась → контекст потерян → нужен восстановимый memory-слой.
5. **Не стартует / слетели конфиги** — count=2 — severity=medium — «чето не могу запустить», «слетели конфиги» после пересборки; повторяющийся operational-шум при частых релизах форка.
6. **issues.jsonl: «connection test»** — count=1 — severity=low — idea от 2026-03-14, устаревшая, де-факто очередь ведётся в GitHub issues.

Оговорка: выборка маленькая (38 human-сессий за 3 дня), преобладают бенчмарк- и агентские сессии; статистика выживает только для крупных паттернов, ранжирование выше — консервативное.

## Judge comments

- **#1 FD + ledger-политика (proven):** самое сильное доказательство в проекте — три независимых подтверждения: контролируемый A/B (−48.5%/−92.3%), acceptance-прогон PR #33 (−93.8% vs off, needle 100%), воспроизведение на втором провайдере (ladder/free). Сомнительного: latency +2 provider-хода на ретрив и designed trade «осознанные ретривы съедают ~56k токенов» — на тяжёлых ретрив-сессиях выгода меньше, чем −92%. Проверить: cost на реальных долгих dogfood-сессиях (не харнессах).
- **#2 Cache-stable boundary (proven):** граница доказана прайсинг-моделью и A/B; главный риск не технический, а эксплуатационный — неправильный конфиг (bare CACHE_MARK в boundary-режиме без FD-политики на кеширующем провайдере) деградирует до no-compaction; политика #36 это закрыла, но «знать, кеширует ли провайдер» остаётся открытым (конфиг capabilities).
- **#3 details (proven):** статус подтверждён цифрами — 130/130 memory-вызовов за 24ч приходятся на details; всё остальное (find/overview) в живом использовании ноль. Это и главный риск: discover-петля (find) не используется моделью вне selftest, т.е. value проявляется только когда маркер уже указывает call_id. Что сомнительно: BUG-REPORT фиксирует неточности полей рядом с details (`status: completed` при упавшей команде, `truncated:false` про индекс, не про данные) — PR #52 добавил `source`, но семантическая честность полей не закрыта.
- **#4 Ассистент-реплики/решения (needs_proof):** поднято до rank 4 осознанно: это high-severity пробел, подтверждённый четырьмя проходами подряд (0 находок) + недоступность `put_in_operational_memory`. Без индексации текста решений «nothing hidden» не распространяется на слой решений — модель помнит только текущий контекст. Проработка: I1a-продолжение + I3a (DecisionWrite), с приоритетом над новыми фичами.
- **#5 PII в индексе (needs_proof):** BUG-REPORT оценивает как high, и это справедливо: redaction работает только на том, что уходит модели (#11 proven), но индекс размножает утечные носители; «свойство оператора, не системы» — плохая форма для security-инварианта. Требуется: `find_pii` (read-only аудит), журнал очистки, redaction при индексации (I1a-приёмка «no secret leaks» формально не выполнена).
- **#6 find (doubtful):** не «сломан», а «пока бесполезен по решению»: PII из query размножалась (закрыто #44), а семантический поиск по решениям не работает, потому что решения не индексируются (#4). После #4 пересудить.
- **#7 projection (doubtful, понижен с proven-подобного):** механика доказана (e2e, 58/58 тестов), но plain mid-turn компакция на cache-прайсинге убыточна — единственный доказанный источник экономии теперь FD+ledger (#1); standalone значение CONTEXT — каркас для остальных режимов. Нужен production-путь с флагом по умолчанию или отказ от него в пользу FD-only конфига.
- **#8 intent (doubtful):** механика GO, defaults NO-GO — вердикт stage-4 держим; 42 сигнала/24ч показывают, что трекер работает на реальном потоке, но acted=1 за сутки и labeled_switch=0 означают, что калибровка по production ещё невозможна. Не завышать: ждём #43 (n≥3) и разметки сигналов.
- **#9 overview (doubtful):** PR #48 частично закрыл инвентаризацию, но `groups_total` вводит в заблуждение (сумма групп ≠ total) — пока агрегат не сходится, «ничего не прячем» на уровне overview недоказуемо. Плюс ноль вызовов за 24ч — инструмент без пользователей.
- **#10 ledger resilience (doubtful):** честная пометка «доказательство = тесты»; деньги не считали. Отдельное наблюдение: ledger пишет только в dogfood-канал (local), основная БД research-сессий ledger пуста — надо убедиться, что прод-канал сборок тоже пишет иначе метрики #6/#7 недоступны.
- **#11 PII redaction (proven):** стабильно через прогоны; остаточный риск — только маска оператора (см. #5), к redaction как механизму претензий нет.
- **#12 single-turn (proven):** закрыт, регрессия покрыта тестами, все последующие A/B шли с этим фиксом.
- **#13 evidence (proven):** корректность полей подтверждена (selftest видит `source`); остаток — соседние семантические дыры полей (статусы, truncated) — в BUG-REPORT, не блокируют.
- **#14 filename-эвристика (doubtful):** менять, не чинить — кандидат на замену при первой переработке detectKind.
- **#15/#16 (needs_proof):** без изменений; LLM-judge дешевле заменить автоматической калибровкой по размеченным сигналам (#43), чем строить отдельную судью-модель.

### Сводка изменения ранжирования (cycle 1 → cycle 2)
- Подняты: FD+ledger (2→1, proven с тремя независимыми доказательствами); details отделён от overview/find и подтверждён метриками использования; пробелы «решения не индексируются» и «PII в индексе» добавлены на high-позиции как needs_proof.
- Понижены: context projection (2→7) — dollar-экономия через plain projection отрицательна на cache-прайсинге; overview (вниз, агрегат не сходится); intent остался doubtful (детектор починен, экономика нет).
- Подтверждены proven: cache-stable boundary, PII redaction, single-turn compaction, evidence-refs.
- Главный метрический факт цикла: memory-тулы используются, но только `get_tool_call_details` (130 вызовов); discover-слой (find/overview) в реальном потоке не задействован.
