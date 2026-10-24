#!/bin/bash
# PRUNE: уборка старых ворктри из ~/.worktrees.
#
# Зачем: корень диска забивается ворктрями (36 GiB / 27 ворктри в цикле
# 20261022-0602), и сборка форка падает при свободном месте < 5 GiB
# (run-build.sh → "BUILD SKIPPED: мало места на диске"). Уборка должна быть
# шагом цепочки ДО сборки, а не разовой ручной акцией.
#
# Безопасность (ни одно правило не отключается):
#   1. только форк opencode-mem (origin-remote содержит $PRUNE_REPO_PATTERN);
#   2. только настоящие git-ворктри/клоны форка;
#   3. HEAD старше $MAX_AGE_DAYS дней (по дате коммита, а не по mtime каталога);
#   4. дерево чистое: `git status --porcelain` пуст (нет ни правок, ни untracked);
#   5. HEAD запушен: коммит содержится хотя бы в одной remote-ветке репозитория
#      (`git branch -r --contains HEAD`) — иначе работа уехала бы в никуда;
# 5b. НЕТ ни одного локального коммита, отсутствующего в remotes
#      (`git log --branches --not --remotes`) — иначе вместе с ворктри потерялась
#      бы непушнутая ветка (проверка только HEAD её не ловит);
#   6. «осиротевшие» ворктри (битый .git → репозиторий переехал) удаляются
#      только после того, как их файловый набор сохранён коммитом в origin
#      (preserve-orphan.sh);
#   7. удаление идёт через `git worktree remove`, чтобы репозиторий не остался
#      с битым указателем на несуществующий каталог.
#
# Режимы:
#   --dry-run   только показать, что будет удалено (по умолчанию — безопасно)
#   --apply     удалять
#   --max-age=N дней (по умолчанию 7)
#
# Артефакты:
#   ~/.opencode/scripts/prune-logs/prune-<STAMP>.log
#   строка в ~/.opencode/scripts/chain-state.jsonl

set -u
WORKTREES_DIR="${PRUNE_DIR:-$HOME/.local/share/opencode/worktree}"
MAX_AGE_DAYS="${PRUNE_MAX_AGE_DAYS:-7}"
REPO_PATTERN="${PRUNE_REPO_PATTERN:-opencode-mem}"
DRY_RUN=1
LOG_DIR="$HOME/.opencode/scripts/prune-logs"
STAMP=$(date +%Y%m%d-%H%M%S)
LOG="$LOG_DIR/prune-$STAMP.log"
mkdir -p "$LOG_DIR"

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --apply) DRY_RUN=0 ;;
    --max-age=*) MAX_AGE_DAYS="${arg#*=}" ;;
  esac
done

log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

log "PRUNE start dir=$WORKTREES_DIR max_age_days=$MAX_AGE_DAYS repo_pattern=$REPO_PATTERN mode=$([ "$DRY_RUN" = "1" ] && echo dry-run || echo apply)"
[ -d "$WORKTREES_DIR" ] || { log "no worktrees dir"; exit 0; }

NOW=$(date +%s)
REMOVED=0
SKIPPED=0
FREED_KB=0

# кандидаты: каталоги с .git (файл = linked worktree, каталог = клон)
CANDIDATES=$(find "$WORKTREES_DIR" -maxdepth 3 -name .git \( -type f -o -type d \) 2>/dev/null | sed 's|/\.git$||' | sort -u)

