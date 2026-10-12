#!/bin/bash
# SELFTEST: dogfooding-сессия на форке (OPENCODE_MEMORY_CONTEXT=1).
# Многоходовая сессия: инструменты → решение → PII → плотные документы → ретрив → отчёт.
# Сценарий: ~/opencode-mem-architecture/SELFTEST.md
#
# Приёмочные правила (см. issue #67):
#  - selftest идёт в изолированном клоне /tmp/opencode-mem-verify, НЕ в рабочем
#    /tmp/opencode-mem: дерево sessions не трогается → «fork dirty» не роняет прогон;
#  - сессия привязывается по уникальному sentinel'у в T1, а не по «последняя в БД»
#    (раньше трейлер метрик снимался с чужой benchmark-сессии);
#  - маркеры компактации живут только в проекции (SQLite хранит оригиналы), поэтому
#    «markers with pii» меряется по memory-context.log, а не LIKE '%pii=%' по parts
#    ("structural zero" больше не выдаётся за результат);
#  - skip ≠ pass: пропуск завершает скрипт с кодом 78 и строкой SELFTEST SKIPPED.
#  - ходы идут на бинаре, собранном из того же verify-слона (не на установленном —
#    он отстаёт до релиза): гейт «версия содержит fork at», иначе exit 70 (issue #70).

set -u
FORK=/tmp/opencode-mem
VERIFY=/tmp/opencode-mem-verify
REPO=https://github.com/gpt-mem/opencode-mem.git
BRANCH=memory-context-v1
LOG_DIR=~/.opencode/scripts/selftest-logs
MEM_LOG=~/.local/share/opencode/log/memory-context.log
mkdir -p "$LOG_DIR"
STAMP=$(date +%Y%m%d-%H%M%S)
LOG="$LOG_DIR/selftest-$STAMP.log"
SENTINEL="ST-$STAMP"
START_MS=$(($(date +%s) * 1000))

export PATH="$HOME/.bun/bin:$PATH"
export OPENCODE_MEMORY_CONTEXT=1
export OPENCODE_MEMORY_CONTEXT_DEBUG=1
export OPENCODE_MEMORY_FIRST_DELIVERY=1
export OPENCODE_MEMORY_CACHE_MARK=1
export OPENCODE_MEMORY_INTENT=1
export OPENCODE_MEMORY_INTENT_DEBUG=1
export OPENCODE_MEMORY_INTENT_ACT=1

skip() { echo "$1" | tee -a "$LOG"; echo "=== SELFTEST $STAMP SKIPPED ===" | tee -a "$LOG"; exit 78; }

# --- Изолированный клон для прогона (самодостаточный) ---
if [ ! -d "$VERIFY/.git" ]; then
  if [ -d "$FORK/.git" ]; then
    git clone --branch "$BRANCH" "$REPO" "$VERIFY" >> "$LOG" 2>&1 \
      || git clone --branch "$BRANCH" "file://$FORK" "$VERIFY" >> "$LOG" 2>&1 \
      || skip "verify-клон не создать — selftest пропущен"
  else
    git clone --branch "$BRANCH" "$REPO" "$VERIFY" >> "$LOG" 2>&1 \
      || skip "verify-клон не создать — selftest пропущен"
  fi
fi
cd "$VERIFY" || skip "нет каталога $VERIFY"
git fetch origin "$BRANCH" >> "$LOG" 2>&1
git checkout "$BRANCH" >> "$LOG" 2>&1 || skip "checkout $BRANCH не удался"
git pull --ff-only origin "$BRANCH" >> "$LOG" 2>&1 \
  || git reset --hard "origin/$BRANCH" >> "$LOG" 2>&1 \
  || skip "синхронизация verify-слона не удалась"
if [ -n "$(git status --porcelain)" ]; then
  git reset --hard "origin/$BRANCH" >> "$LOG" 2>&1
  git clean -fd >> "$LOG" 2>&1
fi
FORK_AT=$(git rev-parse --short HEAD)
echo "fork at $FORK_AT (isolated worktree $VERIFY)" | tee -a "$LOG"
INSTALLED_VER=$("$HOME/.opencode/bin/opencode" --version 2>/dev/null || echo "unknown")
echo "installed binary: $INSTALLED_VER" | tee -a "$LOG"

