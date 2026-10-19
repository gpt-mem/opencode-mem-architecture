#!/bin/bash
set -uo pipefail
T=$(mktemp -d)
export MEM_BUILDS_DIR="$T/builds"
export MEM_INSTALL_MANIFEST="$T/forever-install.json"
export MEM_CSM_SETTINGS="$T/settings.json"
echo '{}' > "$MEM_CSM_SETTINGS"
mkbin() { printf '#!/bin/sh\nif [ "$1" = "--version" ]; then echo "opencode v0.0.0-fork-at-%s"; exit 0; fi\necho ran\n' "$2" > "$1"; chmod +x "$1"; }
mkbin "$T/a" aaaaaaaaaaaa; mkbin "$T/b" bbbbbbbbbbbb; mkbin "$T/c" cccccccccccc
S=~/opencode-mem-architecture/chain/mem-builds.sh
fail=0
chk() { if [ "$2" = "$3" ]; then echo "  ok: $1"; else echo "  FAIL: $1 — got [$2] want [$3]"; fail=1; fi; }
cur() { basename "$(dirname "$(readlink "$MEM_BUILDS_DIR/current")")"; }
prev() { basename "$(dirname "$(readlink "$MEM_BUILDS_DIR/previous")")"; }

echo "### install a,b,c"
"$S" install "$T/a" >/dev/null || exit 1
"$S" install "$T/b" >/dev/null || exit 1
"$S" install "$T/c" >/dev/null || exit 1
chk "current -> c" "$(cur)" "cccccccccccc"
chk "previous -> b" "$(prev)" "bbbbbbbbbbbb"
chk "queue oldest-first" "$(tr '\n' ' ' < "$MEM_BUILDS_DIR/order.txt")" "aaaaaaaaaaaa bbbbbbbbbbbb cccccccccccc "

echo "### rollback walks back: c -> b (previous a)"
"$S" rollback >/dev/null || exit 1
chk "current -> b" "$(cur)" "bbbbbbbbbbbb"
chk "previous -> a" "$(prev)" "aaaaaaaaaaaa"

echo "### rollback again: b -> a (previous none)"
"$S" rollback >/dev/null || exit 1
chk "current -> a" "$(cur)" "aaaaaaaaaaaa"
if [ -L "$MEM_BUILDS_DIR/previous" ]; then echo "  FAIL: previous still present"; fail=1; else echo "  ok: previous removed"; fi

echo "### shift to c"
"$S" shift cccccccccccc >/dev/null || exit 1
chk "current -> c" "$(cur)" "cccccccccccc"
chk "previous -> b (build before c in queue)" "$(prev)" "bbbbbbbbbbbb"

echo "### symlink targets are regular files"
for l in current previous; do
  p="$MEM_BUILDS_DIR/$l"
  [ -L "$p" ] && chk "$l isFile" "$(node -e "console.log(require('fs').statSync('$p').isFile())")" "true"
done

echo "### manifest"
chk "manifest revision" "$(node -p "require('$MEM_INSTALL_MANIFEST').revision")" "cccccccccccc"
chk "manifest repository" "$(node -p "require('$MEM_INSTALL_MANIFEST').repository")" "https://github.com/gpt-mem/opencode-mem"

echo "### settings"
B() { node -p "JSON.parse(require('$MEM_CSM_SETTINGS').opencode_builds).find(b=>b.id==='$1').$2"; }
chk "build count" "$(node -p "JSON.parse(require('$MEM_CSM_SETTINGS').opencode_builds).length")" "3"
chk "mem-latest binary" "$(B mem-latest binary)" "$MEM_BUILDS_DIR/current"
chk "mem-latest kind" "$(B mem-latest kind)" "stable"
chk "mem-latest autoFlag" "$(B mem-latest autoFlag)" "true"
chk "mem-previous binary" "$(B mem-previous binary)" "$MEM_BUILDS_DIR/previous"
chk "mem-previous kind" "$(B mem-previous kind)" "snapshot"
chk "upstream kind" "$(B upstream kind)" "upstream"

echo "### manual entries preserved"
node -e "const fs=require('fs');const p='$MEM_CSM_SETTINGS';const s=JSON.parse(fs.readFileSync(p));s.opencode_builds=JSON.stringify([...JSON.parse(s.opencode_builds),{id:'mine',name:'Mine',binary:'/x',kind:'snapshot'}]);fs.writeFileSync(p,JSON.stringify(s))"
"$S" shift >/dev/null 2>&1
chk "manual kept" "$(node -p "JSON.parse(require('$MEM_CSM_SETTINGS').opencode_builds).some(b=>b.id==='mine')")" "true"

echo "### list --json"
J() { node -p "const j=JSON.parse(require('child_process').execFileSync('$S',['list','--json'],{encoding:'utf8'}));$1"; }
chk "json current" "$(J 'j.current')" "cccccccccccc"
chk "json previous" "$(J 'j.previous')" "bbbbbbbbbbbb"
chk "json build count" "$(J 'j.builds.length')" "3"
chk "json oldest first" "$(J 'j.builds[0].sha')" "aaaaaaaaaaaa"
chk "json version from binary" "$(J 'j.builds[0].version')" "opencode v0.0.0-fork-at-aaaaaaaaaaaa"
chk "json installed flag" "$(J 'j.builds[0].installed')" "true"
chk "json queued flag" "$(J 'j.builds[0].queued')" "true"
chk "json drops uninstalled sha from disk list" "$(J 'j.builds.filter(b=>!b.installed).length')" "0"

echo "### error: install without sha"
printf '#!/bin/sh\necho "opencode v2.0.32"\n' > "$T/nosha"; chmod +x "$T/nosha"
out=$("$S" install "$T/nosha" 2>&1); rc=$?
chk "exit code" "$rc" "1"
echo "  message: $out"

echo "### error: rollback with a single-build queue"
rm -rf "$MEM_BUILDS_DIR"; mkdir -p "$MEM_BUILDS_DIR"
"$S" install "$T/a" >/dev/null
out=$("$S" rollback 2>&1); rc=$?
chk "exit code" "$rc" "1"
echo "  message: $out"
rm -rf "$T"
echo "=== RESULT: $([ $fail = 0 ] && echo ALL PASS || echo FAILURES) ==="
