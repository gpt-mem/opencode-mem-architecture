#!/bin/bash
# UPSTREAM-COLLECT: дешёвый детектор новых релизов апстрима (без модели).
# Локальный двойник collect-джобы в .github/workflows/upstream-watch.yml.
#
# Что делает (логика в chain/upstream_collect.py):
#   - находит новые теги линии v2.* в апстриме, которых ещё не обрабатывали;
#   - собирает сырьё (коммиты, PR, файлы) в ~/.opencode/scripts/upstream-watch/collected/<tag>.json.
#
# Сырьё читает opencode-сессия «изучить» (chain/prompt-upstream-study.txt):
# в этом скрипте нет ни суждений, ни issue — только факты, чтобы не тратить токены.
#
# Коды возврата:
#   0 — отработал (в том числе «новых релизов нет»)
#   1 — ошибка (сеть, права, API)

set -u
SCRIPTS="$HOME/.opencode/scripts"
WATCH_DIR="$SCRIPTS/upstream-watch"
LOG_DIR="$WATCH_DIR/logs"
LOCK_DIR="$WATCH_DIR/collect.lock"
IMPL="${UPSTREAM_IMPL:-/Users/vova/opencode-mem-architecture/chain/upstream_collect.py}"
STAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/collect-$STAMP.log"

log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  STALE=1
  if [ -f "$LOCK_DIR/pid" ]; then
    read -r LPID < "$LOCK_DIR/pid"
    [ -n "$LPID" ] && kill -0 "$LPID" 2>/dev/null && STALE=0
  fi
  if [ "$STALE" = "1" ]; then
    log "stale collect lock — recovering"
    rm -rf "$LOCK_DIR"; mkdir "$LOCK_DIR" 2>/dev/null || { log "lock lost — exit"; exit 0; }
  else
    log "collect already running — skip"
    exit 0
  fi
fi
echo $$ > "$LOCK_DIR/pid"
trap 'rm -rf "$LOCK_DIR"' EXIT

if [ -z "${GH_TOKEN:-}" ]; then
  GH_TOKEN=$(security find-generic-password -s github.com -a kobzevvv -w 2>/dev/null)
  export GH_TOKEN
fi
if [ -z "${GH_TOKEN:-}" ]; then
  log "GH-токен не найден — детектор не может читать GitHub"
  exit 1
fi

log "UPSTREAM-COLLECT $STAMP START"
python3 "$IMPL" 2>&1 | tee -a "$LOG"
CODE=${PIPESTATUS[0]}
log "UPSTREAM-COLLECT $STAMP DONE exit=$CODE"
exit "$CODE"