# зависимости (быстро если уже установлены)
[ -d node_modules ] || bun install >> "$LOG" 2>&1

# Гоняем НЕ установленный бинарь (он отстаёт от tip до следующего релиза), а артефакт,
# собранный из этого verify-слона: иначе «полный selftest на tip» не проверяем по бинарю,
# а installed-строка в трейлере выглядит как несоответствие (issue #70).
echo "building binary from $FORK_AT..." | tee -a "$LOG"
if ! ( cd packages/opencode && bun run build ) >> "$LOG" 2>&1; then
  echo "build binary FAILED — прогон не проводился (issue #70)" | tee -a "$LOG"
  echo "LOG: $LOG"; exit 70
fi
ARCH=$(uname -m)
BIN="$VERIFY/packages/opencode/dist/opencode-darwin-$ARCH/bin/opencode"
if [ ! -x "$BIN" ]; then
  BIN=$(ls -t "$VERIFY"/packages/opencode/dist/opencode-darwin-*/bin/opencode 2>/dev/null | head -1)
fi
if [ -z "$BIN" ] || [ ! -x "$BIN" ]; then
  echo "built binary not found — прогон не проводился (issue #70)" | tee -a "$LOG"
  echo "LOG: $LOG"; exit 70
fi
BIN_VER=$("$BIN" --version 2>/dev/null | tail -1)
case "$BIN_VER" in
  *"$FORK_AT"*) echo "run binary: $BIN ($BIN_VER) — SHA совпал с fork at $FORK_AT" | tee -a "$LOG" ;;
  *)
    echo "binary SHA gate FAILED: '$BIN_VER' не содержит $FORK_AT — прогон не проводился (issue #70)" | tee -a "$LOG"
    echo "LOG: $LOG"; exit 70
    ;;
esac

OC="$BIN"
MODEL="opencode-go/mimo-v2.6-flash"

# Плотные документы с needle-фактами. Документы отдаются ПУТЯМИ, не --file:
# вложение минирует read-тул → контент не попадает в индекс tool-вызовов и не
# проходит компактацию (самопроверка прогона 20261012-072607, §4.1).
DOC_DIR=$(mktemp -d)
cat > "$DOC_DIR/doc1.md" << 'EOF'
# Deploy Runbook v3
Release ID: REL-7742-XK. Owner: william.shekspier@gmail.com
Rollback token: rbk_9f3a_deep_42. Region: eu-central-1.
Step 1: drain traffic. Step 2: swap image tag app:v3.2.1-rc4.
EOF
python3 -c "
import random
random.seed(42)
lines = ['# filler doc 2 — architecture notes']
for i in range(400):
    lines.append(f'note-{i}: component svc-{random.randint(100,999)} latency p95={random.randint(10,900)}ms status ok')
lines.append('NEEDLE-DOC2: the cache mark for provider go/mimo is stored under key CM-5581-A.')
open('$DOC_DIR/doc2.md','w').write('\n'.join(lines))
"
python3 -c "
import random
random.seed(7)
lines = ['# filler doc 3 — incident log']
for i in range(400):
    lines.append(f'incident-{i}: resolved code={random.choice([\"E42\",\"E77\",\"OK\"])} dur={random.randint(1,99)}m')
lines.append('NEEDLE-DOC3: escalation contact phone +7-999-123-45-67 for PII drills.')
open('$DOC_DIR/doc3.md','w').write('\n'.join(lines))
"

echo "=== SELFTEST $STAMP ===" | tee -a "$LOG"

# T1 идёт БЕЗ --continue: так создаётся свежая сессия прогона (раньше --continue
# пристёгивал dogfood к чужой последней сессии: её ledger/mark и чужие метрики).
run_turn() {
  local turn="$1"; shift
  echo "--- TURN $turn: $1" | tee -a "$LOG"
  $OC run --model "$MODEL" --auto "$1" >> "$LOG" 2>&1
}
run_turn_in() {
  local turn="$1"; shift
  echo "--- TURN $turn: $1" | tee -a "$LOG"
  $OC run --model "$MODEL" --auto --session "$SESSION" "$1" >> "$LOG" 2>&1
}

