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

# The command that must exist for a package to be worth deploying. Identity for
# most packages; these are the ones that cannot be derived from the name.
required_command() {
    case "$1" in
        oh-my-zsh)      echo "zsh" ;;
        kickstart.nvim) echo "nvim" ;;
        regolith3)      echo "i3" ;;
        *)              echo "$1" ;;
    esac
}

# Clone external dependencies a package needs. Runs only for packages about to
# be stowed, and only when the dependency is missing.
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
        kickstart.nvim)
            if [[ ! -e "$SCRIPT_DIR/kickstart.nvim/.config/nvim/init.lua" ]]; then
                echo -e "${YELLOW}  fetching kickstart.nvim submodule...${NC}"
                git -C "$SCRIPT_DIR" submodule update --init kickstart.nvim/.config/nvim
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
    local to_deploy=() conflicts=() pkg cmd state
    for pkg in "${candidates[@]}"; do
        cmd="$(required_command "$pkg")"
        if [[ "$SKIP_PATH_CHECK" != true ]] && ! command -v "$cmd" &>/dev/null; then
            printf "  %-18s ${DIM}skipped (%s not on PATH)${NC}\n" "$pkg" "$cmd"
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
        echo -e "${GREEN}  deployed${NC}"
    done

    echo
    echo -e "${GREEN}Done.${NC}"
    if [[ " ${to_deploy[*]} " == *" tmux "* ]]; then
        echo "  tmux: press prefix+I inside tmux to install plugins"
    fi
    if [[ " ${to_deploy[*]} " == *" herdr "* ]]; then
        echo "  herdr: run 'herdr server reload-config' to apply without restarting"
    fi
    [[ ${#conflicts[@]} -gt 0 ]] && exit 1
    exit 0
}

main "$@"
