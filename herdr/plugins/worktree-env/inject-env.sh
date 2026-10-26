#!/usr/bin/env bash
# Run `op inject -i .env.tpl -o .env` at the root of a worktree herdr just
# created or opened. Needs the 1Password CLI connected to the desktop app: the
# herdr server has no TTY, so an `op signin` session is not available here.
set -euo pipefail
OP=$(command -v op || echo /usr/local/bin/op)   # the herdr server's PATH may be minimal
JQ=$(command -v jq || echo /usr/bin/jq)

path=$(printf '%s' "${HERDR_PLUGIN_EVENT_JSON:-}" |
  "$JQ" -r '[.. | objects | select(has("path") and has("is_linked_worktree")) | .path][0] // empty')

[ -n "$path" ] || exit 0              # payload without a worktree path: nothing to do
[ -f "$path/.env.tpl" ] || exit 0     # repo has no template
[ -e "$path/.env" ] && exit 0         # never overwrite an existing .env

cd "$path"
"$OP" inject -i .env.tpl -o .env
chmod 600 .env
echo "worktree-env: wrote $path/.env"
