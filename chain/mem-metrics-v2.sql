-- mem-metrics-v2.sql — измерения использования функционала и расходов (токены/кеш).
-- Запуск: sqlite3 ~/.local/share/opencode/opencode.db < mem-metrics-v2.sql

.headers on
.mode column

-- 1. Расходы по сессиям за 24ч
SELECT 'chain' AS kind,
       count(*) AS sessions,
       sum(tokens_input) AS tok_in,
       sum(tokens_output) AS tok_out,
       sum(tokens_cache_read) AS cache_r,
       round(100.0*sum(tokens_cache_read)/nullif(sum(tokens_input)+sum(tokens_cache_read),0),1) AS cache_hit_pct
FROM session_v2
WHERE time_created > (strftime('%s','now')-86400)*1000;

-- 2. Топ-10 сессий за 24ч по кеш-чтению
SELECT substr(id,1,20) AS session,
       tokens_cache_read AS cache_r, tokens_cache_write AS cache_w
FROM session_v2
WHERE time_created > (strftime('%s','now')-86400)*1000
ORDER BY tokens_cache_read DESC LIMIT 10;

-- 3. Динамика по дням (7 дней)
SELECT date(time_created/1000,'unixepoch','localtime') AS day,
       count(*) AS sessions,
       sum(tokens_input) AS tok_in,
       sum(tokens_cache_read) AS cache_r
FROM session_v2
WHERE time_created > (strftime('%s','now')-604800)*1000
GROUP BY 1 ORDER BY 1;
