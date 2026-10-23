-- mem-metrics-v2.sql — измерения использования функционала и расходов (токены/кеш) для v2.
-- Запуск: sqlite3 ~/.local/share/opencode/opencode.db < mem-metrics-v2.sql

.headers on
.mode column

-- 1. Расходы по сессиям за 24ч
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
FROM session_v2
WHERE time_created > (strftime('%s','now')-86400)*1000
GROUP BY 1 ORDER BY cost_usd DESC;

-- 2. Топ-10 сессий за 24ч
SELECT substr(id,1,20) AS session, substr(title,1,36) AS title,
       tokens_cache_read AS cache_r, tokens_cache_write AS cache_w,
       round(cost,4) AS cost_usd
FROM session_v2
WHERE time_created > (strftime('%s','now')-86400)*1000
ORDER BY tokens_cache_read DESC LIMIT 10;

-- 3. Динамика по дням (7 дней)
SELECT date(time_created/1000,'unixepoch','localtime') AS day,
       count(*) AS sessions,
       sum(tokens_input) AS tok_in,
       sum(tokens_cache_read) AS cache_r,
       sum(tokens_cache_write) AS cache_w,
       round(sum(cost),4) AS cost_usd
FROM session_v2
WHERE time_created > (strftime('%s','now')-604800)*1000
GROUP BY 1 ORDER BY 1;

-- 4. Использование memory-тулов — всего и за 24ч (пока упрощенно, без part join)
-- TODO: Реализовать join для part в v2
SELECT 'memory_tools_v2_not_implemented' AS status;

-- 6. Cache mark: активность по провайдерам
SELECT provider_id, mark_tokens, mark_index,
       datetime(last_used_at/1000,'unixepoch','localtime') AS last_used
FROM provider_cache_mark ORDER BY last_used_at DESC;
