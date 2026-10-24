#!/bin/sh
# PreToolUse hook used only by the sdlc-test-writer agent (agent frontmatter):
# edits are allowed to test files only.
# shellcheck source=../sdlc-scripts/lib.sh
. "$(dirname "$0")/../sdlc-scripts/lib.sh"

input=$(cat)
if ! command -v jq >/dev/null 2>&1; then
  echo "sdlc-test-writer guard: jq is required on PATH." >&2
  exit 2
fi
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -n "$file" ] || exit 0
if sdlc_unnormalized_path "$file"; then
  echo "sdlc-test-writer guard: use a normalized path without ./ or ../ segments ($file)." >&2
  exit 2
fi
dir=$(printf '%s' "$input" | jq -r '.cwd // empty')
dir=${dir:-.}
root=$(sdlc_root "$dir")
file=$(sdlc_resolve_path "$file" "$dir")
# Match test patterns on the path inside the repository, after symlinks are resolved.
case $file in
  "$root"/?*) sdlc_is_test_path "${file#"$root"/}" && exit 0 ;;
esac
echo "sdlc-test-writer may edit test files only, and $file is not one (test/, tests/, __tests__/, spec/, e2e/, fixtures/, *.test.*, *.spec.*, *_test.*, test_*, *Test.*). Report the non-test change that is needed instead." >&2
exit 2
