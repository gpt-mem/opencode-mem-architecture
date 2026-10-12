#!/bin/bash
# Releaser: собирает форк, публикует GitHub Release, ставит бинарь как активный opencode.
# Запускается mem-chain'ом ПОСЛЕ selftest (issue #67) или вручную.
#
# Сборка идёт из изолированного клона /tmp/opencode-mem-verify (тот же каталог,
# что у selftest): рабочее дерево /tmp/opencode-mem, где идут сессии, в сборку
# не попадает → SHA бинаря == SHA проверенного прогона, дерево всегда чистое.

set -u
FORK=/tmp/opencode-mem
VERIFY=/tmp/opencode-mem-verify
BRANCH=memory-context-v1
REPO=gpt-mem/opencode-mem
LOG_DIR=~/.opencode/scripts/releaser-logs
mkdir -p "$LOG_DIR"
STAMP=$(date +%Y%m%d-%H%M%S)
LOG="$LOG_DIR/releaser-$STAMP.log"
BIN_DIR="$HOME/.opencode/bin"

# launchd даёт минимальный PATH (/usr/bin:/bin:...) — gh/node живут в homebrew.
export PATH="$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

echo "=== RELEASE $STAMP ===" | tee -a "$LOG"

# 0. Гейт: релиз после полного selftest того же tip (mem-chain выставляет оба ключа)
if [ "${MEM_REQUIRE_SELFTEST:-0}" = "1" ] && [ "${MEM_SELFTEST_OK:-0}" != "1" ]; then
  echo "RELEASE withheld: MEM_REQUIRE_SELFTEST=1 без MEM_SELFTEST_OK=1 (нет полного selftest)" | tee -a "$LOG"
  exit 77
fi

# 1. Изолированный клон (самодостаточный)
if [ ! -d "$VERIFY/.git" ]; then
  if [ -d "$FORK/.git" ]; then
    git clone --branch "$BRANCH" "file://$FORK" "$VERIFY" >> "$LOG" 2>&1 \
      || git clone --branch "$BRANCH" "https://github.com/$REPO.git" "$VERIFY" >> "$LOG" 2>&1
  else
    git clone --branch "$BRANCH" "https://github.com/$REPO.git" "$VERIFY" >> "$LOG" 2>&1
  fi
fi
cd "$VERIFY" || { echo "no verify clone" | tee -a "$LOG"; exit 1; }
git fetch origin "$BRANCH" >> "$LOG" 2>&1
git checkout "$BRANCH" >> "$LOG" 2>&1
git pull --ff-only origin "$BRANCH" >> "$LOG" 2>&1 || git reset --hard "origin/$BRANCH" >> "$LOG" 2>&1
if [ -n "$(git status --porcelain)" ]; then
  echo "verify tree dirty после синхронизации — чистим перед сборкой" | tee -a "$LOG"
  git reset --hard "origin/$BRANCH" >> "$LOG" 2>&1
  git clean -fd >> "$LOG" 2>&1
fi
SHA=$(git rev-parse --short HEAD)
FULL_SHA=$(git rev-parse HEAD)
echo "HEAD: $SHA (isolated $VERIFY)" | tee -a "$LOG"
if [ ! -d node_modules ]; then
  bun install >> "$LOG" 2>&1 || { echo "bun install FAILED" | tee -a "$LOG"; exit 1; }
fi

# 2. Дубль-релиз того же SHA (guard: локальные теги синхронизируем с remote)
git fetch --tags origin >> "$LOG" 2>&1
if git tag -l "mem-*-${SHA}" | grep -q .; then
  echo "Release for $SHA уже существует ($(git tag -l "mem-*-${SHA}" | head -1)) — дубль не публикуем" | tee -a "$LOG"
  exit 0
fi
LAST_TAG=$(git tag -l 'mem-*' --sort=-v:refname | head -1)
if [ -n "$LAST_TAG" ] && [ "$(git rev-list --count $LAST_TAG..HEAD)" = "0" ]; then
  echo "No new commits since $LAST_TAG — релиз не нужен" | tee -a "$LOG"
  exit 0
fi
NEW_COMMITS=$(git rev-list --count ${LAST_TAG:+$LAST_TAG..}HEAD)
echo "New commits: $NEW_COMMITS (last tag: ${LAST_TAG:-none})" | tee -a "$LOG"

# 3. Сборка бинаря (выбираем правильную архитектуру)
cd "$VERIFY/packages/opencode" || exit 1
echo "building binary..." | tee -a "$LOG"
bun run build >> "$LOG" 2>&1
ARCH=$(uname -m)  # arm64 | x64
BIN="$VERIFY/packages/opencode/dist/opencode-darwin-$ARCH/bin/opencode"
if [ ! -x "$BIN" ]; then
  BIN=$(ls -t "$VERIFY"/packages/opencode/dist/opencode-darwin-*/bin/opencode 2>/dev/null | head -1)
fi
if [ -z "$BIN" ] || [ ! -x "$BIN" ]; then
  echo "BUILD FAILED" | tee -a "$LOG"
  exit 1
