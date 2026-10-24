#!/bin/sh
# PreToolUse hook used only by the sdlc-test-writer agent (agent frontmatter):
# edits are allowed to test files only.
# shellcheck source=../sdlc/lib.sh
. "$(dirname "$0")/../sdlc/lib.sh"

input=$(cat)
if ! command -v jq >/dev/null 2>&1; then
  echo "sdlc-test-writer guard: jq is required on PATH." >&2
  exit 2
fi
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -n "$file" ] || exit 0
case $file in
  ../* | */../* | */.. | ./* | */./*)
    echo "sdlc-test-writer guard: use a normalized path without ./ or ../ segments ($file)." >&2
    exit 2 ;;
esac
sdlc_is_test_path "$file" && exit 0
echo "sdlc-test-writer may edit test files only, and $file is not one (test/, tests/, __tests__/, spec/, e2e/, fixtures/, *.test.*, *.spec.*, *_test.*, test_*, *Test.*). Report the non-test change that is needed instead." >&2
exit 2
