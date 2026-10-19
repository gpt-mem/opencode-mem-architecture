#!/usr/bin/env bash
set -euo pipefail
DEFAULT_OC="${OPENCODE_DEFAULT_BINARY:-}"
if [[ -z "$DEFAULT_OC" ]]; then
  if [[ -x "$HOME/.opencode/bin/opencode.stock-backup" ]]; then
    DEFAULT_OC="$HOME/.opencode/bin/opencode.stock-backup"
  else
    DEFAULT_OC="$(command -v opencode)"
  fi
fi
[[ -x "$DEFAULT_OC" ]] || { echo "default opencode binary not found: $DEFAULT_OC" >&2; exit 1; }
echo "default opencode: $DEFAULT_OC"
"$DEFAULT_OC" --version
"$DEFAULT_OC" run --title default-opencode-smoke "Reply with DEFAULT_OK" >/tmp/default-opencode-smoke.out 2>&1
cat /tmp/default-opencode-smoke.out
grep -q "DEFAULT_OK" /tmp/default-opencode-smoke.out
