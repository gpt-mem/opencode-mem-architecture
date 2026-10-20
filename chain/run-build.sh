#!/bin/bash
# BUILD: кандидат — сборка форка из v2-линии в стейджинг.
#
# Шаг 1 цепочки «кандидат → проверка → промоушен». Кандидат сюда НЕ
# устанавливается: активный бинарь не трогается, пока проверка не зелёная.
# Промоушеном занимается run-releaser.sh (он зовёт mem-builds.sh install).
#
# Линия: main (packages/core + packages/cli). Старая v1-раскладка
# (packages/opencode, ветка memory-context-v1) больше не используется.
#
# Артефакты:
#   ~/.opencode/candidates/<sha12>/opencode   бинарь-кандидат
#   ~/.opencode/scripts/candidate-current.json  sha/путь/версия кандидата
#   ~/.opencode/scripts/build-logs/build-<STAMP>.log

set -u
FORK=/tmp/opencode-mem
VERIFY=/tmp/opencode-mem-verify
REPO=https://github.com/gpt-mem/opencode-mem.git
BRANCH=main
LOG_DIR=~/.opencode/scripts/build-logs
CANDIDATES_DIR=~/.opencode/candidates
CANDIDATE_STATE=~/.opencode/scripts/candidate-current.json
mkdir -p "$LOG_DIR" "$CANDIDATES_DIR"
STAMP=$(date +%Y%m%d-%H%M%S)
LOG="$LOG_DIR/build-$STAMP.log"

# launchd даёт минимальный PATH — bun лежит в homebrew/локальной сборке.
export PATH="$HOME/.local/bun142/bun-darwin-aarch64:$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

echo "=== BUILD $STAMP ===" | tee -a "$LOG"

# --- 1. Изолированный клон на main (самодостаточный) ---
if [ ! -d "$VERIFY/.git" ]; then
  if [ -d "$FORK/.git" ]; then
    git clone --branch "$BRANCH" "file://$FORK" "$VERIFY" >> "$LOG" 2>&1 \
      || git clone --branch "$BRANCH" "$REPO" "$VERIFY" >> "$LOG" 2>&1 \
      || { echo "verify-клон не создать — сборка не пошла" | tee -a "$LOG"; exit 1; }
  else
    git clone --branch "$BRANCH" "$REPO" "$VERIFY" >> "$LOG" 2>&1 \
      || { echo "verify-клон не создать — сборка не пошла" | tee -a "$LOG"; exit 1; }
  fi
fi
cd "$VERIFY" || { echo "нет каталога $VERIFY" | tee -a "$LOG"; exit 1; }
git fetch origin "$BRANCH" >> "$LOG" 2>&1
git checkout "$BRANCH" >> "$LOG" 2>&1 || { echo "checkout $BRANCH не удался" | tee -a "$LOG"; exit 1; }
git pull --ff-only origin "$BRANCH" >> "$LOG" 2>&1 \
  || git reset --hard "origin/$BRANCH" >> "$LOG" 2>&1 \
  || { echo "синхронизация verify-слона не удалась" | tee -a "$LOG"; exit 1; }
if [ -n "$(git status --porcelain)" ]; then
  git reset --hard "origin/$BRANCH" >> "$LOG" 2>&1
  git clean -fd >> "$LOG" 2>&1
fi
FULL_SHA=$(git rev-parse HEAD)
SHA12=$(git rev-parse --short=12 HEAD)
echo "HEAD: $FULL_SHA ($SHA12) branch=$BRANCH" | tee -a "$LOG"

# --- 2. Зависимости (быстро, если уже стоят) ---
if [ ! -d node_modules ]; then
  bun install >> "$LOG" 2>&1 || { echo "bun install FAILED" | tee -a "$LOG"; exit 1; }
fi

# --- 3. Сборка кандидата (v2-раскладка) ---
# Версия вшивается в бинарь через OPENCODE_VERSION (packages/cli/src/version.ts
# → define в packages/cli/script/build.ts), поэтому в ней есть SHA сборки —
# на этом же держится гейт «бинарь == проверяемый SHA» в run-selftest.sh.
export OPENCODE_VERSION="0.0.0-fork-at-$SHA12"
# Канал вшивается в бинарь тем же define и ОПРЕДЕЛЯЕТ ИМЯ ФАЙЛА БАЗЫ:
# packages/cli/src/database-path.ts берёт opencode.db только для каналов
# latest|dev|beta|next|prod, иначе opencode-<канал>.db. Без явного канала
# скрипт сборки выводит его из имени ветки (packages/script/src/index.ts),
# и форк уезжал в отдельную базу opencode-main.db: у пользователя исчезали
# креды (модель mem-gpt/build отдавала 401 unauthorized) и все 161 сессия.
# Форк заменяет стоковый бинарь — значит обязан делить с ним базу.
export OPENCODE_CHANNEL="latest"
echo "building candidate ($OPENCODE_VERSION)..." | tee -a "$LOG"
if ! ( cd packages/cli && bun run script/build.ts --single --skip-install --skip-web-ui ) >> "$LOG" 2>&1; then
  echo "BUILD FAILED — кандидата нет" | tee -a "$LOG"
  echo "LOG: $LOG"; exit 70
fi
ARCH=$(uname -m)
BIN="$VERIFY/packages/cli/dist/cli-darwin-$ARCH/bin/opencode"
if [ ! -x "$BIN" ]; then
  BIN=$(ls -t "$VERIFY"/packages/cli/dist/cli-darwin-*/bin/opencode 2>/dev/null | head -1)
fi
if [ -z "$BIN" ] || [ ! -x "$BIN" ]; then
  echo "built binary not found — кандидата нет" | tee -a "$LOG"
  echo "LOG: $LOG"; exit 70
fi
BIN_VER=$("$BIN" --version 2>/dev/null | head -1)
echo "candidate: $BIN ($BIN_VER)" | tee -a "$LOG"

# Гейт: версия обязана нести SHA сборки. Без этого «проверка кандидата» проверяла
# бы не тот бинарь, который потом поедет на машину.
case "$BIN_VER" in
  *"$SHA12"*) echo "candidate SHA ok: $BIN_VER содержит $SHA12" | tee -a "$LOG" ;;
  *)
    echo "CANDIDATE SHA GATE FAILED: '$BIN_VER' не содержит $SHA12" | tee -a "$LOG"
    echo "LOG: $LOG"; exit 70
    ;;
esac

# --- 4. Стейджинг: кандидат не трогает активный бинарь ---
STAGE_DIR="$CANDIDATES_DIR/$SHA12"
mkdir -p "$STAGE_DIR"
cp -f "$BIN" "$STAGE_DIR/opencode.new" && chmod +x "$STAGE_DIR/opencode.new"
mv -f "$STAGE_DIR/opencode.new" "$STAGE_DIR/opencode"

cat > "$CANDIDATE_STATE.tmp.$$" <<JSON
{
  "sha": "$FULL_SHA",
  "sha12": "$SHA12",
  "branch": "$BRANCH",
  "version": "$BIN_VER",
  "binary": "$STAGE_DIR/opencode",
  "built_at": "$(date -u +%Y-%m-%dT%H:%M:%S.000000+00:00)"
}
JSON
mv -f "$CANDIDATE_STATE.tmp.$$" "$CANDIDATE_STATE"

echo "staged: $STAGE_DIR/opencode" | tee -a "$LOG"
echo "state: $CANDIDATE_STATE" | tee -a "$LOG"
echo "=== BUILD $STAMP DONE ===" | tee -a "$LOG"
echo "LOG: $LOG"
