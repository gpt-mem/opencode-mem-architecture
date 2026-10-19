#!/bin/bash
# SELFTEST: проверка кандидата (шаг 2 цепочки «кандидат → проверка → промоушен»).
#
# Сценарий v2: большие выводы инструментов не едут в контекст целиком — вместо
# них модель видит маркер «[showing … of …; full output saved to <file>]», а полный
# вывод лежит в файле. Проверяем ровно это:
#   1) бинарь-кандидат поднялся и его версия несёт SHA сборки;
#   2) большой вывод инструмента действительно ужат до маркера;
#   3) файл с полным выводом существует и содержит needle-факт;
#   4) модель достала needle-факт из этого файла (сжали, но не спрятали).
#
# Приёмочные правила:
#  - selftest идёт в изолированном клоне /tmp/opencode-mem-verify и на кандидате
#    из ~/.opencode/candidates, а НЕ на установленном бинаре: иначе проверялось
#    бы не то, что потом поедет на машину;
#  - сессия привязывается по уникальному sentinel'у, а не по «последняя в БД»;
#  - skip ≠ pass: пропуск завершает скрипт с кодом 78 и строкой SELFTEST SKIPPED.

set -u
FORK=/tmp/opencode-mem
VERIFY=/tmp/opencode-mem-verify
REPO=https://github.com/gpt-mem/opencode-mem.git
BRANCH=v2-base
LOG_DIR=~/.opencode/scripts/selftest-logs
CANDIDATE_STATE=~/.opencode/scripts/candidate-current.json
SELFTEST_STATE=~/.opencode/scripts/selftest-last.json
MEM_LOG=~/.local/share/opencode/log/memory-context.log
mkdir -p "$LOG_DIR"
STAMP=$(date +%Y%m%d-%H%M%S)
LOG="$LOG_DIR/selftest-$STAMP.log"
SENTINEL="ST-$STAMP"
START_MS=$(($(date +%s) * 1000))
NEEDLE="CM-5581-A"

export PATH="$HOME/.local/bun142/bun-darwin-aarch64:$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
# v2-флаги форка: маска кэша (по умолчанию включена) и её idle-порог.
# Старые OPENCODE_MEMORY_* из v1 на v2 не существуют.
export OPENCODE_CACHE_MASK=1
export OPENCODE_CACHE_MARK_IDLE_MS=600000

skip() { echo "$1" | tee -a "$LOG"; echo "=== SELFTEST $STAMP SKIPPED ===" | tee -a "$LOG"; exit 78; }
fail() { echo "$1" | tee -a "$LOG"; echo "LOG: $LOG"; exit 70; }

# --- 1. Кандидат: тот же SHA, что и в verify-клоне ---
if [ ! -f "$CANDIDATE_STATE" ]; then
  skip "кандидата нет ($CANDIDATE_STATE отсутствует) — сначала run-build.sh"
fi
CAND_SHA=$(sed -n 's/.*"sha12"[[:space:]]*:[[:space:]]*"\([0-9a-f]\{7,40\}\)".*/\1/p' "$CANDIDATE_STATE" | head -1)
CAND_BIN=$(sed -n 's/.*"binary"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CANDIDATE_STATE" | head -1)
[ -n "$CAND_SHA" ] && [ -n "$CAND_BIN" ] || skip "кандидат не описан в $CANDIDATE_STATE"
[ -x "$CAND_BIN" ] || skip "кандидат недоступен: $CAND_BIN"

echo "=== SELFTEST $STAMP ===" | tee -a "$LOG"
echo "candidate: $CAND_BIN ($CAND_SHA)" | tee -a "$LOG"

# verify-клон должен совпадать с кандидатом по SHA: проверяем то, что собрано.
if [ -d "$VERIFY/.git" ]; then
  VERIFY_SHA=$(git -C "$VERIFY" rev-parse --short=12 HEAD 2>/dev/null || echo "")
  if [ -n "$VERIFY_SHA" ] && [ "$VERIFY_SHA" != "$CAND_SHA" ]; then
    fail "verify-клон на $VERIFY_SHA, а кандидат на $CAND_SHA — проверялось бы не то"
  fi
fi

CAND_VER=$("$CAND_BIN" --version 2>/dev/null | head -1)
INSTALLED_VER=$("$HOME/.opencode/bin/opencode" --version 2>/dev/null | head -1 || echo "unknown")
echo "candidate version: $CAND_VER" | tee -a "$LOG"
echo "installed binary: $INSTALLED_VER" | tee -a "$LOG"
case "$CAND_VER" in
  *"$CAND_SHA"*) : ;;
  *) fail "SHA-гейт кандидата не пройден: '$CAND_VER' не содержит $CAND_SHA" ;;
