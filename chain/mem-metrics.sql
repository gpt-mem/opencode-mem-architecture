-- mem-metrics.sql — измерения использования функционала и расходов (токены/кеш).
-- Запуск: sqlite3 ~/.local/share/opencode/opencode-memory-context-v1.db < mem-metrics.sql
-- Для сессии учёного (prompt-researcher.txt). Без дашбордов — обычный SQL.

.headers on
.mode column

-- 1. Расходы по сессиям за 24ч (по типам: chain-*, scheduled-*, ad-hoc)
SELECT CASE
         WHEN title LIKE 'chain-%'        THEN 'chain'
         WHEN title LIKE 'scheduled-%'    THEN 'scheduled'
         WHEN title LIKE 'bug-reporter%'  THEN 'bug-reporter'
         WHEN title LIKE 'researcher%'    THEN 'researcher'
         WHEN title LIKE 'architect%'     THEN 'architect'
         ELSE 'ad-hoc'
       END AS kind,
       count(*)                       AS sessions,
       sum(tokens_input)              AS tok_in,
       sum(tokens_output)             AS tok_out,
       sum(tokens_cache_read)         AS cache_r,
       round(100.0*sum(tokens_cache_read)/nullif(sum(tokens_input)+sum(tokens_cache_read),0),1) AS cache_hit_pct,
       round(sum(cost),4)             AS cost_usd
FROM session
WHERE time_created > (strftime('%s','now')-86400)*1000
GROUP BY 1 ORDER BY cost_usd DESC;

-- 2. Топ-10 сессий за 24ч по кеш-чтению и стоимости
SELECT substr(id,1,20) AS session, substr(title,1,36) AS title,
       tokens_cache_read AS cache_r, tokens_cache_write AS cache_w,
       round(cost,4) AS cost_usd
FROM session
WHERE time_created > (strftime('%s','now')-86400)*1000
ORDER BY tokens_cache_read DESC LIMIT 10;

-- 3. Динамика по дням (7 дней) — куда уходят токены
SELECT date(time_created/1000,'unixepoch','localtime') AS day,
       count(*) AS sessions,
       sum(tokens_input) AS tok_in,
       sum(tokens_cache_read) AS cache_r,
       sum(tokens_cache_write) AS cache_w,
       round(sum(cost),4) AS cost_usd
FROM session
WHERE time_created > (strftime('%s','now')-604800)*1000
GROUP BY 1 ORDER BY 1;

-- 4. Использование memory-тулов (функционал I1) — всего и за 24ч
SELECT json_extract(p.data,'$.tool') AS tool,
       count(*) FILTER (WHERE m.time_created > (strftime('%s','now')-86400)*1000) AS calls_24h,
       count(*) AS calls_total
FROM part p JOIN message m ON m.id = p.message_id
WHERE json_extract(p.data,'$.type') = 'tool'
  AND json_extract(p.data,'$.tool') IN
      ('get_tool_call_overview','find_tool_calls','get_tool_call_details','find_agent_artifact','operationalMemory')
GROUP BY 1 ORDER BY calls_total DESC;

-- 5. Доля memory-тулов среди всех tool-вызовов за 24ч (доля функционала)
SELECT round(100.0 * count(*) FILTER (WHERE json_extract(p.data,'$.tool') IN
      ('get_tool_call_overview','find_tool_calls','get_tool_call_details','find_agent_artifact','operationalMemory'))
      / nullif(count(*),0), 2) AS memory_tool_share_pct
FROM part p JOIN message m ON m.id = p.message_id
WHERE json_extract(p.data,'$.type') = 'tool'
  AND m.time_created > (strftime('%s','now')-86400)*1000;

-- 6. Cache mark (флаг CACHE_MARK=1): активность по провайдерам
SELECT provider_id, mark_tokens, mark_index,
       datetime(last_used_at/1000,'unixepoch','localtime') AS last_used
FROM provider_cache_mark ORDER BY last_used_at DESC;

-- 7. Intent-сигналы (детектор смены интента, трек B1) — качество за 24ч
SELECT count(*) AS signals,
       round(avg(cosine),3)         AS cosine_avg,
       round(avg(llm_conf),3)       AS llm_conf_avg,
       sum(CASE WHEN llm_label='switch' THEN 1 ELSE 0 END) AS labeled_switch,
       sum(acted)                   AS acted_cnt
FROM intent_signal
WHERE ts > (strftime('%s','now')-86400)*1000;

-- 8. Context projection (флаг CONTEXT=1): сессии с проекцией vs без — экономия
--    (time_compacting заполняется при компакции; проекция сокращает входные токены)
SELECT CASE WHEN time_compacting IS NOT NULL THEN 'compacted' ELSE 'full' END AS ctx,
       count(*) AS sessions,
       round(avg(tokens_input)) AS avg_tok_in,
       round(avg(tokens_cache_read)) AS avg_cache_r,
       round(avg(cost),4) AS avg_cost
FROM session
WHERE time_created > (strftime('%s','now')-604800)*1000
GROUP BY 1;