for dir in $CANDIDATES; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")

  # 1. только форк: origin-remote должен указывать на репозиторий форка
  origin=""
  if [ -d "$dir/.git" ]; then
    origin=$(git -C "$dir" remote get-url origin 2>/dev/null)
  else
    common=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null)
    if [ -n "$common" ]; then
      case "$common" in
        /*) repo=$(dirname "$common") ;;
        *) repo=$(cd "$dir" && cd "$common/.." && pwd) ;;
      esac
      origin=$(git -C "$repo" remote get-url origin 2>/dev/null)
    fi
  fi
  case "$origin" in
    *"$REPO_PATTERN"*) : ;;
    *)
      log "SKIP $name: not a $REPO_PATTERN worktree (origin=${origin:-none})"
      SKIPPED=$((SKIPPED + 1))
      continue
      ;;
  esac

  size_kb=$(du -sk "$dir" 2>/dev/null | awk '{print $1}')
  [ -n "$size_kb" ] || size_kb=0

  # 6. осиротевший ворктри: .git указывает в никуда
  if [ -f "$dir/.git" ] && ! git -C "$dir" rev-parse --git-common-dir >/dev/null 2>&1; then
    if [ "$DRY_RUN" = "1" ]; then
      log "WOULD PRESERVE+REMOVE $name (${size_kb} KiB, orphaned gitdir)"
      continue
    fi
    if bash "$HOME/.opencode/scripts/preserve-orphan.sh" "$dir" origin/main \
        "groom/$(date +%Y-%m-%d)-orphan-$name" >> "$LOG" 2>&1; then
      rm -rf "$dir"
      log "REMOVED $name (${size_kb} KiB, orphaned gitdir, preserved on origin)"
      REMOVED=$((REMOVED + 1))
      FREED_KB=$((FREED_KB + size_kb))
    else
      log "FAILED $name: preserve failed (kept)"
      SKIPPED=$((SKIPPED + 1))
    fi
    continue
  fi

  # 3. возраст HEAD
  head_ts=$(git -C "$dir" log -1 --format=%ct 2>/dev/null)
  if [ -z "$head_ts" ]; then
    log "SKIP $name: no HEAD commit"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  age_days=$(( (NOW - head_ts) / 86400 ))
  if [ "$age_days" -lt "$MAX_AGE_DAYS" ]; then
    log "SKIP $name: HEAD is $age_days day(s) old (< $MAX_AGE_DAYS)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  # 4. чистое дерево
  dirty=$(git -C "$dir" status --porcelain 2>/dev/null | head -5)
  if [ -n "$dirty" ]; then
    log "SKIP $name: dirty tree"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  # 5. HEAD запушен
  pushed=$(git -C "$dir" branch -r --contains HEAD 2>/dev/null | head -3 | tr '\n' ' ')
  if [ -z "$pushed" ]; then
    log "SKIP $name: HEAD is not contained in any remote branch"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  # 5b. нет непушнутых локальных коммитов (страховка от потери ветки)
  unpushed=$(git -C "$dir" log --branches --not --remotes --oneline 2>/dev/null | head -3)
  if [ -n "$unpushed" ]; then
    log "SKIP $name: unpushed local commits: $(echo "$unpushed" | tr '\n' ' ')"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  if [ "$DRY_RUN" = "1" ]; then
    log "WOULD REMOVE $name (${size_kb} KiB, ${age_days}d, remote: $pushed)"
    continue
  fi
  common=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null)
  case "$common" in
    /*) repo=$(dirname "$common") ;;
    *) repo=$(cd "$dir" && cd "$common/.." && pwd) ;;
  esac
  if git -C "$repo" worktree remove --force "$dir" >>"$LOG" 2>&1; then
    log "REMOVED $name (${size_kb} KiB, ${age_days}d, remote: $pushed)"
    REMOVED=$((REMOVED + 1))
    FREED_KB=$((FREED_KB + size_kb))
  else
    log "FAILED $name: git worktree remove failed (kept)"
    SKIPPED=$((SKIPPED + 1))
  fi
done

# осиротевшие указатели (каталога уже нет) чистим в каждом репозитории
if [ "$DRY_RUN" = "0" ]; then
  for repo in "$WORKTREES_DIR"/*; do
    [ -d "$repo" ] || continue
    git -C "$repo" worktree prune >>"$LOG" 2>&1 || true
  done
fi

log "PRUNE done removed=$REMOVED skipped=$SKIPPED freed_kb=$FREED_KB"
# Детальная запись: step_script в run-mem-chain.sh пишет свой «prune» (статус шага),
# здесь — метрики (что и сколько удалено). Ключ отличается, чтобы не сливать два вида.
printf '{"ts":"%s","step":"prune-detail","removed":%d,"skipped":%d,"freed_kb":%d,"max_age_days":%d,"mode":"%s"}\n' \
  "$(date -Iseconds)" "$REMOVED" "$SKIPPED" "$FREED_KB" "$MAX_AGE_DAYS" \
  "$([ "$DRY_RUN" = "1" ] && echo dry-run || echo apply)" >> "$HOME/.opencode/scripts/chain-state.jsonl"
exit 0
