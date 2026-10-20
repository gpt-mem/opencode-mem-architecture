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
#   BUN           — путь к bun (по умолчанию ищем подходящую версию)
#
# На stdout печатается путь к собранному бинарю.

set -euo pipefail

FORK_REPO="${FORK_REPO:-gpt-mem/opencode-mem}"
FORK_BRANCH="${FORK_BRANCH:-v2-base}"
DIR="${1:-fork}"

log() { echo "[build-fork-cli] $*"; }

# Сборка форка требует bun ^1.4.2 (packages/script/src/index.ts). В системном PATH
# на маке лежит 1.3.14 — от него сборка падает, поэтому ищем подходящий bun.
pick_bun() {
  if [ -n "${BUN:-}" ]; then
    echo "$BUN"
    return
  fi
  local cands=()
  [ -x "$HOME/.local/bun142/bun-darwin-aarch64/bun" ] && cands+=("$HOME/.local/bun142/bun-darwin-aarch64/bun")
  [ -x "$HOME/.local/bun142/bun-darwin-x64/bun" ] && cands+=("$HOME/.local/bun142/bun-darwin-x64/bun")
  [ -x "$HOME/.bun/bin/bun" ] && cands+=("$HOME/.bun/bin/bun")
  command -v bun >/dev/null 2>&1 && cands+=("$(command -v bun)")
  for c in "${cands[@]}"; do
    if "$c" --version 2>/dev/null | grep -qE '^1\.(4|[5-9])\.'; then
      echo "$c"
      return
    fi
  done
  command -v bun 2>/dev/null || echo ""
}

BUN_BIN="$(pick_bun)"
if [ -z "$BUN_BIN" ]; then
  log "bun не найден — поставь bun ^1.4.2"
  exit 1
fi
BUN_VERSION="$("$BUN_BIN" --version 2>/dev/null | tr -d 'v' || echo '?')"
if ! echo "$BUN_VERSION" | grep -qE '^1\.(4|[5-9])\.'; then
  log "нужен bun ^1.4.2, а доступен $BUN_VERSION ($BUN_BIN)"
  log "поставь: curl -fsSL https://bun.sh/install | bash -s \"bun-v1.4.2\""
  exit 1
fi
log "bun: $BUN_BIN ($BUN_VERSION)"
export BUN="$BUN_BIN"

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
  "$BUN_BIN" install --frozen-lockfile || "$BUN_BIN" install
fi

log "собираю CLI"
( cd packages/cli && "$BUN_BIN" run script/build.ts --single --skip-install --skip-web-ui )

BIN=$(find_bin || true)
if [ -z "$BIN" ]; then
  log "БИНАРЬ НЕ СОБРАН"
  exit 1
fi
chmod +x "$BIN"
log "бинарь: $BIN"
echo "$BIN"
