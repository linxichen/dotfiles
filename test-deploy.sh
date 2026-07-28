#!/usr/bin/env bash
# Tests for deploy.sh, per the spec's testing section.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
PASS=0; FAIL=0

ok()   { echo "  PASS: $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected '$3', got '$2')"; fi; }

fresh() { rm -rf "$WORK"; mkdir -p "$WORK"; }
trap 'rm -rf "$WORK"' EXIT

echo "== 1. classification =="
fresh
OUT="$("$REPO/deploy.sh" --dry-run --all --target "$WORK" 2>&1)"
for p in aider herdr kickstart.nvim kitty oh-my-zsh regolith3 tmux wezterm vim; do
    if grep -qE "^  $p +" <<<"$OUT"; then ok "classified in: $p"; else bad "classified in: $p"; fi
done
for p in install skills noip ubuntu_profile_d emacs macprofile spacemacs i3 doom_emacs w3m docs; do
    if grep -qE "^  $p +" <<<"$OUT"; then bad "classified out: $p"; else ok "classified out: $p"; fi
done

echo "== 2. PATH check skips uninstalled tools =="
fresh
OUT="$("$REPO/deploy.sh" --dry-run --target "$WORK" 2>&1)"
if grep -qE "^  regolith3 +.*skipped \(i3 not on PATH\)" <<<"$OUT"; then
    ok "regolith3 skipped, i3 absent"
else bad "regolith3 should be skipped (got: $(grep regolith3 <<<"$OUT"))"; fi
if grep -qE "^  tmux +.*will link" <<<"$OUT"; then ok "tmux planned, tmux installed"
else bad "tmux should be planned"; fi

echo "== 3. conflict is reported, file untouched, exit non-zero =="
fresh
echo "PRECIOUS" > "$WORK/.wezterm.lua"
OUT="$("$REPO/deploy.sh" --dry-run --all --target "$WORK" 2>&1)"; RC=$?
grep -qE "^  wezterm +.*CONFLICT" <<<"$OUT" && ok "conflict reported" || bad "conflict not reported"
check "conflicting file unchanged" "$(cat "$WORK/.wezterm.lua")" "PRECIOUS"
check "exit non-zero on conflict" "$RC" "1"
grep -q "blocked by:" <<<"$OUT" && ok "blocking path named" || bad "blocking path not named"

echo "== 4. already-linked is a no-op, not an error =="
fresh
(cd "$REPO" && stow wezterm -t "$WORK")
OUT="$("$REPO/deploy.sh" --dry-run --all --target "$WORK" 2>&1)"; RC=$?
grep -qE "^  wezterm +.*already linked" <<<"$OUT" && ok "reports already linked" || bad "should report already linked"
check "exit zero" "$RC" "0"

echo "== 5. dry-run writes nothing =="
fresh
BEFORE="$(find "$WORK" | sort)"
"$REPO/deploy.sh" --dry-run --all --target "$WORK" >/dev/null 2>&1
check "target untouched" "$(find "$WORK" | sort)" "$BEFORE"

echo "== 6. explicit non-package is an error =="
fresh
OUT="$("$REPO/deploy.sh" --target "$WORK" emacs 2>&1)"; RC=$?
check "exit 2 for non-package" "$RC" "2"
grep -q "Not a stow package" <<<"$OUT" && ok "explains why" || bad "no explanation"

echo "== 7. vim converted correctly =="
fresh
(cd "$REPO" && stow vim -t "$WORK")
[ -L "$WORK/.vimrc" ] && ok ".vimrc linked" || bad ".vimrc not linked"
[ -L "$WORK/.gvimrc" ] && ok ".gvimrc linked" || bad ".gvimrc not linked"
for junk in dotvimrc_k40 dotvimrc_python Skim_SyncTex.sh dotvimrc_k40~; do
    [ -e "$WORK/$junk" ] && bad "$junk leaked into target" || ok "$junk ignored"
done

echo "== 8. kitty theme include resolves =="
fresh
(cd "$REPO" && stow kitty -t "$WORK")
[ -e "$WORK/.config/kitty/current-theme.conf" ] && ok "current-theme.conf beside kitty.conf" \
    || bad "current-theme.conf missing from .config/kitty"
[ -e "$WORK/current-theme.conf" ] && bad "current-theme.conf leaked to target root" \
    || ok "nothing leaked to target root"

echo "== 9. empty package is not mistaken for already-linked =="
fresh
OUT="$("$REPO/deploy.sh" --dry-run --all --target "$WORK" 2>&1)"
if [ -z "$(find "$REPO/kickstart.nvim" -type f -print -quit)" ]; then
    grep -qE "^  kickstart.nvim +.*empty" <<<"$OUT" && ok "empty package reported as empty" \
        || bad "empty package misreported: $(grep kickstart <<<"$OUT")"
    grep -q "submodule update --init" <<<"$OUT" && ok "names the submodule fix" \
        || bad "no submodule hint"
else
    echo "  SKIP: submodule is populated, cannot test empty case"
fi

echo
echo "passed: $PASS  failed: $FAIL"
rm -rf "$WORK"
[ "$FAIL" -eq 0 ]