# T1 — архитектура и тулы (sentinel $SENTINEL нужен для привязки сессии)
run_turn T1 "Ты работаешь на новой архитектуре MEM (форк OpenCode, репо gpt-mem/opencode-mem, ветка memory-context-v1). Это self-review сессия. Метка прогона: $SENTINEL. Шаг 1: посмотри какие инструменты тебе доступны — особенно get_tool_call_overview, find_tool_calls, get_tool_call_details. Вызови get_tool_call_overview и покажи результат."

# Привязываем свежую сессию ДО остальных ходов: дальше работаем только в ней.
# Канал БД зависит от того, чем гоняли ходы: бинарь с channel=memory-context-v1 пишет
# в opencode-memory-context-v1.db, source-запуск (channel=local) — в opencode-local.db,
# сток — в opencode.db → ищем sentinel во всех opencode*.db (issue #70, прогон 123843).
SESSION="" DB="" SESSION_SOURCE=""
for db_try in "$HOME"/.local/share/opencode/opencode*.db; do
  [ -f "$db_try" ] || continue
  # Текст промпта живёт в parts (message.data у user хранит только метаданные) —
  # ищем sentinel по user-частям, не по ответам ассистента.
  hit=$(sqlite3 "$db_try" "SELECT m.session_id FROM part p
        JOIN message m ON p.message_id=m.id
        WHERE json_extract(m.data,'\$.role')='user' AND p.data LIKE '%$SENTINEL%'
        ORDER BY m.time_created DESC LIMIT 1" 2>/dev/null)
  if [ -n "$hit" ]; then SESSION="$hit"; DB="$db_try"; SESSION_SOURCE="sentinel"; break; fi
done
if [ -z "$SESSION" ]; then
  # Без привязанной сессии ходы ТОЛЬКО замусорят чужую — прогон провален явно.
  echo "session: NOT-BOUND (sentinel '$SENTINEL' не найден в opencode*.db) — оставшиеся ходы пропущены" | tee -a "$LOG"
  echo "LOG: $LOG"; rm -rf "$DOC_DIR"; exit 70
fi
echo "session: $SESSION (source=$SESSION_SOURCE db=$DB)" | tee -a "$LOG"

# T2 — решение
run_turn_in T2 "Запиши решение: «принято решение форкать опенкод и его развивать» — сохрани через put_in_operational_memory если тул доступен, иначе явно зафиксируй в тексте ответа как решение."

# T3 — PII
run_turn_in T3 "Вставлена почта: william.shekspier@gmail.com. Проверь через find_tool_calls или find_pii — появилась ли она в индексе артефактов/памяти? Покажи что нашёл."

# T4 — плотные документы читаются read-тулом (пути, не вложения)
run_turn_in T4 "Вот три плотных документа: $DOC_DIR/doc1.md, $DOC_DIR/doc2.md, $DOC_DIR/doc3.md. Прочитай КАЖДЫЙ через read-тул (не по памяти) и подтверди что получил needle-факты: из doc1 — Release ID, из doc2 — CM-ключ, из doc3 — escalation contact."

# T5 — ретрив решения
run_turn_in T5 "Вспомни: какое решение ты записал ранее? Используй тулы памяти для ретрива если нужно."

# T6 — ретрив PII
run_turn_in T6 "Вспомни почту из документа 1 — какая была email-адресат?"

# T7 — дисковери
run_turn_in T7 "Найди через find_tool_calls последние 5 tool-вызовов в этой сессии. Покажи call_id и статусы."

# T8 — детали
run_turn_in T8 "Возьми любой call_id из предыдущего результата и достань детали через get_tool_call_details."

# T9 — needle из сжатого (doc2 читался первым, его вывод старший → вероятнее всего уже под маркером)
run_turn_in T9 "Вспомни needle-факт из doc2: какой CM-ключ для provider go/mimo? Если в контексте только компакт-маркер — добудь оригинал через get_tool_call_details."

# T10 — финальный отчёт
run_turn_in T10 "Финальный отчёт self-review: 1) какие memory-тулы доступны; 2) какие использовал и где понадобился ретрив; 3) нашёл ли PII-теги; 4) что сломалось или удивило; 5) работает ли принцип «сжимаем но ничего не прячем» — оцени по 5-балльной шкале с обоснованием."

echo "=== SELFTEST $STAMP DONE ===" | tee -a "$LOG"

# ── Метрики по привязанной сессии ────────────────────────────────────────
sqlite3 "$DB" "
SELECT json_extract(data,'\$.role') || ' in=' || json_extract(data,'\$.tokens.input') ||
       ' out=' || json_extract(data,'\$.tokens.output') ||
       ' cache_r=' || json_extract(data,'\$.tokens.cache.read') ||
       ' cost=' || json_extract(data,'\$.cost')
FROM message WHERE session_id='$SESSION' AND json_extract(data,'\$.role')='assistant'
ORDER BY time_created" 2>/dev/null | tee -a "$LOG"

# Memory-тулы (по нашей сессии)
sqlite3 "$DB" "
SELECT json_extract(p.data,'\$.tool') || ' -> ' || substr(json_extract(p.data,'\$.state.input'),1,120)
FROM part p JOIN message m ON p.message_id=m.id
WHERE m.session_id='$SESSION' AND json_extract(p.data,'\$.type')='tool'
  AND json_extract(p.data,'\$.tool') IN ('get_tool_call_overview','find_tool_calls','get_tool_call_details','put_in_operational_memory','find_pii','search_operational_memory','get_operational_memory')
ORDER BY p.rowid" 2>/dev/null | tee -a "$LOG"

# Компакт-маркеры существуют ТОЛЬКО в проекции (оригиналы в SQLite не трогаются),
# поэтому меряемся по memory-context.log, а не по parts.
if [ -f "$MEM_LOG" ]; then
  MC_LINES=$(grep -c "session=$SESSION " "$MEM_LOG" 2>/dev/null || echo 0)
  MC_SUM=$(grep "session=$SESSION " "$MEM_LOG" 2>/dev/null \
    | sed -n 's/.*compacted=\([0-9]*\).*/\1/p' | sort -n | tail -1)
  MC_MARK=$(grep "session=$SESSION " "$MEM_LOG" 2>/dev/null \
    | sed -n 's/.*mark=\([0-9]*\).*/\1/p' | sort -n | tail -1)
  echo "compaction: log_lines=$MC_LINES max_compacted=${MC_SUM:-0} final_mark=${MC_MARK:-0}" | tee -a "$LOG"
  if [ "${MC_LINES:-0}" = "0" ]; then
    echo "compaction: NONE — сцена не спровоцировала компактацию (ожидаются маркеры у больших read/bash-выводов)" | tee -a "$LOG"
  fi
else
  echo "compaction: memory-context.log не найден (OPENCODE_MEMORY_CONTEXT_DEBUG=1 не писался)" | tee -a "$LOG"
fi

# PII: маскированные носители в индексе parts (previews/details). Сырых значений
# в лог не пишем — только счётчики по типам.
sqlite3 "$DB" "
SELECT 'redacted_placeholders=' || COUNT(*) FROM part p JOIN message m ON p.message_id=m.id
WHERE m.session_id='$SESSION' AND p.data LIKE '%[REDACTED:%'" 2>/dev/null | tee -a "$LOG"
sqlite3 "$DB" "
SELECT 'find_pii_invocations=' || COUNT(*) FROM part p JOIN message m ON p.message_id=m.id
WHERE m.session_id='$SESSION' AND json_extract(p.data,'\$.tool')='find_pii'" 2>/dev/null | tee -a "$LOG"
sqlite3 "$DB" "
SELECT 'email_placeholders=' || COUNT(*) FROM part p JOIN message m ON p.message_id=m.id
WHERE m.session_id='$SESSION' AND p.data LIKE '%[REDACTED:email]%'" 2>/dev/null | tee -a "$LOG"

# Сводка приёмочной тройки (fork == binary для «слито ≠ доступно модели»).
# binary= — бинарь, на котором реально шли ходы (собран из verify-слона, SHA-гейт выше);
# installed= — что стоит в ~/.opencode/bin (отстаёт до следующего релиза, issue #70).
echo "acceptance: verify_sha=$FORK_AT binary=$BIN_VER installed=$INSTALLED_VER sentinel=$SENTINEL started_ms=$START_MS" | tee -a "$LOG"

echo "LOG: $LOG"
rm -rf "$DOC_DIR"
exit 0
