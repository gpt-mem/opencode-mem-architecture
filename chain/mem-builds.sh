#!/bin/bash
# MEM-BUILDS: установленные сборки форка OpenCode MEM — раскладка на диске и
# переключение «последняя / предпоследняя».
#
# Раскладка:
#   ~/.opencode/builds/<sha12>/opencode   реальный бинарь сборки
#   ~/.opencode/builds/current            симлинк на последнюю установленную сборку
#   ~/.opencode/builds/previous           симлинк на предпоследнюю
#   ~/.opencode/builds/order.txt          очередь сборок, старая первой
#
# Симлинки указывают на ФАЙЛ, а не на каталог сборки: resolveOpencodeBuild()
# в Session Manager проверяет fs.statSync(binary).isFile() — симлинк на
# каталог дал бы «build unavailable».
#
# Очередь (order.txt) хранится от старой сборки к новой, а «current» — указатель
# на обслуживаемую сборку. Откат идёт строго назад по этой очереди:
#   очередь [a, b, c], current = c  →  rollback → current = b, previous = a
#   rollback → current = a, previous = (нет)
#
# Команды:
#   install <бинарь> [--sha <sha>] [--version <версия>]   поставить сборку и сдвинуть указатели
#   shift [<sha>]                                         сдвинуть указатели на сборку
#   list                                                  показать сборки, очередь и указатели
#   rollback                                              откатиться на предыдущую сборку
#   status                                                короткое состояние (для launchd/логов)
#
# Переменные окружения (для тестов и нестандартных путей):
#   MEM_BUILDS_DIR      каталог сборок        (по умолчанию ~/.opencode/builds)
#   MEM_INSTALL_MANIFEST  манифест установки  (по умолчанию ~/.opencode/forever-install.json)
#   MEM_CSM_SETTINGS    настройки Session Manager (по умолчанию ~/.config/claude-session-manager/settings.json)
#   MEM_FORK_REPO       репозиторий форка     (по умолчанию https://github.com/gpt-mem/opencode-mem)

set -euo pipefail

BUILDS_DIR="${MEM_BUILDS_DIR:-$HOME/.opencode/builds}"
MANIFEST="${MEM_INSTALL_MANIFEST:-$HOME/.opencode/forever-install.json}"
CSM_SETTINGS="${MEM_CSM_SETTINGS:-$HOME/.config/claude-session-manager/settings.json}"
FORK_REPO="${MEM_FORK_REPO:-https://github.com/gpt-mem/opencode-mem}"
STOCK_BIN="$HOME/.opencode/bin/opencode.stock-backup"
ORDER_FILE="$BUILDS_DIR/order.txt"

log() { printf '%s\n' "$*"; }
die() { printf 'mem-builds: %s\n' "$*" >&2; exit 1; }

# ── указатели ────────────────────────────────────────────────────────────────
# Замена симлинка атомарна: временный симлинк + rename(2) через mv -f.
# `mv -T` на macOS не существует (BSD mv), а `mv -f` уводит цель внутрь
# каталога, если тот существует — поэтому каталог на месте симлинка считаем
# ошибкой, а не поводом заменить его.

link_target() { readlink "$1" 2>/dev/null || true; }

set_link() {
  local name="$1"
  local target="$2"
  local tmp="$BUILDS_DIR/.$name.$$"
  [ ! -d "$BUILDS_DIR/$name" ] || die "$BUILDS_DIR/$name — каталог, а не симлинк; уберите его вручную"
  rm -f "$tmp"
  ln -s "$target" "$tmp"
  mv -f "$tmp" "$BUILDS_DIR/$name"
}

# ── очередь сборок ───────────────────────────────────────────────────────────

# Очередь: SHA по одному в строке, старая первая. В очереди только реально
# установленные сборки — иначе откат уводил бы на несуществующий бинарь.
order_read() {
  [ -f "$ORDER_FILE" ] || return 0
  local sha
  while read -r sha; do
    [ -n "$sha" ] || continue
    [ -x "$BUILDS_DIR/$sha/opencode" ] && printf '%s\n' "$sha"
  done < "$ORDER_FILE"
}

order_write() {
  mkdir -p "$BUILDS_DIR"
  local tmp="$ORDER_FILE.tmp.$$"
  printf '%s\n' "$@" > "$tmp"
  mv -f "$tmp" "$ORDER_FILE"
}

# SHA очереди, стоящий перед указанным (более старый).
order_before() {
  local target="$1" prev="" sha
  while read -r sha; do
    [ -n "$sha" ] || continue
    if [ "$sha" = "$target" ]; then printf '%s\n' "$prev"; return 0; fi
    prev="$sha"
  done < <(order_read)
  printf '\n'
}

