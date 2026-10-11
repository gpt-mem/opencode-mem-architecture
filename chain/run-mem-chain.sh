#!/bin/bash
# MEM-CHAIN: релиз → селфтест → баг-репортер → учёный → архитектор.
# Запускается launchd local.opencode.mem-chain каждые 2 часа (StartInterval 7200).
#
# Системно с описанием релиза апдейта:
#   - релиз (run-releaser.sh) кладёт ноты в release-current.md
#   - селфтест логируется, отчёт — в selftest-logs/
#   - баг-репортер читает release-current.md + selftest-logs
#   - учёный читает BUGS-REPORT/STUDY + SQL-метрики
#   - архитектор консервативно правит ROADMAP.md + prompt.txt builder'а,
#     пишет chain-last.md (сводка цикла) → следующий релиз читает её
#
# Артефакты:
#   ~/.opencode/scripts/chain-logs/chain-<STAMP>.log   — общий лог
#   ~/.opencode/scripts/release-current.md             — релиз-ноты (вход баг-репортера)
#   ~/.opencode/scripts/chain-last.md                  — сводка прошлого цикла (архитектор)
#   ~/.opencode/scripts/chain-state.jsonl              — журнал статусов шагов

set -u
SCRIPTS="$HOME/.opencode/scripts"
DOCS="/Users/vova/opencode-mem-architecture"
OC="$HOME/.opencode/bin/opencode"
MODEL="opencode-go/mimo-v2.6-flash"
STAMP=$(date +%Y%m%d-%H%M)
LOCK_DIR="$SCRIPTS/chain.lock"
LOG_DIR="$SCRIPTS/chain-logs"
STATE="$SCRIPTS/chain-state.jsonl"
RELEASE_NOTES="$SCRIPTS/release-current.md"
CHAIN_LAST="$SCRIPTS/chain-last.md"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/chain-$STAMP.log"
mkdir -p "$SCRIPTS/selftest-logs"

log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

# ── lock (защита от наложения циклов) ───────────────────────────────────
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  STALE=1
  if [ -f "$LOCK_DIR/pid" ]; then
    read -r LPID < "$LOCK_DIR/pid"
    [ -n "$LPID" ] && kill -0 "$LPID" 2>/dev/null && STALE=0
  fi
  if [ "$STALE" = 1 ]; then
    log "stale chain lock — recovering"
    rm -rf "$LOCK_DIR"; mkdir "$LOCK_DIR" 2>/dev/null || { log "lock lost — exit"; exit 0; }
  else
    log "chain already running — skip"
    exit 0
  fi
fi
echo $$ > "$LOCK_DIR/pid"
trap 'rm -rf "$LOCK_DIR"' EXIT

state() { printf '{"ts":"%s","run":"%s","step":"%s","exit":%d,"dur_s":%d}\n' \
  "$(date -Iseconds)" "$STAMP" "$1" "$2" "$3" >> "$STATE"; }

step_script() {
  local name="$1" cmd="$2"
  local t0=$(date +%s)
  log "STEP $name START: $cmd"
  bash -c "$cmd" >> "$LOG" 2>&1
  local code=$? dur=$(( $(date +%s) - t0 ))
  log "STEP $name END exit=$code dur=${dur}s"
  state "$name" "$code" "$dur"
}

step_session() {
  local name="$1" prompt_file="$2"
  local t0=$(date +%s)
  log "STEP $name START (session $name)"
  ( cd "$DOCS" && "$OC" run --model "$MODEL" --auto --title "chain-$name" \
      "$(cat "$prompt_file")" ) >> "$LOG" 2>&1
  local code=$? dur=$(( $(date +%s) - t0 ))
  log "STEP $name END exit=$code dur=${dur}s"
  state "$name" "$code" "$dur"
}

echo "$STAMP" > "$SCRIPTS/chain-current.txt"
log "MEM-CHAIN $STAMP START"

# 1. РЕЛИЗ — сборка форка, GitHub Release, установка бинаря; ноты в release-current.md
step_script release "bash $SCRIPTS/run-releaser.sh"

# 2. СЕЛФТЕСТ — dogfooding на активном бинаре (fork)
step_script selftest "bash $SCRIPTS/run-selftest.sh"

# 3. БАГ-РЕПОРТЕР — систематизация проблем/идей по итогам селфтеста
step_session bug-reporter "$SCRIPTS/prompt-bug-reporter.txt"

# 4. УЧЁНЫЙ — метрики, исследования, user feedback, судья по бенчмаркам
step_session researcher "$SCRIPTS/prompt-researcher.txt"

# 5. АРХИТЕКТОР — консервативно правит приоритеты + prompt builder'а
step_session architect "$SCRIPTS/prompt-architect.txt"

log "MEM-CHAIN $STAMP DONE"