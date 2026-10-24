#!/bin/sh
# PreToolUse hook (Bash, if "Bash(git commit*)"). On branch sdlc/<slug>, a commit
# while anything outside sdlc/ is changed needs an accepted plan.md and a passing
# $SDLC_VERIFY. Commits while only sdlc/ (the phase artifacts) is changed pass, and
# so do commits that change only test files, which may hold a deliberately failing
# test (test-first fixes).
# shellcheck source=../sdlc/lib.sh
. "$(dirname "$0")/../sdlc/lib.sh"

input=$(cat)
cwd=
if command -v jq >/dev/null 2>&1; then
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
  # The hook's "if" filter also lets through commands it cannot parse, so check
  # for a git commit here (including "git -C dir commit" and "git -c k=v commit").
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
  printf '%s\n' "$cmd" |
    grep -Eq '(^|[^[:alnum:]_-])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+commit([[:space:]]|$)' ||
    exit 0
  # Judge the repository the commit targets: "git -C <dir>" or a leading "cd <dir> &&".
  target=$(printf '%s\n' "$cmd" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+([^[:space:];&|]+).*/\1/p' | head -n 1)
  [ -n "$target" ] ||
    target=$(printf '%s\n' "$cmd" | sed -nE 's/^[[:space:]]*cd[[:space:]]+([^[:space:];&|]+)[[:space:]]*&&.*/\1/p' | head -n 1)
  target=${target#[\"\']}
  target=${target%[\"\']}
  if [ -n "$target" ]; then
    case $target in
      /*) cwd=$target ;;
      *) cwd="${cwd:-.}/$target" ;;
    esac
  fi
fi
dir=${cwd:-.}
slug=$(sdlc_branch_slug "$dir") || exit 0
root=$(sdlc_root "$dir") || exit 0
cd "$root" || exit 0

# Staged, unstaged and untracked paths: the command may stage files before committing.
outside=$( {
  git diff --cached --name-only
  git diff --name-only
  git ls-files --others --exclude-standard
} | grep -v '^sdlc/' | sort -u)
[ -n "$outside" ] || exit 0
first=$(printf '%s\n' "$outside" | head -n 1)

status=$(sdlc_field "sdlc/$slug/plan.md" status)
if [ "$status" != accepted ]; then
  echo "SDLC commit gate: code is changed ($first, ...) but sdlc/$slug/plan.md is not accepted (status: ${status:-missing}). Finish the plan phase (/sdlc-plan $slug) first." >&2
  exit 2
fi

if printf '%s\n' "$outside" | while IFS= read -r f; do sdlc_is_test_path "$f" || exit 1; done; then
  exit 0
fi

if [ -z "${SDLC_VERIFY:-}" ]; then
  echo "SDLC commit gate: SDLC_VERIFY is empty. Run /sdlc-setup verify, or set \"env\": {\"SDLC_VERIFY\": \"<test command>\"} in .claude/settings.json (\"true\" opts out), then restart the session." >&2
  exit 2
fi

out=$(sh -c "$SDLC_VERIFY" 2>&1)
rc=$?
[ "$rc" -eq 0 ] && exit 0
{
  echo "SDLC commit gate: \`$SDLC_VERIFY\` failed (exit $rc). Fix the code, not the checks, then commit again. Last 40 lines:"
  printf '%s\n' "$out" | tail -n 40
} >&2
exit 2
