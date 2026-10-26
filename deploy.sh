#!/usr/bin/env bash
#
# Deploy dotfiles with GNU Stow.
#
# Auto-detects which packages are deployable on this machine: a directory is a
# stow package if it holds at least one dot-prefixed entry, and it is deployed
# only if the tool it configures is on PATH. Existing files are never
# overwritten; conflicts are reported for you to resolve.
#
#   ./deploy.sh                 plan everything, confirm once, apply
#   ./deploy.sh tmux herdr      same, restricted to named packages
#   ./deploy.sh --dry-run       plan and exit
#   ./deploy.sh --all           deploy even if the tool is not installed
#
# Written for bash 3.2 (macOS system bash), so no associative arrays.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME"
DRY_RUN=false
SKIP_PATH_CHECK=false

if [[ -t 1 ]]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'; DIM=$'\033[2m'; NC=$'\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; DIM=''; NC=''
fi

usage() {
    cat <<EOF
Usage: $0 [options] [package...]

Options:
  --dry-run        Show the plan and exit without changing anything
  --all            Deploy packages even if their command is not on PATH
  --target DIR     Stow into DIR instead of \$HOME (for testing)
  -h, --help       Show this help

With no package names, every auto-detected package is planned.
EOF
}

# A directory is a stow package if it contains at least one dot-prefixed entry.
# .stow-local-ignore does not count: it configures stow rather than being
# deployed by it.
is_stow_package() {
    local dir="$1" entry
    [[ -d "$SCRIPT_DIR/$dir" ]] || return 1
    for entry in "$SCRIPT_DIR/$dir"/.*; do
        [[ -e "$entry" ]] || continue
        case "${entry##*/}" in
            .|..|.stow-local-ignore) continue ;;
            *) return 0 ;;
        esac
    done
    return 1
}

# How to tell whether the tool a package configures is actually in use here.
# Echoes "<kind> <value>", where kind is cmd or dir.
#
# Most packages are named after a command on PATH. oh-my-zsh is not: it is a
# shell framework installed as a directory, and probing for `zsh` would always
# succeed on macOS and happily deploy an oh-my-zsh .zshrc over a different
# shell setup (starship, say). Probe for the framework itself.
#
# orca is the Orca agent IDE, whose CLI is `orca` on macOS but `orca-ide` on
# Linux, where `orca` is the GNOME screen reader and would match on any desktop.
install_probe() {
    case "$1" in
        oh-my-zsh) echo "dir $TARGET/.oh-my-zsh" ;;
        regolith3) echo "cmd i3" ;;
        orca)
            if [[ "$(uname -s)" == Linux ]]; then echo "cmd orca-ide"
            else echo "cmd orca"; fi ;;
        *)         echo "cmd $1" ;;
    esac
}

is_installed() {
    local kind value
    read -r kind value <<<"$(install_probe "$1")"
    case "$kind" in
        cmd) command -v "$value" &>/dev/null ;;
        dir) [[ -d "$value" ]] ;;
    esac
}

# Human-readable reason a package was skipped.
install_hint() {
    local kind value tilde='~'
    read -r kind value <<<"$(install_probe "$1")"
    case "$kind" in
        cmd) echo "$value not on PATH" ;;
        dir) echo "${value/#$HOME/$tilde} not present" ;;
    esac
}

# Fetch external dependencies a package needs. Runs before stow, for packages
# about to be stowed, and only when the dependency is missing. Sources must
# exist before stow so it has something to link.
bootstrap() {
    case "$1" in
        tmux)
            local tpm="$TARGET/.tmux/plugins/tpm"
            if [[ ! -d "$tpm" ]]; then
                echo -e "${YELLOW}  bootstrapping tmux plugin manager...${NC}"
                mkdir -p "$TARGET/.tmux/plugins"
                git clone -q https://github.com/tmux-plugins/tpm "$tpm"
            fi
            ;;
        oh-my-zsh)
            if [[ ! -d "$TARGET/.oh-my-zsh" ]]; then
                echo -e "${YELLOW}  bootstrapping oh-my-zsh...${NC}"
                RUNZSH=no KEEP_ZSHRC=yes sh -c \
                    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
            fi
            ;;
        vim)
            local vundle="$TARGET/.vim/bundle/Vundle.vim"
            if [[ ! -d "$vundle" ]]; then
                echo -e "${YELLOW}  bootstrapping Vundle...${NC}"
                mkdir -p "$TARGET/.vim/bundle"
                git clone -q https://github.com/VundleVim/Vundle.vim "$vundle"
            fi
            ;;
    esac
}