# Сборки на диске, которых нет в очереди.
build_dirs() {
  [ -d "$BUILDS_DIR" ] || return 0
  find "$BUILDS_DIR" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -print 2>/dev/null | while read -r d; do
    [ -x "$d/opencode" ] && printf '%s\n' "$d"
  done
}

sha_of() {
  local binary="$1" version found
  version="$("$binary" --version 2>/dev/null | head -1 || true)"
  # «opencode v0.0.0-fork-at-<sha>» — SHA, вшитый при сборке.
  # grep без совпадений возвращает 1: под pipefail это оборвало бы скрипт
  # раньше, чем он успевает объяснить, что SHA не определился.
  found="$(printf '%s' "$version" | grep -oE 'fork-at-[0-9a-f]{7,40}' | head -1 | sed 's/^fork-at-//' || true)"
  printf '%s' "$found"
}

normalize_sha() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | grep -oE '[0-9a-f]{7,40}' | head -1 || true
}

# ── манифест установки ───────────────────────────────────────────────────────

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

write_manifest() {
  local revision="$1" version="$2" sha256="$3"
  mkdir -p "$(dirname "$MANIFEST")"
  local tmp="$MANIFEST.tmp.$$"
  cat > "$tmp" <<JSON
{
  "repository": "$FORK_REPO",
  "revision": "$revision",
  "version": "$version",
  "platform": "$(uname -s)-$(uname -m)",
  "sha256": "$sha256",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%S.000000+00:00)",
  "build_command": "OPENCODE_VERSION=\$OPENCODE_VERSION bun run script/build.ts --single --skip-install --skip-web-ui",
  "default_profile": "master",
  "default_model": "ladder/build"
}
JSON
  mv -f "$tmp" "$MANIFEST"
}

# ── регистрация в Session Manager ───────────────────────────────────────────
# opencode_builds — это JSON-строка в настройках Session Manager
# (~/.config/claude-session-manager/settings.json). Пишем её атомарно и
# сохраняем записи, добавленные вручную.

register_builds() {
  local current_commit="$1" previous_commit="$2" current_version="$3"
  [ -f "$CSM_SETTINGS" ] || return 0
  command -v node >/dev/null 2>&1 || return 0

  CSM_SETTINGS="$CSM_SETTINGS" \
  BUILDS_DIR="$BUILDS_DIR" \
  CURRENT_COMMIT="$current_commit" \
  PREVIOUS_COMMIT="$previous_commit" \
  CURRENT_VERSION="$current_version" \
  STOCK_BIN="$STOCK_BIN" \
  node -e '
const fs = require("fs");
const path = require("path");
const settingsPath = process.env.CSM_SETTINGS;
const buildsDir = process.env.BUILDS_DIR;
const stock = process.env.STOCK_BIN;

let settings = {};
try { settings = JSON.parse(fs.readFileSync(settingsPath, "utf8")); } catch {}

let existing = [];
try {
  const parsed = JSON.parse(settings.opencode_builds || "[]");
  if (Array.isArray(parsed)) existing = parsed;
} catch {}

const managed = new Set(["mem-latest", "mem-previous", "upstream"]);
const kept = existing.filter((b) => b && !managed.has(b.id));

const iso = new Date().toISOString();
const entries = [
  {
    id: "mem-latest",
    name: "OpenCode last",
    binary: path.join(buildsDir, "current"),
    kind: "stable",
    autoFlag: true,
    builtAt: iso,
    commit: process.env.CURRENT_COMMIT || undefined,
    description: process.env.CURRENT_VERSION ? `Last promoted fork build (${process.env.CURRENT_VERSION})` : "Last promoted fork build",
  },
  {
    id: "mem-previous",
    name: "OpenCode previous",
    binary: path.join(buildsDir, "previous"),
    kind: "snapshot",
    autoFlag: true,
    builtAt: iso,
    commit: process.env.PREVIOUS_COMMIT || undefined,
    description: "Previous promoted fork build",
  },
];

if (fs.existsSync(stock)) {
  entries.push({
    id: "upstream",
    name: "OpenCode (stock backup)",
    binary: stock,
    kind: "upstream",
    autoFlag: false,
    builtAt: iso,
    description: "Stock upstream binary kept next to the fork",
  });
}

settings.opencode_builds = JSON.stringify([...entries, ...kept]);
const tmp = settingsPath + ".tmp";
fs.writeFileSync(tmp, JSON.stringify(settings, null, 2));
fs.renameSync(tmp, settingsPath);
'
}