fi
echo "binary: $BIN ($("$BIN" --version 2>/dev/null))" | tee -a "$LOG"

# 4. Тег + Release notes (ограничиваем диф от dev, не всю историю)
TAG="mem-v$(date +%Y%m%d-%H%M)-${SHA}"
LOG_RANGE="${LAST_TAG:+$LAST_TAG..}origin/dev..HEAD"
if [ -n "$LAST_TAG" ]; then LOG_RANGE="$LAST_TAG..HEAD"; fi
NOTES=$(mktemp)
{
  echo "OpenCode MEM — ранний билд для тестирования."
  echo ""
  echo "## Что нового (с ${LAST_TAG:-origin/dev})"
  git -C "$VERIFY" log "$LOG_RANGE" --oneline | sed 's/^/- /' | head -40
  echo ""
  echo "## Как тестировать"
  echo "Бинарь уже установлен как активный \`~/.opencode/bin/opencode\` (сток сохранён рядом как \`opencode.stock-backup\`)."
  echo ""
  echo "Флаги MEM (все default off):"
  echo '- \`OPENCODE_MEMORY_CONTEXT=1\` — компакт-маркеры старых tool-выводов'
  echo '- \`OPENCODE_MEMORY_FIRST_DELIVERY=1\` — маркер с первой доставки (B0, максимум экономии)'
  echo '- \`OPENCODE_MEMORY_INTENT=1\` (+\`_ACT=1\`) — трекер интентов'
  echo '- \`OPENCODE_MEMORY_CONTEXT_DEBUG=1\` — лог компактации'
  echo ""
  echo "Без флагов поведение ≈ сток."
} > "$NOTES"

# 5. Публикация релиза (бинарь как asset).
# --target обязателен: без него GitHub вешает тег на default-branch (dev), а не на
# выпущенный SHA — все теги mem-* до 2026-10-12 так и указывают на 0112a92c41 (issue #70).
cp "$BIN" /tmp/opencode-mem-bin
REL_OK=1
gh release create "$TAG" /tmp/opencode-mem-bin \
  --repo "$REPO" \
  --target "$FULL_SHA" \
  --title "MEM build $TAG" \
  --notes-file "$NOTES" >> "$LOG" 2>&1 \
  && { echo "release published: $TAG -> $FULL_SHA" | tee -a "$LOG"; REL_OK=0; } \
  || echo "RELEASE FAILED (см. лог)" | tee -a "$LOG"

# 6. Установить как активный opencode.
# ВАЖНО: не перезаписывать файл на месте (cp) — его мапят запущенные opencode-процессы,
# macOS даёт SIGKILL на exec изменённого маппинга. Копируем в НОВЫЙ файл и атомарно mv.
if [ ! -f "$BIN_DIR/opencode.stock-backup" ]; then
  cp -f "$BIN_DIR/opencode" "$BIN_DIR/opencode.stock-backup"
  echo "stock backed up -> opencode.stock-backup" | tee -a "$LOG"
fi
NEWBIN="$BIN_DIR/opencode.new.$$"
cp /tmp/opencode-mem-bin "$NEWBIN" && chmod +x "$NEWBIN"
mv -f "$NEWBIN" "$BIN_DIR/opencode"   # атомарная подмена inode
INSTALLED_VER=$("$BIN_DIR/opencode" --version 2>/dev/null | tail -1)
echo "installed: ${INSTALLED_VER:-'(занят запущенным процессом, подхватится при новом старте)'}" | tee -a "$LOG"

# 7. Гейт binary == SHA (issue #70): версия со вшитым git SHA обязана содержать
# собираемый SHA. Старый формат (без SHA) — предупреждение, не отказ: переход.
if printf '%s' "$INSTALLED_VER" | grep -Eq '[0-9a-f]{12}-[0-9]{12}$'; then
  case "$INSTALLED_VER" in
    *"$SHA"*) echo "installed SHA ok: $INSTALLED_VER содержит $SHA" | tee -a "$LOG" ;;
    *)
      echo "RELEASE FAILED: installed version '$INSTALLED_VER' не содержит $SHA (issue #70)" | tee -a "$LOG"
      exit 1
      ;;
  esac
else
  echo "installed version без git SHA (старый формат, PR #72 не смержен?) — гейт binary==SHA пропущен" | tee -a "$LOG"
fi

# Сохраняем релиз-ноты для цепочки (mem-chain читает их на шаге баг-репортера)
cp "$NOTES" "$HOME/.opencode/scripts/release-current.md" 2>/dev/null || true
rm -f "$NOTES" /tmp/opencode-mem-bin
if [ "$REL_OK" != "0" ]; then
  echo "RELEASE FAILED: GitHub Release/$TAG не опубликован (тега нет) — exit 1" | tee -a "$LOG"
  echo "LOG: $LOG"
  exit 1
fi
echo "=== RELEASE $STAMP DONE ===" | tee -a "$LOG"
echo "LOG: $LOG"
