#!/bin/bash
# MEM-CHAIN: кандидат → проверка → промоушен → баг-репортер → учёный → архитектор.
# Запускается launchd local.opencode.mem-chain каждые 2 часа (StartInterval 7200).
#
# Системно с описанием релиза апдейта:
#   - run-build.sh собирает кандидата (v2-base, packages/cli) в стейджинг
#   - run-selftest.sh проверяет кандидата и пишет отчёт selftest-last.json
#   - run-releaser.sh публикует релиз и ставит сборку (mem-builds.sh install)
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
# Модель: ladder/build есть и в стоке, и в сборке форка (opencode-go в v2-раскладке
# форка не зарегистрирован). Переопределяется переменной MEM_MODEL.
MODEL="${MEM_MODEL:-ladder/build}"
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

state() { printf '{"ts":"%s","run":"%s","step":"%s","exit":%d,"dur_s":%d,"status":"%s"}\n' \
  "$(date -Iseconds)" "$STAMP" "$1" "$2" "$3" "$4" >> "$STATE"; }

# exit 78 = сам селфтест объявил «skipped» — это НЕ успех (issue #67).
status_of() {
  case "$1" in
    0) echo "ok" ;;
    78) echo "skipped" ;;
    *) echo "failed" ;;
  esac
}

step_script() {
  local name="$1" cmd="$2"
  local t0=$(date +%s)
  log "STEP $name START: $cmd"
  bash -c "$cmd" >> "$LOG" 2>&1
  local code=$? dur=$(( $(date +%s) - t0 ))
  log "STEP $name END exit=$code dur=${dur}s status=$(status_of "$code")"
  state "$name" "$code" "$dur" "$(status_of "$code")"
  LAST_STEP_EXIT=$code
}

step_session() {
  local name="$1" prompt_file="$2"
  local t0=$(date +%s)
  log "STEP $name START (session $name)"
  ( cd "$DOCS" && "$OC" run --model "$MODEL" --auto --title "chain-$name" \
      "$(cat "$prompt_file")" ) >> "$LOG" 2>&1
  local code=$? dur=$(( $(date +%s) - t0 ))
  log "STEP $name END exit=$code dur=${dur}s status=$(status_of "$code")"
  state "$name" "$code" "$dur" "$(status_of "$code")"
}

echo "$STAMP" > "$SCRIPTS/chain-current.txt"
log "MEM-CHAIN $STAMP START"

# Порядок шагов: КАНДИДАТ → ПРОВЕРКА → ПРОМОУШЕН.
# Кандидат собирается и уходит в стейджинг, активный бинарь на этом шаге не
# трогается. Проверка идёт по кандидату. Промоушен (релиз + установка сборки)
# выполняется только после зелёной проверки того же SHA — иначе бинарь уезжает
# на непроверенной сборке (циклы 20261012-0452/0725).
# 1. КАНДИДАТ — сборка v2-кандидата в стейджинг
step_script build "bash $SCRIPTS/run-build.sh"
BUILD_EXIT=$LAST_STEP_EXIT

# 2. ПРОВЕРКА — полный selftest на кандидате
if [ "$BUILD_EXIT" = "0" ]; then
  step_script selftest "bash $SCRIPTS/run-selftest.sh"
  SELFTEST_EXIT=$LAST_STEP_EXIT
else
  log "SELFTEST withheld: build exit=$BUILD_EXIT (status=$(status_of "$BUILD_EXIT")) — кандидата нет"
  state selftest 77 0 "withheld"
  SELFTEST_EXIT=77
fi

# 3. ПРОМОУШЕН — GitHub Release, установка сборки (mem-builds.sh), активный бинарь
if [ "$SELFTEST_EXIT" = "0" ]; then
  step_script release "MEM_REQUIRE_SELFTEST=1 MEM_SELFTEST_OK=1 bash $SCRIPTS/run-releaser.sh"
else
  log "RELEASE withheld: selftest exit=$SELFTEST_EXIT (status=$(status_of "$SELFTEST_EXIT")) — верификация прогона не пройдена"
  state release 77 0 "withheld"
fi

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

GDRIVE_FOLDER_ID="1LOUSoTtWr-Z4YScefw2RETJar4oxln8X"

# PII-инвариант: в облако уходит редактированная копия — сырые email/phone из
# selftest-сценария не должны размножаться в артефактах (issue #67).
redact_copy() {
  local src="$1" dst="$2"
  sed -E \
    -e 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/[REDACTED:email]/g' \
    -e 's/\+[0-9][0-9() -]{6,}[0-9]/[REDACTED:phone]/g' \
    "$src" > "$dst"
}

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
  local upload="$file"
  if [[ "$mime" == text/* ]]; then
    upload="/tmp/redacted-$(basename "$file")"
    redact_copy "$file" "$upload"
  fi
  # Google Drive API по токену gcloud (папка "logs sessions", owner kobzevvv@gmail.com)
  local token name
  token=$(gcloud auth print-access-token 2>/dev/null) || { log "Drive SKIP: no gcloud token"; [ "$upload" = "$file" ] || rm -f "$upload"; return 0; }
  name="$(date +%Y%m%d-%H%M)-$(basename "$file")"
  curl -s -X POST \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: multipart/related; boundary=memchainboundary" \
    --data-binary @- \
    "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&supportsAllDrives=true" \
    >> "$LOG" 2>&1 <<EOF && log "Drive OK: $name" || log "Drive FAIL: $name"
--memchainboundary
Content-Type: application/json; charset=UTF-8

{"name":"$name","parents":["$GDRIVE_FOLDER_ID"]}
--memchainboundary
Content-Type: text/plain; charset=UTF-8

$(cat "$upload")
--memchainboundary--
EOF
  [ "$upload" = "$file" ] || rm -f "$upload"
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