# Install plugins. Runs after stow, because every plugin manager here reads the
# config file that stow has just linked into place.
#
# Failures are reported but do not abort the deployment: a single unreachable
# plugin repository should not leave the remaining packages unstowed.
finalize() {
    case "$1" in
        tmux)
            local installer="$TARGET/.tmux/plugins/tpm/bin/install_plugins"
            if [[ -x "$installer" ]]; then
                echo -e "${YELLOW}  installing tmux plugins...${NC}"
                "$installer" >/dev/null 2>&1 \
                    || echo -e "${YELLOW}  some tmux plugins failed; press prefix+I in tmux to retry${NC}"
            fi
            ;;
        vim)
            # Vundle's installer drives a real Vim UI, so it hangs forever
            # without a controlling terminal (piped stdin, CI, a non-tty
            # harness). Only run it when we genuinely have one.
            if ! command -v vim &>/dev/null; then
                :
            elif [[ -t 0 && -t 1 ]]; then
                echo -e "${YELLOW}  installing vim plugins (:PluginInstall)...${NC}"
                vim +PluginInstall +qall \
                    || echo -e "${YELLOW}  some vim plugins failed; run :PluginInstall in vim to retry${NC}"
            else
                echo -e "${YELLOW}  no tty; skipping :PluginInstall${NC}"
                echo -e "${DIM}    run 'vim +PluginInstall +qall' in a terminal${NC}"
            fi
            ;;
    esac
}

# True if the package holds at least one regular file to deploy. An
# uninitialized git submodule leaves an empty directory behind, which stow
# reports identically to an already-stowed package: no links to make. Without
# this check that state is misread as "already linked".
package_has_content() {
    [[ -n "$(find "$SCRIPT_DIR/$1" -type f ! -name .stow-local-ignore -print -quit)" ]]
}

# Echo one of: link | linked | conflict | empty
# Side-effect free: stow runs in simulation mode.
plan_package() {
    local pkg="$1" out status
    if ! package_has_content "$pkg"; then
        echo "empty"
        return
    fi

    set +e
    out="$(cd "$SCRIPT_DIR" && stow -n -v "$pkg" -t "$TARGET" 2>&1)"
    status=$?
    set -e

    if [[ $status -ne 0 ]]; then
        echo "conflict"
    elif grep -q "^LINK:" <<<"$out"; then
        echo "link"
    else
        echo "linked"
    fi
}

conflict_detail() {
    local pkg="$1"
    set +e
    (cd "$SCRIPT_DIR" && stow -n -v "$pkg" -t "$TARGET" 2>&1) \
        | grep "cannot stow" \
        | sed 's/.*over existing target /    blocked by: /; s/ since .*//'
    set -e
}