# Обновить указатели под текущую очередь: current — на current_sha,
# previous — на сборку перед ней.
apply_pointers() {
  local current_sha="$1"
  local previous_sha
  previous_sha="$(order_before "$current_sha")"
  set_link current "$BUILDS_DIR/$current_sha/opencode"
  if [ -n "$previous_sha" ]; then
    set_link previous "$BUILDS_DIR/$previous_sha/opencode"
  else
    rm -f "$BUILDS_DIR/previous"
  fi
  local version
  version="$("$BUILDS_DIR/$current_sha/opencode" --version 2>/dev/null | head -1 || true)"
  register_builds "$current_sha" "$previous_sha" "$version"
}

# ── команды ──────────────────────────────────────────────────────────────────

cmd_install() {
  local binary="" sha="" version=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --sha) sha="${2:-}"; shift 2 ;;
      --version) version="${2:-}"; shift 2 ;;
      --*) die "неизвестный флаг: $1" ;;
      *) [ -z "$binary" ] || die "ожидался один бинарь, получено: $1"; binary="$1"; shift ;;
    esac
  done
  [ -n "$binary" ] || die "нужен путь к бинарю"
  [ -f "$binary" ] || die "нет такого файла: $binary"
  [ -x "$binary" ] || die "файл не исполняемый: $binary"

  mkdir -p "$BUILDS_DIR"

  [ -n "$sha" ] || sha="$(sha_of "$binary")"
  sha="$(normalize_sha "$sha")"
  [ -n "$sha" ] || die "не удалось определить SHA сборки; передайте --sha <sha>"

  [ -n "$version" ] || version="$("$binary" --version 2>/dev/null | head -1 || true)"

  local target_dir="$BUILDS_DIR/$sha"
  mkdir -p "$target_dir"
  # Копируем во временный файл и переименовываем: бинарь может быть запущен.
  cp -f "$binary" "$target_dir/opencode.new"
  chmod +x "$target_dir/opencode.new"
  mv -f "$target_dir/opencode.new" "$target_dir/opencode"

  # Новая сборка — в конец очереди (она самая свежая).
  local queue=()
  local s
  while read -r s; do
    [ -n "$s" ] || continue
    [ "$s" = "$sha" ] && continue
    queue+=("$s")
  done < <(order_read)
  queue+=("$sha")
  order_write "${queue[@]}"

  apply_pointers "$sha"
  write_manifest "$sha" "$version" "$(sha256_of "$target_dir/opencode")"

  log "installed: $target_dir/opencode"
  log "  version: $version"
  log "  current  → $target_dir/opencode"
  local previous_target
  previous_target="$(link_target "$BUILDS_DIR/previous")"
  if [ -n "$previous_target" ]; then log "  previous → $previous_target"; fi
  log "  manifest: $MANIFEST"
}

# Сдвинуть указатели на указанную сборку (по умолчанию — на последнюю в очереди).
cmd_shift() {
  mkdir -p "$BUILDS_DIR"
  local sha="${1:-}"
  if [ -z "$sha" ]; then
    sha="$(order_read | tail -1)"
  fi
  [ -n "$sha" ] || die "нечего сдвигать: очередь сборок пуста"
  sha="$(normalize_sha "$sha")"
  [ -n "$sha" ] || die "неверный SHA: ${1:-}"
  [ -x "$BUILDS_DIR/$sha/opencode" ] || die "сборка не установлена: $sha"

  # Сборка становится самой свежей в очереди.
  local queue=()
  local s
  while read -r s; do
    [ -n "$s" ] || continue
    [ "$s" = "$sha" ] && continue
    queue+=("$s")
  done < <(order_read)
  queue+=("$sha")
  order_write "${queue[@]}"

  apply_pointers "$sha"
  log "current  → $BUILDS_DIR/$sha/opencode"
  local previous_target
  previous_target="$(link_target "$BUILDS_DIR/previous")"
  if [ -n "$previous_target" ]; then log "previous → $previous_target"; fi
}

# Откат: current ← предыдущая по очереди сборка, previous ← та, что перед ней.
cmd_rollback() {
  local current_sha
  current_sha="$(basename "$(dirname "$(link_target "$BUILDS_DIR/current")")")"
  [ -n "$current_sha" ] && [ "$current_sha" != "." ] || die "нет текущей сборки для отката"

  local previous_sha
  previous_sha="$(order_before "$current_sha")"
  [ -n "$previous_sha" ] || die "нет предыдущей сборки для отката"
  [ -x "$BUILDS_DIR/$previous_sha/opencode" ] || die "предыдущая сборка недоступна: $previous_sha"

  apply_pointers "$previous_sha"
  log "rolled back: current → $BUILDS_DIR/$previous_sha/opencode"
  local previous_target
  previous_target="$(link_target "$BUILDS_DIR/previous")"
  if [ -n "$previous_target" ]; then log "  previous → $previous_target"; fi
}

