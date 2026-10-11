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

# ── 6. Страховочный push docs-репо ──────────────────────────────────────
# Сессии сами пушат свои артефакты; здесь добиваем всё, что осталось локально,
# чтобы ценные находки не остались только на диске.
log "DOCS PUSH (safety net)"
( cd "$DOCS" && \
  if [ -n "$(git status --porcelain)" ]; then
    git add -A && \
    git commit -m "chain: auto-push $STAMP" && \
    git push origin main >> "$LOG" 2>&1 \
      && log "docs pushed" || log "docs push FAILED (занято/конфликт — подхватится позже)"
  else
    log "docs clean — nothing to push"
  fi ) || true

# ── 7. Тяжёлые артефакты → Google Drive ─────────────────────────────────
# SA = vovako-21js@trained-assist-gdrive-sa.iam.gserviceaccount.com
# Шареная папка: OpenCode MEM Artifacts (ID: 1yA2KUcjVV9V3mwk1u5rTFI1p5DAsNb9B)
# Требуется: Shared Drive, созданная владельцем (kobzevvv@gmail.com), SA = writer.
#            Ключ: $HOME/.config/gcloud/application_default_credentials.json
#            или $GOOGLE_APPLICATION_CREDENTIALS.
#
# Формат: selftest-<STAMP>.log (до 10MB), chain-state.jsonl (последние 50 строк).
# Не заливаем: chain-last.md, STUDY.md, BUGS-REPORT.md — они в GitHub docs-репо.

GDRIVE_SA_EMAIL="vovako-21js@trained-assist-gdrive-sa.iam.gserviceaccount.com"
GDRIVE_FOLDER_ID="1yA2KUcjVV9V3mwk1u5rTFI1p5DAsNb9B"

upload_to_drive() {
  local file="$1" mime="${2:-text/plain}"
  if [ ! -f "$file" ]; then
    log "Drive upload SKIP: $file not found"
    return 0
  fi
  local size=$(stat -f%z "$file" 2>/dev/null || echo 0)
  if [ "$size" -gt 10485760 ]; then  # >10MB
    log "Drive upload SKIP: $file >10MB ($size bytes) — слишком большой"
    return 0
  fi
  # gcloud storage cp — надёжнее, чем googleapis
  if command -v gcloud >/dev/null 2>&1; then
    gcloud storage cp "$file" "gs://opencode-mem-artifacts/chain/$STAMP/$(basename "$file")" --project aiqarus-web 2>> "$LOG" \
      && log "Drive OK: $file → gs://..." || log "Drive FAIL: $file"
  else
    log "Drive SKIP: gcloud not found"
  fi
}

# Selftest-лог этого цикла
SELFTEST_LOG="$HOME/.opencode/scripts/selftest-logs/selftest-$(ls -t "$HOME/.opencode/scripts/selftest-logs/" 2>/dev/null | head -1)"
[ -f "$SELFTEST_LOG" ] && upload_to_drive "$SELFTEST_LOG" "text/plain"

# Chain state (последние 50 строк)
if [ -f "$STATE" ]; then
  tail -50 "$STATE" > "/tmp/chain-state-last50.jsonl"
  upload_to_drive "/tmp/chain-state-last50.jsonl" "application/json"
  rm -f "/tmp/chain-state-last50.jsonl"
fi

log "MEM-CHAIN $STAMP DONE"