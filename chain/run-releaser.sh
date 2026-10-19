#!/bin/bash
# RELEASER: промоушен проверенного кандидата.
#
# Шаг 3 цепочки «кандидат → проверка → промоушен». Публикует релиз, ставит
# сборку через mem-builds.sh (каталог сборок, симлинки current/previous,
# манифест, регистрация в Session Manager) и подменяет активный бинарь.
#
# Активный бинарь трогается ТОЛЬКО после зелёной проверки того же SHA:
# сценарий проверки пишет ~/.opencode/scripts/selftest-last.json, и этот файл
# обязан совпасть с кандидатом. Без совпадения — exit 77, ничего не меняется.

set -u
VERIFY=/tmp/opencode-mem-verify
BRANCH=v2-base
REPO=gpt-mem/opencode-mem
LOG_DIR=~/.opencode/scripts/releaser-logs
CANDIDATE_STATE=~/.opencode/scripts/candidate-current.json
SELFTEST_STATE=~/.opencode/scripts/selftest-last.json
BIN_DIR="$HOME/.opencode/bin"
MEM_BUILDS_SCRIPT="${MEM_BUILDS_SCRIPT:-$HOME/opencode-mem-architecture/chain/mem-builds.sh}"
[ -x "$MEM_BUILDS_SCRIPT" ] || MEM_BUILDS_SCRIPT="$HOME/.opencode/scripts/mem-builds.sh"
mkdir -p "$LOG_DIR"
STAMP=$(date +%Y%m%d-%H%M%S)
LOG="$LOG_DIR/releaser-$STAMP.log"

# launchd даёт минимальный PATH — gh/node живут в homebrew.
export PATH="$HOME/.local/bun142/bun-darwin-aarch64:$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

echo "=== RELEASE $STAMP ===" | tee -a "$LOG"

# 0. Гейт: промоушен только после зелёной проверки того же SHA.
if [ "${MEM_REQUIRE_SELFTEST:-0}" = "1" ] && [ "${MEM_SELFTEST_OK:-0}" != "1" ]; then
  echo "RELEASE withheld: MEM_REQUIRE_SELFTEST=1 без MEM_SELFTEST_OK=1 (нет полного selftest)" | tee -a "$LOG"
  exit 77
fi

# 1. Кандидат: тот же SHA, что и в проверке.
if [ ! -f "$CANDIDATE_STATE" ]; then
  echo "RELEASE withheld: нет кандидата ($CANDIDATE_STATE)" | tee -a "$LOG"
  exit 77
