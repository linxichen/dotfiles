# Dotfiles Deployment Redesign

Date: 2026-07-27
Status: Approved

## Problem

The repository carries three generations of deployment tooling, two of which are
dead or actively wrong.

1. `install/install_{mac,redhat,ubuntu}.sh` — hardcoded `ln -sf ~/GitHub/dotfiles/...`
   symlinks. The repository now lives at `~/gits/dotfiles`, so every path is
   stale. Dead code.
2. `deploy.sh` (241 lines) — a `case` per package plus a generic `stow` fallback.
   The fallback stows any directory named on the command line, including
   directories that are not stow-shaped.
3. `interactive-deploy.sh` (939 lines) — a whiptail TUI wrapping OS detection,
   system package installation for three distributions, external repository
   bootstrap, nerd font installation, and roughly 150 lines of Claude provider
   switching that has nothing to do with dotfiles.

Three concrete defects follow from this:

- **Only 8 of 19 top-level directories are stow-shaped.** The rest use an older
  `dot`-prefix convention (`vim/dotvimrc`, `emacs/dotemacs`, `macprofile/dotprofile`).
  `interactive-deploy.sh` lists `vim` in its package menu and stows it, which
  produces `~/dotvimrc`, `~/dotgvimrc`, and `~/Skim_SyncTex.sh` — literal
  filenames in the home directory, not `~/.vimrc`. Verified with `stow -n -v vim`.
- **`kitty`'s theme include is broken.** `kitty/.config/kitty/kitty.conf:3` reads
  `include current-theme.conf`, resolved relative to `kitty.conf`, so the file
  must land at `~/.config/kitty/current-theme.conf`. The repository keeps it at
  `kitty/current-theme.conf`, so stow places it at `~/current-theme.conf` and the
  include does not resolve.
- **The README's headline install command cannot work.** It pipes
  `interactive-deploy.sh` from curl into bash, but the script resolves every path
  from `SCRIPT_DIR` and never clones the repository. Run from a pipe there is no
  repository to deploy from.

## Goals

- One entry point that auto-detects what is deployable on the current machine.
- Never clobber an existing file; surface conflicts for the user to resolve.
- Small enough to read in one sitting.

## Non-goals

- Installing system packages. The user installs tools via their own package
  manager; this script deploys configuration only.
- Supporting the `dot`-prefix convention long term. Only `vim` is converted;
  the remaining `dot*` directories stay as they are and are simply not
  auto-deployed.
- Nerd font installation, OS/distribution detection, and the Claude provider
  switcher. All removed.

## Design

### Single script: `deploy.sh`

Target roughly 180 lines. Replaces `interactive-deploy.sh` entirely.

#### `classify`

A directory is a stow package if it contains at least one top-level entry
beginning with `.` (excluding `.stow-local-ignore` itself).

This is a convention, not a list, so a new package becomes deployable purely by
being shaped correctly. A declarative manifest enumerating all packages was
considered and rejected: with 9 packages it would restate what the directory
layout already encodes, and would drift from it.

Classified in (8): `aider`, `herdr`, `kitty`, `oh-my-zsh`, `regolith3`,
`tmux`, `wezterm`, `vim` (after conversion).

Classified out (11): `install`, `skills`, `noip`, `ubuntu_profile_d`, `emacs`,
`macprofile`, `spacemacs`, `i3`, `doom_emacs`, `w3m`, `docs`.

#### `install_probe`

Answers whether the tool a package configures is actually present. Most packages
are named after a command on `PATH`; two are not:

| Package | Probe | Why |
|---|---|---|
| `regolith3` | `i3` on `PATH` | different name |
| `oh-my-zsh` | `~/.oh-my-zsh` directory | `zsh` is always present, even unused |

The `oh-my-zsh` case is a correctness issue, not a convenience: probing for `zsh`
succeeds on any macOS machine, so the package always planned as deployable and
would have overwritten an unrelated shell setup (starship) with an oh-my-zsh
`.zshrc` that sources a framework which is not installed. Only a pre-existing
`~/.zshrc` conflict prevented that.

The probe follows `--target`, so tests against a throwaway directory see the
package as not installed.

A package that fails its probe is skipped with the reason printed. As a side
effect `regolith3` self-skips on macOS.

`--all` bypasses this check.

#### `bootstrap` (before stow)