# Машиночитаемое состояние для Session Manager: сборки, очередь и указатели.
# Пишем через node (он есть везде, где есть Session Manager) — иначе пришлось
# бы вручную экранировать JSON в bash.
cmd_list_json() {
  local current_sha previous_sha
  current_sha="$(basename "$(dirname "$(link_target "$BUILDS_DIR/current")")")"
  [ "$current_sha" != "." ] || current_sha=""
  previous_sha="$(basename "$(dirname "$(link_target "$BUILDS_DIR/previous")")")"
  [ "$previous_sha" != "." ] || previous_sha=""

  BUILDS_DIR="$BUILDS_DIR" CURRENT_SHA="$current_sha" PREVIOUS_SHA="$previous_sha" \
  ORDER_FILE="$ORDER_FILE" node -e '
const fs = require("fs");
const path = require("path");
const dir = process.env.BUILDS_DIR;
const readVersion = (sha) => {
  try {
    const out = require("child_process").execFileSync(path.join(dir, sha, "opencode"), ["--version"], { encoding: "utf8", timeout: 5000 });
    return out.trim().split("\n")[0];
  } catch { return ""; }
};
let queue = [];
try {
  queue = fs.readFileSync(process.env.ORDER_FILE, "utf8").split("\n").map((s) => s.trim()).filter(Boolean);
} catch {}
const onDisk = [];
try {
  for (const name of fs.readdirSync(dir)) {
    if (name.startsWith(".")) continue;
    if (!fs.existsSync(path.join(dir, name, "opencode"))) continue;
    onDisk.push(name);
  }
} catch {}
const shas = [...new Set([...queue, ...onDisk])];
process.stdout.write(JSON.stringify({
  dir,
  current: process.env.CURRENT_SHA || null,
  previous: process.env.PREVIOUS_SHA || null,
  builds: shas.map((sha) => ({
    sha,
    version: readVersion(sha),
    installed: onDisk.includes(sha),
    queued: queue.includes(sha),
  })),
}, null, 2) + "\n");
'
}

cmd_list() {
  log "builds in $BUILDS_DIR:"
  local d
  while read -r d; do
    [ -n "$d" ] || continue
    log "  $(basename "$d")  $("$d/opencode" --version 2>/dev/null | head -1 || echo '(version unknown)')"
  done < <(build_dirs | while read -r x; do printf '%s\t%s\n' "$(stat -f %m "$x" 2>/dev/null || stat -c %Y "$x" 2>/dev/null || echo 0)" "$x"; done | sort -rn | cut -f2-)
  log "queue (oldest first):"
  local s
  while read -r s; do
    [ -n "$s" ] || continue
    log "  $s"
  done < <(order_read)
  log "current  → $(link_target "$BUILDS_DIR/current")"
  log "previous → $(link_target "$BUILDS_DIR/previous")"
}

cmd_status() {
  local current
  current="$(link_target "$BUILDS_DIR/current")"
  if [ -n "$current" ] && [ -x "$current" ]; then
    log "current: $current ($("$current" --version 2>/dev/null | head -1 || echo unknown))"
  else
    log "current: (none)"
  fi
  local previous
  previous="$(link_target "$BUILDS_DIR/previous")"
  if [ -n "$previous" ] && [ -x "$previous" ]; then
    log "previous: $previous ($("$previous" --version 2>/dev/null | head -1 || echo unknown))"
  else
    log "previous: (none)"
  fi
}

case "${1:-}" in
  install) shift; cmd_install "$@" ;;
  shift) shift; cmd_shift "$@" ;;
  list)
    shift
    case "${1:-}" in
      --json) cmd_list_json ;;
      *) cmd_list "$@" ;;
    esac
    ;;
  rollback) shift; cmd_rollback "$@" ;;
  status) shift; cmd_status "$@" ;;
  *)
    cat >&2 <<'USAGE'
Usage: mem-builds.sh <command>

  install <binary> [--sha <sha>] [--version <version>]  install a build and shift current/previous
  shift [<sha>]                                         point current/previous at a build
  list [--json]                                        list builds, queue and pointers
  rollback                                             roll current back to previous
  status                                               short status
USAGE
    exit 2
    ;;
esac
