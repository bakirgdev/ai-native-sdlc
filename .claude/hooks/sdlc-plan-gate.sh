#!/bin/sh
# PreToolUse hook (Edit|Write|MultiEdit|NotebookEdit). On branch sdlc/<slug>, blocks
# edits to repository files outside sdlc/ until sdlc/<slug>/plan.md is accepted.
# Files outside the repository (for example plan-mode drafts in ~/.claude/plans) pass.
# shellcheck source=../sdlc/lib.sh
. "$(dirname "$0")/../sdlc/lib.sh"

input=$(cat)
if ! command -v jq >/dev/null 2>&1; then
  sdlc_branch_slug >/dev/null || exit 0
  echo "SDLC plan gate: jq is required on PATH to check edits on this sdlc/ branch." >&2
  exit 2
fi

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -n "$file" ] || exit 0
dir=${cwd:-.}
slug=$(sdlc_branch_slug "$dir") || exit 0
root=$(sdlc_root "$dir") || exit 0

if sdlc_unnormalized_path "$file"; then
  echo "SDLC plan gate: use a normalized path without ./ or ../ segments ($file)." >&2
  exit 2
fi
file=$(sdlc_resolve_path "$file" "$dir")
case $file in
  "$root"/sdlc/*) exit 0 ;;
  "$root"/*) ;;
  *) exit 0 ;;
esac

status=$(sdlc_field "$root/sdlc/$slug/plan.md" status)
[ "$status" = accepted ] && exit 0
echo "SDLC plan gate: ${file#"$root"/} is outside sdlc/ and sdlc/$slug/plan.md is not accepted (status: ${status:-missing}). Finish the plan phase (/sdlc-plan $slug) before changing code." >&2
exit 2