Fetches external sources. Runs only for packages about to be stowed, and only
when the dependency is missing. This must precede stow so there is something to
link.

| Package | Action |
|---|---|
| `tmux` | clone `tmux-plugins/tpm` into `~/.tmux/plugins/tpm` |
| `oh-my-zsh` | run the upstream oh-my-zsh installer |
| `vim` | clone `VundleVim/Vundle.vim` into `~/.vim/bundle` |

No `sudo`, no package manager invocation.

#### `finalize` (after stow)

Installs plugins. This must follow stow, because every plugin manager here reads
the config file stow has just linked into place.

| Package | Action |
|---|---|
| `tmux` | `tpm/bin/install_plugins` |
| `vim` | `vim +PluginInstall +qall` |

Failures are reported but do not abort the run: one unreachable plugin
repository must not leave the remaining packages unstowed.

Vundle drives a real Vim UI and hangs indefinitely without a controlling
terminal, so `:PluginInstall` is guarded on `[[ -t 0 && -t 1 ]]` and skipped
with instructions when stdin or stdout is not a tty.

#### `plan`

For each candidate package, run `stow -n` and classify the outcome as one of:

- `link` — will create new symlinks
- `already linked` — nothing to do, re-running is a no-op
- `CONFLICT` — an existing non-symlink target is in the way
- `skipped` — not stow-shaped, or its `install_probe` failed
- `empty` — stow-shaped but holds no files (see below)

Print as a table. This phase has no side effects.

#### `apply`

For each package planned as `link`: run `bootstrap`, then `stow`.

### Conflict policy

Report and skip. Never overwrite, and never pass `--adopt`. The script prints the
exact command to move the conflicting file aside so the user can decide.

This is the situation encountered when deploying `herdr`: a real
`~/.config/herdr/config.toml` written by herdr's own onboarding blocked the stow.
Silently adopting or overwriting it would have discarded live user settings.

### Interface

| Invocation | Behavior |
|---|---|
| `./deploy.sh` | plan all → print table → single y/n → apply |
| `./deploy.sh tmux herdr` | same flow, restricted to the named packages |
| `./deploy.sh --dry-run` | plan and exit |
| `./deploy.sh --all` | skip the `PATH` check |
| `./deploy.sh -h` | usage |

Naming a directory that is not stow-shaped is an error, not a silent skip — the
user asked for it explicitly.

## Repository changes

- `git mv vim/dotvimrc vim/.vimrc`
- `git mv vim/dotgvimrc vim/.gvimrc`
- Add `vim/.stow-local-ignore` covering `dotvimrc_k40`, `dotvimrc_k40~`,
  `dotvimrc_python`, `Skim_SyncTex.sh` — variants and helper scripts that must
  not land in `~`.
- `git mv kitty/current-theme.conf kitty/.config/kitty/current-theme.conf`
  (fixes the broken `include`).
- Delete `interactive-deploy.sh`, `install/install_mac.sh`,
  `install/install_redhat.sh`, `install/install_ubuntu.sh`, `deploy.sh.bak`.
- Keep `install/openvpn_ubuntu.sh`; it is unrelated to dotfiles deployment.
- `chmod +x deploy.sh`.
- Rewrite `README.org`: remove the curl one-liner, document `git clone`
  followed by `./deploy.sh`, and add a hand-deployment procedure for agents.
- Remove the `kickstart.nvim` package and its submodule; no longer used. This
  leaves `.gitmodules` empty, so delete it too.

## Testing

The plan phase is side-effect-free, which makes it directly testable. Against a
throwaway `--target` directory, assert:

1. All 8 expected packages classify in; all 11 expected directories classify out.
2. A package whose required command is absent is reported `skipped`, not `link`.
3. A seeded conflicting regular file produces `CONFLICT`, the file is unchanged
   after a full run, and the exit status is non-zero.
4. Re-running against an already-stowed package reports `already linked` and
   does not error.
5. `--dry-run` writes nothing to the target directory.

## Consequences

A fresh machine goes from clone to deployed configuration in one command, with
tools that are not installed skipped automatically. The cost is that system
package installation is no longer handled: the user installs `tmux`, `herdr`,
`nvim`, and so on via their own package manager first. This is deliberate — that
matrix across apt, pacman, and brew was the bulk of the 939 lines being removed.