main() {
    local requested=() explicit=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) DRY_RUN=true; shift ;;
            --all)     SKIP_PATH_CHECK=true; shift ;;
            --target)  TARGET="$2"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            -*)        echo -e "${RED}Unknown option: $1${NC}" >&2; usage >&2; exit 2 ;;
            *)         requested+=("$1"); explicit=true; shift ;;
        esac
    done

    if ! command -v stow &>/dev/null; then
        echo -e "${RED}GNU Stow is not installed.${NC}" >&2
        echo "Install it with your package manager, e.g. 'brew install stow'." >&2
        exit 1
    fi

    # Naming a non-package explicitly is an error; auto-detection just skips.
    local candidates=()
    if [[ "$explicit" == true ]]; then
        local pkg
        for pkg in "${requested[@]}"; do
            pkg="${pkg%/}"
            if [[ ! -d "$SCRIPT_DIR/$pkg" ]]; then
                echo -e "${RED}No such package directory: $pkg${NC}" >&2
                exit 2
            fi
            if ! is_stow_package "$pkg"; then
                echo -e "${RED}Not a stow package: $pkg${NC}" >&2
                echo "It holds no dot-prefixed entries, so stow would copy its" >&2
                echo "filenames verbatim into $TARGET." >&2
                exit 2
            fi
            candidates+=("$pkg")
        done
    else
        local dir
        for dir in "$SCRIPT_DIR"/*/; do
            dir="${dir%/}"; dir="${dir##*/}"
            is_stow_package "$dir" && candidates+=("$dir")
        done
    fi

    if [[ ${#candidates[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No stow packages found.${NC}"
        exit 0
    fi

    # Plan
    echo -e "${BLUE}Planning deployment into $TARGET${NC}"
    echo
    local to_deploy=() conflicts=() pkg state
    for pkg in "${candidates[@]}"; do
        if [[ "$SKIP_PATH_CHECK" != true ]] && ! is_installed "$pkg"; then
            printf "  %-18s ${DIM}skipped (%s)${NC}\n" "$pkg" "$(install_hint "$pkg")"
            continue
        fi
        state="$(plan_package "$pkg")"
        case "$state" in
            link)
                printf "  %-18s ${GREEN}will link${NC}\n" "$pkg"
                to_deploy+=("$pkg")
                ;;
            linked)
                printf "  %-18s ${DIM}already linked${NC}\n" "$pkg"
                ;;
            empty)
                printf "  %-18s ${YELLOW}empty${NC}\n" "$pkg"
                if [[ -f "$SCRIPT_DIR/.gitmodules" ]] \
                   && grep -q "path = $pkg/" "$SCRIPT_DIR/.gitmodules"; then
                    echo -e "${DIM}    submodule not initialized; run:${NC}"
                    echo -e "${DIM}    git submodule update --init${NC}"
                fi
                ;;
            conflict)
                printf "  %-18s ${RED}CONFLICT${NC}\n" "$pkg"
                conflict_detail "$pkg"
                conflicts+=("$pkg")
                ;;
        esac
    done
    echo

    if [[ ${#conflicts[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Conflicting packages are skipped; nothing is overwritten.${NC}"
        echo "Move the blocking file aside, then re-run:"
        echo -e "${DIM}    mv <path> <path>.bak${NC}"
        echo
    fi

    if [[ ${#to_deploy[@]} -eq 0 ]]; then
        echo -e "${GREEN}Nothing to do.${NC}"
        [[ ${#conflicts[@]} -gt 0 ]] && exit 1
        exit 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${DIM}Dry run; no changes made.${NC}"
        [[ ${#conflicts[@]} -gt 0 ]] && exit 1
        exit 0
    fi

    printf "Deploy %d package(s)? [y/N] " "${#to_deploy[@]}"
    read -r reply
    if [[ ! "$reply" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    echo

    # Apply
    for pkg in "${to_deploy[@]}"; do
        echo -e "${BLUE}$pkg${NC}"
        bootstrap "$pkg"
        (cd "$SCRIPT_DIR" && stow "$pkg" -t "$TARGET")
        finalize "$pkg"
        echo -e "${GREEN}  deployed${NC}"
    done

    echo
    echo -e "${GREEN}Done.${NC}"
    if [[ " ${to_deploy[*]} " == *" tmux "* ]]; then
        echo "  tmux: run 'tmux source ~/.tmux.conf' in a running session to reload"
    fi
    if [[ " ${to_deploy[*]} " == *" herdr "* ]]; then
        echo "  herdr: run 'herdr server reload-config' to apply without restarting"
    fi
    [[ ${#conflicts[@]} -gt 0 ]] && exit 1
    exit 0
}

main "$@"
