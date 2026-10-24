#!/bin/sh
# PreToolUse hook (Bash, if "Bash(git commit*)"). On branch sdlc/<slug>, a commit
# while anything outside sdlc/ is changed needs an accepted plan.md and a passing
# $SDLC_VERIFY. Commits while only sdlc/ (the phase artifacts) is changed pass, and
# so do commits that change only test files, which may hold a deliberately failing
# test (test-first fixes).
# shellcheck source=../sdlc/lib.sh
. "$(dirname "$0")/../sdlc/lib.sh"

input=$(cat)
# git and $SDLC_VERIFY only ever run in this project's root, never in a directory
# taken from the command text, which could be an untrusted repository.
project=$(cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null && pwd -P) || exit 0

# True when an absolute path inside the project lies in another checkout (a nested
# repository or a git worktree, such as an sdlc-implementer's), found without git.
in_other_checkout() {
  _p=$1
  while [ "$_p" != "$project" ] && [ -n "$_p" ]; do
    [ -e "$_p/.git" ] && return 0
    _p=${_p%/*}
  done
  return 1
}

if command -v jq >/dev/null 2>&1; then
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
  # The hook's "if" filter also lets through commands it cannot parse, so check
  # for a git commit here (including "git -C dir commit" and "git -c k=v commit").
  printf '%s\n' "$cmd" |
    grep -Eq '(^|[^[:alnum:]_-])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+commit([[:space:]]|$)' ||
    exit 0
  # Skip the gate only when the commit clearly runs in another checkout: the single
  # "cd <dir>" or "git -C <dir>" in the command (or, with none, the session directory)
  # resolves outside this project or into a nested checkout. Anything less clear is gated.
  targets=$( {
    printf '%s\n' "$cmd" | grep -oE '(^|[;&|[:space:]])cd[[:space:]]+[^[:space:];&|]+' |
      sed -E 's/^[;&|[:space:]]*cd[[:space:]]+//'
    printf '%s\n' "$cmd" | grep -oE 'git([[:space:]]+-c[[:space:]]+[^[:space:]]+)*[[:space:]]+-C[[:space:]]+[^[:space:];&|]+' |
      sed -E 's/.*-C[[:space:]]+//'
  })
  t=
  if [ -z "$targets" ]; then
    t=$cwd
  elif [ "$(printf '%s\n' "$targets" | wc -l)" -eq 1 ]; then
    t=${targets#[\"\']}
    t=${t%[\"\']}
    case $t in /*) ;; *) t="${cwd:-$project}/$t" ;; esac
  fi
  if [ -n "$t" ] && abs=$(cd "$t" 2>/dev/null && pwd -P); then
    case $abs in
      "$project" | "$project"/*) in_other_checkout "$abs" && exit 0 ;;
      *) exit 0 ;;
    esac
  fi
fi

slug=$(sdlc_branch_slug "$project") || exit 0
root=$(sdlc_root "$project") || exit 0
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