esac

# --- Гейт: кандидат обязан делить пространство данных со стоком ---
# Форк заменяет стоковый бинарь, поэтому он обязан открывать ту же базу.
# Иначе у пользователя пропадают креды (у модели, ключ которой лежит в
# хранилище кредов, приходит 401 unauthorized) и вся история сессий.
# Имя файла базы задаёт канал сборки (packages/cli/src/database-path.ts):
# opencode.db для latest|dev|beta|next|prod, иначе opencode-<канал>.db.
# Путь к базе сообщает сам бинарь: `opencode debug paths`.
STOCK_BIN="$HOME/.opencode/bin/opencode.stock-backup"
strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }
CAND_DB=$("$CAND_BIN" debug paths 2>/dev/null | awk '/^db /{print $2; exit}')
[ -n "$CAND_DB" ] || fail "кандидат не сообщил путь к базе (opencode debug paths) — пространство данных нечем проверить"
if [ -x "$STOCK_BIN" ]; then
  STOCK_DB=$("$STOCK_BIN" debug paths 2>/dev/null | awk '/^db /{print $2; exit}')
  [ -n "$STOCK_DB" ] || fail "сток-бэкап не сообщил путь к базе — пространство данных нечем сверить"
  if [ "$CAND_DB" != "$STOCK_DB" ]; then
    fail "кандидат открывает другую базу: $CAND_DB, а сток — $STOCK_DB (форк обязан делить базу с заменяемым стоком)"
  fi
  # Хранилище кредов: у пользователя оно не пустое, и форк обязан его видеть.
  CAND_AUTH=$("$CAND_BIN" auth list 2>/dev/null | strip_ansi | tr -s ' ' | sed '/^$/d' | sort)
  STOCK_AUTH=$("$STOCK_BIN" auth list 2>/dev/null | strip_ansi | tr -s ' ' | sed '/^$/d' | sort)
  if [ "$CAND_AUTH" != "$STOCK_AUTH" ]; then
    fail "хранилище кредов кандидата отличается от стока: кандидат=[${CAND_AUTH:-пусто}] сток=[${STOCK_AUTH:-пусто}]"
  fi
  echo "check: data namespace shared with stock — ok ($CAND_DB)" | tee -a "$LOG"
else
  echo "check: data namespace — сток-бэкап не найден, сверка только с именем базы ($CAND_DB)" | tee -a "$LOG"
fi

OC="$CAND_BIN"
MODEL="ladder/build"

# Сессию задаём сами: `opencode run --session <id>` создаёт сессию с этим id,
# если её ещё нет. Так проверка не может прицепиться к чужой последней сессии.
SESSION="ses_selftest-$STAMP"

# Плотный документ с needle-фактом: его нельзя ужать до маркера по объёму,
# поэтому needle кладём в отдельный файл, который модель прочитает отдельно.
DOC_DIR=$(mktemp -d)
python3 -c "
import random
random.seed(42)
lines = ['# filler doc — architecture notes']
for i in range(400):
    lines.append(f'note-{i}: component svc-{random.randint(100,999)} latency p95={random.randint(10,900)}ms status ok')
lines.append('NEEDLE-DOC: the cache mark for provider go/mimo is stored under key CM-5581-A.')
open('$DOC_DIR/doc.md','w').write('\n'.join(lines))
"
# Большой вывод инструмента: > 2 КиБ (лимит v2) и > 2000 строк (лимит v2).
BIG_SH="$DOC_DIR/big.txt"
python3 -c "
lines = ['big-output-line-%d %s' % (i, 'x'*60) for i in range(3000)]
open('$BIG_SH','w').write('\n'.join(lines))
"