fi
SHA=$(sed -n 's/.*"sha"[[:space:]]*:[[:space:]]*"\([0-9a-f]\{7,40\}\)".*/\1/p' "$CANDIDATE_STATE" | head -1)
SHA12=$(sed -n 's/.*"sha12"[[:space:]]*:[[:space:]]*"\([0-9a-f]\{7,40\}\)".*/\1/p' "$CANDIDATE_STATE" | head -1)
CAND_BIN=$(sed -n 's/.*"binary"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CANDIDATE_STATE" | head -1)
[ -n "$SHA" ] && [ -n "$SHA12" ] && [ -n "$CAND_BIN" ] || { echo "RELEASE withheld: кандидат не описан" | tee -a "$LOG"; exit 77; }
[ -x "$CAND_BIN" ] || { echo "RELEASE withheld: кандидат недоступен: $CAND_BIN" | tee -a "$LOG"; exit 77; }

if [ -f "$SELFTEST_STATE" ]; then
  SELFTEST_SHA=$(sed -n 's/.*"sha12"[[:space:]]*:[[:space:]]*"\([0-9a-f]\{7,40\}\)".*/\1/p' "$SELFTEST_STATE" | head -1)
  SELFTEST_STATUS=$(sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$SELFTEST_STATE" | head -1)
  if [ "$SELFTEST_SHA" != "$SHA12" ] || [ "$SELFTEST_STATUS" != "ok" ]; then
    echo "RELEASE withheld: проверка касалась $SELFTEST_SHA (статус $SELFTEST_STATUS), а кандидат — $SHA12" | tee -a "$LOG"
    exit 77
  fi
  echo "gate: selftest ok for $SHA12" | tee -a "$LOG"
else
  echo "RELEASE withheld: нет отчёта проверки ($SELFTEST_STATE)" | tee -a "$LOG"
  exit 77
fi

# Гейт пространства данных: форк заменяет стоковый бинарь и обязан открывать
# ту же базу. Иначе промоушен уводит пользователя в пустую параллельную базу:
# креды и вся история сессий остаются в стоковой, а дефолтная модель отдаёт
# 401 unauthorized (issue #2). Путь к базе сообщает сам бинарь.
STOCK_REF="$BIN_DIR/opencode.stock-backup"
if [ -x "$STOCK_REF" ]; then
  CAND_DB=$("$CAND_BIN" debug paths 2>/dev/null | awk '/^db /{print $2; exit}')
  STOCK_DB=$("$STOCK_REF" debug paths 2>/dev/null | awk '/^db /{print $2; exit}')
  if [ -n "$CAND_DB" ] && [ -n "$STOCK_DB" ] && [ "$CAND_DB" != "$STOCK_DB" ]; then
    echo "RELEASE withheld: кандидат открывает другую базу ($CAND_DB), сток — $STOCK_DB" | tee -a "$LOG"
    exit 77
  fi
  echo "gate: data namespace shared with stock — ok (${CAND_DB:-неизвестно})" | tee -a "$LOG"
fi

CAND_VER=$("$CAND_BIN" --version 2>/dev/null | head -1)
echo "candidate: $SHA12 ($CAND_VER)" | tee -a "$LOG"

# 2. Дубль-релиз того же SHA — не публикуем дважды.
git -C "$VERIFY" fetch --tags origin >> "$LOG" 2>&1
if git -C "$VERIFY" tag -l "mem-*-${SHA12}" | grep -q .; then
  echo "Release for $SHA12 уже существует ($(git -C "$VERIFY" tag -l "mem-*-${SHA12}" | head -1)) — дубль не публикуем" | tee -a "$LOG"
  exit 0
fi

# 3. Тег + ассеты. Имя архива совпадает с форматом, который ждёт гейт
# промоушена агента: opencode-<os>-<arch>.tar.gz + .sha256.
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ASSET="opencode-${OS}-${ARCH}.tar.gz"
STAGE=$(mktemp -d)
mkdir -p "$STAGE/bin"
cp -f "$CAND_BIN" "$STAGE/bin/opencode" && chmod +x "$STAGE/bin/opencode"
tar -czf "$STAGE/$ASSET" -C "$STAGE/bin" opencode
( cd "$STAGE" && shasum -a 256 "$ASSET" > "$ASSET.sha256" )
echo "asset: $ASSET ($(stat -f%z "$STAGE/$ASSET" 2>/dev/null || stat -c%s "$STAGE/$ASSET") bytes)" | tee -a "$LOG"

TAG="mem-v$(date +%Y%m%d-%H%M)-${SHA12}"
NOTES="$STAGE/notes.md"
{
  echo "OpenCode MEM (v2) — сборка форка для локальной машины."
  echo ""
  echo "## Сборка"
  echo "- SHA: \`$SHA\`"
  echo "- версия: \`$CAND_VER\`"
  echo "- линия: \`$BRANCH\`"
  echo ""
  echo "## Как поставить"
  echo '```'
  echo "tar -xzf $ASSET -C /tmp && install -m 0755 /tmp/opencode ~/.opencode/bin/opencode"
  echo '```'
  echo ""
  echo "Сток лежит рядом как \`~/.opencode/bin/opencode.stock-backup\`."
  echo "Полная раскладка сборок (current/previous, откат) — в README форка."
  echo ""
  echo "## Флаги v2"
  echo '- `OPENCODE_CACHE_MASK=0` — выключить маску кэша (по умолчанию включена)'
  echo '- `OPENCODE_CACHE_MARK_IDLE_MS` — через сколько мс простоя считать scope холодным'
} > "$NOTES"

# 4. Публикация релиза. --target обязателен: без него GitHub вешает тег на
# default-branch, а не на выпущенный SHA.
#
# GitHub API на POST /releases флапает: на одном и том же токене подряд идут
# 403 "Resource not accessible by personal access token" и 500 "Unexpected end
# of JSON input" вперемешку с успехом. Публикация поэтому повторяется, а
# частичный успех (релиз создан, ассет не догружен) дочищается загрузкой
# ассета, а не пересозданием релиза.
REL_OK=1
RELEASE_TRIES="${MEM_RELEASE_TRIES:-6}"
try=1
while [ "$try" -le "$RELEASE_TRIES" ]; do
  if gh release create "$TAG" "$STAGE/$ASSET" "$STAGE/$ASSET.sha256" \
      --repo "$REPO" \
      --target "$SHA" \
      --title "MEM build $TAG" \
      --notes-file "$NOTES" >> "$LOG" 2>&1; then
    echo "release published: $TAG -> $SHA" | tee -a "$LOG"
    REL_OK=0
    break
  fi
  # Частичный успех: релиз есть, ассет(ы) не догружены.
  if gh release view "$TAG" --repo "$REPO" >> "$LOG" 2>&1; then
    echo "release exists, догружаем ассеты (попытка $try)" | tee -a "$LOG"
    if gh release upload "$TAG" "$STAGE/$ASSET" "$STAGE/$ASSET.sha256" --clobber --repo "$REPO" >> "$LOG" 2>&1; then
      echo "release published: $TAG -> $SHA" | tee -a "$LOG"
      REL_OK=0
      break
    fi
  fi
  echo "release publish failed (попытка $try/$RELEASE_TRIES), повтор через 15с" | tee -a "$LOG"
  sleep 15
  try=$((try + 1))
done
if [ "$REL_OK" != "0" ]; then
  echo "RELEASE FAILED после $RELEASE_TRIES попыток (см. лог)" | tee -a "$LOG"
fi

# 5. Промоушен локально: mem-builds.sh ставит сборку в builds/<sha12>,
# двигает current/previous, пишет манифест и регистрирует сборки в Session
# Manager. Активный бинарь подменяем после этого.
if [ -x "$MEM_BUILDS_SCRIPT" ]; then
  "$MEM_BUILDS_SCRIPT" install "$CAND_BIN" --sha "$SHA12" --version "$CAND_VER" >> "$LOG" 2>&1 \
    && echo "mem-builds: installed $SHA12" | tee -a "$LOG" \
    || { echo "mem-builds install FAILED" | tee -a "$LOG"; exit 1; }
else
  echo "mem-builds.sh не найден ($MEM_BUILDS_SCRIPT) — сборка не поставлена" | tee -a "$LOG"
  exit 1
fi

# Активный бинарь: не перезаписываем файл на месте (cp) — его мапят запущенные
# opencode-процессы, macOS даёт SIGKILL на exec изменённого маппинга.
# Копируем в НОВЫЙ файл и атомарно mv.
# Сток-бэкап — это запасной путь назад на стоковую линию. Он должен быть
# настоящим стоком: форк (метка "fork-at-<sha>" в версии) стоком быть не
# может, а устаревший бэкап от другой линии (v1 вместо v2) уводит откат не
# туда. Поэтому бэкапим активный бинарь, только если он стоковый, и обновляем
# бэкап, если он другой версии.
STOCK_BIN="$BIN_DIR/opencode.stock-backup"
ACTIVE_VER_BEFORE="$("$BIN_DIR/opencode" --version 2>/dev/null | head -1 || true)"
STOCK_VER="$( [ -f "$STOCK_BIN" ] && "$STOCK_BIN" --version 2>/dev/null | head -1 || true )"
case "$ACTIVE_VER_BEFORE" in
  *fork-at-*) echo "stock: активный бинарь — форк ($ACTIVE_VER_BEFORE), бэкап стока не трогаем" | tee -a "$LOG" ;;
  *)
    if [ "$STOCK_VER" != "$ACTIVE_VER_BEFORE" ]; then
      cp -f "$BIN_DIR/opencode" "$STOCK_BIN" \
        && echo "stock backed up: $ACTIVE_VER_BEFORE (было: ${STOCK_VER:-нет})" | tee -a "$LOG"
    fi
    ;;
