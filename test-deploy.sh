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
for p in aider herdr kitty oh-my-zsh orca regolith3 tmux wezterm vim; do
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

# oh-my-zsh must probe for the framework directory, not for `zsh`. zsh is always
# present on macOS, so a command probe would deploy an oh-my-zsh .zshrc over a
# starship setup.
# The probe follows --target, so under a throwaway target .oh-my-zsh is absent
# and the package must be skipped even though zsh itself is on PATH.
grep -qE "^  oh-my-zsh +.*skipped \(.*\.oh-my-zsh not present\)" <<<"$OUT" \
    && ok "oh-my-zsh probes the framework dir, not zsh" \
    || bad "oh-my-zsh should be skipped (got: $(grep oh-my-zsh <<<"$OUT"))"
command -v zsh >/dev/null && ok "…and zsh IS on PATH, so a command probe would have wrongly deployed it" \
    || echo "  SKIP: zsh not on PATH, cannot demonstrate the false positive"

# On Linux `orca` is the GNOME screen reader; the Orca IDE's CLI is `orca-ide`.
# Fake a Linux host with only the screen reader installed: orca must be skipped.
SHIM="$(mktemp -d)"
printf '#!/bin/sh\necho Linux\n' > "$SHIM/uname"
printf '#!/bin/sh\nexit 0\n' > "$SHIM/orca"
chmod +x "$SHIM/uname" "$SHIM/orca"
OUT="$(PATH="$SHIM:$PATH" "$REPO/deploy.sh" --dry-run --target "$WORK" orca 2>&1)"
rm -rf "$SHIM"
grep -qE "^  orca +.*skipped \(orca-ide not on PATH\)" <<<"$OUT" \
    && ok "orca on Linux probes orca-ide, not the screen reader" \
    || bad "orca should be skipped on Linux without orca-ide (got: $(grep orca <<<"$OUT"))"

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
# An empty package (an uninitialized submodule, say) makes stow report "nothing
# to link", which is indistinguishable from "already stowed" unless content is
# checked explicitly. Build a synthetic empty package to keep that covered.
fresh
EMPTY_PKG="$REPO/zz_test_empty_pkg"
rm -rf "$EMPTY_PKG"; mkdir -p "$EMPTY_PKG/.config"
OUT="$("$REPO/deploy.sh" --dry-run --all --target "$WORK" 2>&1)"
rm -rf "$EMPTY_PKG"
grep -qE "^  zz_test_empty_pkg +.*empty" <<<"$OUT" && ok "empty package reported as empty" \
    || bad "empty package misreported: $(grep zz_test <<<"$OUT" || echo 'not listed at all')"
grep -qE "^  zz_test_empty_pkg +.*already linked" <<<"$OUT" \
    && bad "empty package misreported as already linked" || ok "not called already-linked"

echo
echo "passed: $PASS  failed: $FAIL"
rm -rf "$WORK"
[ "$FAIL" -eq 0 ]
