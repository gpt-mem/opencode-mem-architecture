#!/usr/bin/env bash
# mem-metrics-v2.sh — метрики v2-линии форка OpenCode MEM.
#
# Зачем отдельный скрипт: mem-metrics.sql (v1) бьёт по opencode-memory-context-v1.db
# со схемой v1 (`session` / `part`). Эта БД заморожена с 2026-10-12 (последняя сессия
# 2026-10-12 14:34) — 24ч-окно в ней пустое.
#
# v2-линия пишет иначе:
#   * основная БД — ~/.local/share/opencode/opencode.db, таблицы `session_v2` + `session_message`;
#   * v1-схема (`session`/`part`) в той же БД — остаток старых сессий (до 2026-10-15);
#   * активность размазана по 16 канальным БД (opencode-.db, opencode-trim-web-serve.db,
#     opencode-out-of-box-integration.db, ...) — канал задаётся OPENCODE_CHANNEL.
#     Так же их читает CSM: src/lib/opencode-db.ts -> listOpencodeDbPaths().
#
# Скрипт объединяет ВСЕ opencode*.db (v1-схема) + session_v2 основной БД.
# Использование: mem-metrics-v2.sh [окно_секунд=86400]
set -uo pipefail

DIR="${OPENCODE_DATA_DIR:-$HOME/.local/share/opencode}"
WIN="${1:-86400}"
CUT="(strftime('%s','now')-$WIN)*1000"
MAIN="$DIR/opencode.db"

hdr() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