esac
NEWBIN="$BIN_DIR/opencode.new.$$"
cp -f "$HOME/.opencode/builds/$SHA12/opencode" "$NEWBIN" && chmod +x "$NEWBIN"
mv -f "$NEWBIN" "$BIN_DIR/opencode"
INSTALLED_VER=$("$BIN_DIR/opencode" --version 2>/dev/null | head -1)
echo "installed: ${INSTALLED_VER:-(занят запущенным процессом, подхватится при новом старте)}" | tee -a "$LOG"

case "$INSTALLED_VER" in
  *"$SHA12"*) echo "installed SHA ok: $INSTALLED_VER содержит $SHA12" | tee -a "$LOG" ;;
  *)
    echo "RELEASE FAILED: installed version '$INSTALLED_VER' не содержит $SHA12" | tee -a "$LOG"
    exit 1
    ;;
esac

cp "$NOTES" "$HOME/.opencode/scripts/release-current.md" 2>/dev/null || true
rm -rf "$STAGE"
if [ "$REL_OK" != "0" ]; then
  echo "RELEASE FAILED: GitHub Release/$TAG не опубликован (тега нет)" | tee -a "$LOG"
  echo "LOG: $LOG"
  exit 1
fi
echo "=== RELEASE $STAMP DONE ===" | tee -a "$LOG"
echo "LOG: $LOG"
