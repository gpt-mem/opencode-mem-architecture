#!/bin/bash
# Сборка нашего форка (opencode CLI) под текущую ОС/архитектуру.
# Используется в .github/workflows/upstream-watch.yml и локально.
#
#   chain/build-fork-cli.sh [каталог]
#
# Переменные окружения:
#   FORK_REPO     — репозиторий форка (по умолчанию gpt-mem/opencode-mem)
#   FORK_BRANCH   — линия форка (по умолчанию v2-base)
#   SKIP_INSTALL  — 1: не ставить зависимости (уже стоят)
#
# На stdout печатается путь к собранному бинарю.

set -euo pipefail

FORK_REPO="${FORK_REPO:-gpt-mem/opencode-mem}"
FORK_BRANCH="${FORK_BRANCH:-v2-base}"
DIR="${1:-fork}"

log() { echo "[build-fork-cli] $*"; }

find_bin() {
  find "$DIR/packages/cli/dist" -name opencode -type f 2>/dev/null | head -1
}

if [ ! -d "$DIR/.git" ]; then
  log "клонирую $FORK_REPO@$FORK_BRANCH → $DIR"
  git clone --depth 1 --branch "$FORK_BRANCH" "https://github.com/$FORK_REPO.git" "$DIR"
fi

BIN=$(find_bin || true)
if [ -n "$BIN" ]; then
  chmod +x "$BIN" 2>/dev/null || true
  log "бинарь уже собран: $BIN"
  echo "$BIN"
  exit 0
fi

cd "$DIR"
if [ "${SKIP_INSTALL:-0}" != "1" ]; then
  log "ставлю зависимости"
  bun install --frozen-lockfile || bun install
fi

log "собираю CLI"
( cd packages/cli && bun run script/build.ts --single --skip-install --skip-web-ui )

BIN=$(find_bin || true)
if [ -z "$BIN" ]; then
  log "БИНАРЬ НЕ СОБРАН"
  exit 1
fi
chmod +x "$BIN"
log "бинарь: $BIN"
echo "$BIN"
