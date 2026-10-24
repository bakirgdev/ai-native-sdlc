#!/bin/sh
# Status of the AI-native SDLC tasks in this repository.
#   status.sh [slug]     task table, then details and the next command for one task
#   status.sh --line     one line for the checked-out task (for your status line script)
#   status.sh --context  SessionStart hook output with the checked-out task's state
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
# shellcheck source=lib.sh
. "$here/lib.sh"

arg=${1:-}
root=$(sdlc_root) || { echo "Not inside a git repository."; exit 0; }
cur=$(sdlc_branch_slug "$root") || cur=

slugs() {
  {
    git -C "$root" for-each-ref --format='%(refname:strip=3)' refs/heads/sdlc/
    for d in "$root"/sdlc/*/; do
      [ -f "${d}task.yaml" ] && basename "$d"
    done
  } 2>/dev/null | sort -u
}

# <slug> -> "phase status" for the first unfinished phase.
progress() {
  _p=$(sdlc_current_phase "$root" "$1")
  if [ "$_p" = "done" ]; then
    echo "done -"
    return
  fi
  _s=$(sdlc_task_field "$root" "$1" "$(sdlc_artifact "$_p")" status)
  echo "$_p ${_s:-not-started}"
}

field() { sdlc_task_field "$root" "$1" task.yaml "$2"; }

case $arg in
  --line)
    [ -n "$cur" ] || exit 0
    # shellcheck disable=SC2046
    set -- $(progress "$cur")
    echo "sdlc:$cur $1 ($2) $(field "$cur" gate_mode)/$(field "$cur" run_mode)"
    exit 0 ;;
  --context)
    [ -n "$cur" ] || exit 0
    # shellcheck disable=SC2046
    set -- $(progress "$cur")
    text="SDLC task $cur: phase $1 (artifact status $2), gate_mode $(field "$cur" gate_mode), run_mode $(field "$cur" run_mode). Files are the source of truth: re-read sdlc/$cur/task.yaml and the current phase's artifact before continuing."
    if command -v jq >/dev/null 2>&1; then
      jq -n --arg t "$text" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $t}}'
    else
      printf '%s\n' "$text"
    fi
    exit 0 ;;
esac

all=$(slugs)
if [ -z "$all" ]; then
  echo "No SDLC tasks yet. Start one with /sdlc-intent <idea>."
  exit 0
fi

printf '  %-32s %-7s %-12s %-10s %s\n' TASK PHASE STATUS GATE RUN
for s in $all; do
  # shellcheck disable=SC2046
  set -- $(progress "$s")
  mark=" "
  [ "$s" = "$cur" ] && mark="*"
  printf '%s %-32s %-7s %-12s %-10s %s\n' "$mark" "$s" "$1" "$2" "$(field "$s" gate_mode)" "$(field "$s" run_mode)"
done

sel=${arg:-$cur}
if [ -z "$sel" ] && [ "$(printf '%s\n' "$all" | wc -l)" -eq 1 ]; then
  sel=$all
fi
[ -n "$sel" ] || exit 0
if [ -z "$(sdlc_task_file "$root" "$sel" task.yaml)" ]; then
  echo
  echo "No task '$sel'."
  exit 0
fi

echo
echo "Task $sel: $(field "$sel" title)"
echo "  branch sdlc/$sel, pr $(field "$sel" pr)"
for p in $SDLC_PHASES; do
  a=$(sdlc_artifact "$p")
  st=$(sdlc_task_field "$root" "$sel" "$a" status)
  by=$(sdlc_task_field "$root" "$sel" "$a" approved_by)
  printf '  %-7s %-10s %-12s %s\n' "$p" "$a" "${st:--}" "${by:+approved by $by}"
done
echo
# next.sh exits non-zero while a phase is unfinished; status is informational and
# must exit 0, because a failing command aborts the skills that embed this output.
"$here/next.sh" "$sel" --print || true