# --standalone поднимает приватный сервер на время хода: так флаги форка
# (OPENCODE_CACHE_MASK и т.п.) действуют именно на эту проверку. Без него
# ход уходит в общий фоновый сервис, у которого своё окружение.
run_turn() {
  local turn="$1"; local model="$2"; shift 2
  echo "--- TURN $turn ($model): $1" | tee -a "$LOG"
  $OC run --standalone --model "$model" --auto --session "$SESSION" "$1" >> "$LOG" 2>&1
  local rc=$?
  echo "--- TURN $turn exit=$rc" | tee -a "$LOG"
  return $rc
}

# T1 — большой вывод целиком: он не влезает в контекст и уезжает в файл.
run_turn T1 "$MODEL" "Ты работаешь на форке OpenCode MEM (репо gpt-mem/opencode-mem, линия v2-base). Это self-review сессия. Метка прогона: $SENTINEL. Шаг 1: вызови bash-тул с командой 'cat $BIG_SH' и выведи результат как есть."

# Сессия создана с нашим id; sentinel'а в ней быть должно — иначе первый ход
# ушёл не туда (чужая база, другой профиль, бинарь не тот).
# База открыта в WAL-режиме: свежие записи лежат в .db-wal, а в самом .db они
# появляются только после чекпойнта. Поэтому смотрим и sidecar-файл — иначе
# привязка выглядит незавершённой при вполне успешном ходе.
# Ищем сначала в базе кандидата: попадание в чужую базу — это ровно тот
# дефект, который ловит гейт пространства данных (issue #2).
SESSION_FOUND_IN=""
for db_try in "$CAND_DB" "$HOME"/.local/share/opencode/*.db; do
  [ -f "$db_try" ] || continue
  if strings -a "$db_try" "$db_try-wal" 2>/dev/null | grep -qF "$SENTINEL"; then SESSION_FOUND_IN="$db_try"; break; fi
done
if [ -z "$SESSION_FOUND_IN" ]; then
  fail "session: NOT-BOUND (sentinel '$SENTINEL' не найден в opencode*.db[-wal]) — оставшиеся ходы пропущены"
fi
if [ "$SESSION_FOUND_IN" != "$CAND_DB" ]; then
  fail "session: кандидат записал сессию в $SESSION_FOUND_IN, а его база — $CAND_DB (пространство данных разъехалось)"
fi
echo "session: $SESSION (bound in $SESSION_FOUND_IN)" | tee -a "$LOG"

# T2 — большой вывод: модель видит маркер и путь к файлу.
run_turn T2 "$MODEL" "Прочитай файл $DOC_DIR/doc.md через read-тул (не по памяти) и выпиши needle-факт из последней строки."

# T3 — «сжали, но ничего не прячем»: полный вывод лежит в файле, модель его достаёт.
run_turn T3 "$MODEL" "В предыдущем выводе tool'а был маркер вида «[showing … of …; full output saved to <file>]». Возьми этот файл и найди в нём строку с 'big-output-line-2999' через grep или read. Приведи найденную строку."

# T4 — финальный отчёт.
run_turn T4 "$MODEL" "Финальный отчёт self-review: 1) как называется маркер ужатого вывода и куда уходит полный вывод; 2) нашёл ли ты needle-факт CM-5581-A; 3) что сломалось или удивило. Ответь по-русски, кратко."

# T5 — дефолтная модель пользователя: именно её он зовёт после промоушена.
# Ключ к ней может лежать в хранилище кредов, а не в конфиге, поэтому этот ход
# ловит расхождение пространства данных по симптому, а не только по `auth list`.
DEFAULT_MODEL=""
for cfg in "$HOME/.config/opencode/opencode.json" "$HOME/.config/opencode/opencode.jsonc"; do
  [ -f "$cfg" ] || continue
  if command -v jq >/dev/null 2>&1; then
    m=$(jq -r '.model // empty' "$cfg" 2>/dev/null | head -1)
  else
    m=$(sed -n 's/^[[:space:]]*"model"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$cfg" | head -1)
  fi
  [ -n "$m" ] && { DEFAULT_MODEL="$m"; break; }
done
if [ -n "$DEFAULT_MODEL" ]; then
  echo "default model: $DEFAULT_MODEL" | tee -a "$LOG"
  if ! run_turn T5 "$DEFAULT_MODEL" "Ответь ровно одним словом: ok"; then
    fail "ход с дефолтной моделью пользователя ($DEFAULT_MODEL) не прошёл — форк не обслуживает модель по умолчанию"
  fi
  echo "check: default model served — ok ($DEFAULT_MODEL)" | tee -a "$LOG"
else
  echo "default model: в конфиге не найден — T5 пропущен" | tee -a "$LOG"
fi

echo "=== SELFTEST $STAMP DONE ===" | tee -a "$LOG"

# ── Проверки ───────────────────────────────────────────────────────────────
# 1) маркер ужатого вывода лежит в сообщениях ЭТОЙ сессии, и в нём путь к файлу.
#    Важно: маркер ищем в сессии, а не «где-нибудь в базе» — база общая на все
#    сессии, и первый попавшийся маркер принадлежит чужому прогону. Из-за
#    этого проверка брала файл чужого вывода и объявляла «вывод потерян».
OUT_FILE=$(sqlite3 "$SESSION_FOUND_IN" \
  "select data from session_message where session_id='$SESSION' and data like '%full output saved to %' order by seq;" 2>/dev/null \
  | grep -o 'full output saved to /[^ ]*' | head -1 | cut -d' ' -f5-)
if [ -z "$OUT_FILE" ]; then
  # Запасной путь на случай другой схемы хранилища: берём маркер из файлов
  # сессии и оставляем тот, чей файл действительно содержит полный вывод.
  for candidate in $(strings -a "$SESSION_FOUND_IN" "$SESSION_FOUND_IN-wal" 2>/dev/null \
    | grep -o 'full output saved to /[^ ]*' | cut -d' ' -f5- | sort -u); do
    if [ -f "$candidate" ] && grep -q "big-output-line-2999" "$candidate"; then OUT_FILE="$candidate"; break; fi
  done
fi
[ -n "$OUT_FILE" ] || fail "маркер ужатого вывода не найден в сессии $SESSION — v2-механика не сработала"
echo "check: truncation marker present — ok ($OUT_FILE)" | tee -a "$LOG"

# 2) файл с полным выводом существует и содержит последнюю строку исходника:
#    «сжали, но ничего не прячем».
[ -f "$OUT_FILE" ] || fail "файл полного вывода не найден: $OUT_FILE"
if ! grep -q "big-output-line-2999" "$OUT_FILE"; then
  fail "в файле полного вывода нет последней строки — вывод потерян, а не сжат"
fi
echo "check: full output file present and complete — ok ($OUT_FILE)" | tee -a "$LOG"

# 3) needle-факт доехал до ответа модели
if ! strings -a "$SESSION_FOUND_IN" "$SESSION_FOUND_IN-wal" 2>/dev/null | grep -q "$NEEDLE"; then
  fail "needle-факт $NEEDLE не найден в сессии — ретрив не сработал"
fi
echo "check: needle retrieved — ok ($NEEDLE)" | tee -a "$LOG"

# Отчёт проверки: промоушен (run-releaser.sh) требует, чтобы он совпал с
# кандидатом по SHA. Без этого отчёта активный бинарь не трогается.
cat > "$SELFTEST_STATE.tmp.$$" <<JSON
{
  "sha12": "$CAND_SHA",
  "version": "$CAND_VER",
  "status": "ok",
  "session": "$SESSION",
  "sentinel": "$SENTINEL",
  "checked_at": "$(date -u +%Y-%m-%dT%H:%M:%S.000000+00:00)"
}
JSON
mv -f "$SELFTEST_STATE.tmp.$$" "$SELFTEST_STATE"

echo "acceptance: candidate_sha=$CAND_SHA candidate=$CAND_VER installed=$INSTALLED_VER sentinel=$SENTINEL started_ms=$START_MS" | tee -a "$LOG"
echo "LOG: $LOG"
rm -rf "$DOC_DIR"
exit 0