# --- 1. Сессии/токены/кэш за окно: v1-схема по всем каналам + session_v2 основной БД ---
hdr "1. Tokens & cost (window=${WIN}s) — union all channels"
printf '%-46s %8s %12s %12s %14s %8s %10s\n' db sessions tok_in tok_out cache_read cache_w cost
tot_s=0; tot_in=0; tot_out=0; tot_cr=0; tot_cw=0; tot_cost=0
for f in "$DIR"/opencode*.db; do
  [ -e "$f" ] || continue
  b=$(basename "$f")
  row=$(sqlite3 -separator '|' "$f" \
    "SELECT count(*), coalesce(sum(tokens_input),0), coalesce(sum(tokens_output),0),
            coalesce(sum(tokens_cache_read),0), coalesce(sum(tokens_cache_write),0), coalesce(round(sum(cost),4),0)
     FROM session WHERE time_created > $CUT;" 2>/dev/null)
  [ -z "$row" ] && continue
  IFS='|' read -r s i o cr cw c <<<"$row"
  [ "${s:-0}" = "0" ] && continue
  printf '%-46s %8s %12s %12s %14s %8s %10s\n' "$b" "$s" "$i" "$o" "$cr" "$cw" "$c"
  tot_s=$((tot_s+s)); tot_in=$((tot_in+i)); tot_out=$((tot_out+o))
  tot_cr=$((tot_cr+cr)); tot_cw=$((tot_cw+cw)); tot_cost=$(awk -v a="$tot_cost" -v b="$c" 'BEGIN{print a+b}')
done
if [ -f "$MAIN" ]; then
  IFS='|' read -r s i o cr cw c <<<"$(sqlite3 -separator '|' "$MAIN" \
    "SELECT count(*), coalesce(sum(tokens_input),0), coalesce(sum(tokens_output),0),
            coalesce(sum(tokens_cache_read),0), coalesce(sum(tokens_cache_write),0), coalesce(round(sum(cost),4),0)
     FROM session_v2 WHERE time_created > $CUT;" 2>/dev/null)"
  printf '%-46s %8s %12s %12s %14s %8s %10s\n' "session_v2 (main opencode.db)" "$s" "$i" "$o" "$cr" "$cw" "$c"
  tot_s=$((tot_s+s)); tot_in=$((tot_in+i)); tot_out=$((tot_out+o))
  tot_cr=$((tot_cr+cr)); tot_cw=$((tot_cw+cw)); tot_cost=$(awk -v a="$tot_cost" -v b="$c" 'BEGIN{print a+b}')
fi
hit=$(awk -v cr="$tot_cr" -v i="$tot_in" 'BEGIN{ if(cr+i>0) printf "%.1f", 100*cr/(cr+i); else print "n/a" }')
printf '%-46s %8s %12s %12s %14s %8s %10s\n' "TOTAL" "$tot_s" "$tot_in" "$tot_out" "$tot_cr" "$tot_cw" "$tot_cost"
echo "cache_hit_pct (cache_read / (cache_read + tok_in)) = $hit"

# --- 2. Memory tools: v1-схема (part) по всем БД ---
hdr "2. Memory tool calls (24h window) — v1 schema part[]"
: >/tmp/.mm_tools.$$
for f in "$DIR"/opencode*.db; do
  [ -e "$f" ] || continue
  sqlite3 -separator '|' "$f" \
    "SELECT json_extract(p.data,'\$.tool'), count(*) FROM part p JOIN message m ON m.id=p.message_id
     WHERE json_extract(p.data,'\$.type')='tool' AND m.time_created > $CUT
       AND json_extract(p.data,'\$.tool') IN ('get_tool_call_overview','find_tool_calls',
            'get_tool_call_details','find_agent_artifact','operationalMemory','find_pii',
            'search_operational_memory','put_in_operational_memory','get_operational_memory')
     GROUP BY 1;" 2>/dev/null >>"/tmp/.mm_tools.$$"
done
if [ -s "/tmp/.mm_tools.$$" ]; then sort -t'|' -k2 -rn "/tmp/.mm_tools.$$"; else echo "(нет вызовов memory-тулов)"; fi
rm -f "/tmp/.mm_tools.$$"

# --- 3. Memory tools: v2-схема (session_message.content[].name) ---
hdr "3. Memory tool calls — v2 schema session_message[]"
if [ -f "$MAIN" ]; then
  sqlite3 -separator '|' "$MAIN" \
    "SELECT json_extract(j.value,'\$.name'), count(*) FROM session_message m,
       json_each(json_extract(m.data,'\$.content')) j
     WHERE m.type='assistant' AND m.time_created > $CUT
       AND json_extract(j.value,'\$.type')='tool'
       AND (json_extract(j.value,'\$.name') LIKE '%memory%'
         OR json_extract(j.value,'\$.name') LIKE '%tool_call%'
         OR json_extract(j.value,'\$.name') LIKE '%pii%')
     GROUP BY 1 ORDER BY 2 DESC;" 2>/dev/null || true
fi

# --- 4. Intent signals ---
hdr "4. Intent signals"
for f in "$DIR"/opencode*.db; do
  [ -e "$f" ] || continue
  r=$(sqlite3 -separator '|' "$f" "SELECT count(*), coalesce(datetime(max(ts)/1000,'unixepoch','localtime'),'-'),
      coalesce(round(avg(cosine),3),'-'), coalesce(sum(acted),0), coalesce(sum(CASE WHEN llm_label='switch' THEN 1 ELSE 0 END),0)
      FROM intent_signal WHERE ts > $CUT;" 2>/dev/null)
  [ -z "$r" ] && continue
  IFS='|' read -r n last cos acted sw <<<"$r"
  [ "${n:-0}" = "0" ] && continue
  echo "$(basename "$f"): signals=$n last=$last cosine_avg=$cos acted=$acted labeled_switch=$sw"
done
echo "(пусто = детектор интента в v2-линии не пишет сигналы)"

# --- 5. Compaction / truncation: измерители v2 ---
hdr "5. Compaction & tool-output truncation (v2)"
if [ -f "$MAIN" ]; then
  sqlite3 -separator '|' "$MAIN" \
    "SELECT 'compaction msgs', count(*) FROM session_message WHERE type='compaction' AND time_created > $CUT
     UNION ALL SELECT 'compaction msgs 7d', count(*) FROM session_message WHERE type='compaction' AND time_created > (strftime('%s','now')-604800)*1000
     UNION ALL SELECT 'truncation markers', count(*) FROM session_message WHERE data LIKE '%showing lines%' AND time_created > $CUT
     UNION ALL SELECT 'truncation markers 7d', count(*) FROM session_message WHERE data LIKE '%showing lines%' AND time_created > (strftime('%s','now')-604800)*1000
     UNION ALL SELECT 'sessions time_compacting NOT NULL', count(*) FROM session_v2 WHERE time_created > (strftime('%s','now')-604800)*1000 AND time_compacting IS NOT NULL
     UNION ALL SELECT 'sessions total 7d', count(*) FROM session_v2 WHERE time_created > (strftime('%s','now')-604800)*1000;" 2>/dev/null
fi

# --- 6. Живость каналов: последняя сессия по каждому opencode*.db ---
hdr "6. Channel freshness (last session per DB)"
for f in "$DIR"/opencode*.db; do
  [ -e "$f" ] || continue
  last=$(sqlite3 "$f" "SELECT coalesce(datetime(max(time_created)/1000,'unixepoch','localtime'),'-') FROM session;" 2>/dev/null)
  last2=$(sqlite3 "$f" "SELECT coalesce(datetime(max(time_created)/1000,'unixepoch','localtime'),'-') FROM session_v2;" 2>/dev/null)
  echo "$(basename "$f"): v1=$last v2=$last2"
done
