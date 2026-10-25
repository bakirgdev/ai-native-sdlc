# Review instructions

This repository is Claude Code configuration: skills, agents and rules in Markdown, and hooks and scripts in POSIX shell. It has no build or test suite, so review is most of what checks it.

## What failure means here

- A hook or gate fails open: an error, a missing tool or an unparsed input lets a commit or edit through that should be blocked. Important.
- A script uses GNU-only or bash-only behavior (`sed -i` without a suffix, `readlink -f`, arrays, `[[`), or breaks on paths with spaces. Important.
- A skill, agent, rule or the README states Claude Code behavior, a CLI flag or a settings key that does not exist or is not checked against the docs. Important: the docs lie.
- Two files disagree: a step, key, status value or agent name in one is missing or different in another (README tables, `sdlc-artifacts.md`, the skills, the gatekeeper). Important.
- Instructions that could be read two ways by a model running the phase. Nit, or Important when it changes what gets approved or merged.
- Wording, tone and formatting are Nit at most.

## Nits

Report at most 5.

## Do not report

- `LICENSE`.
- Style in Markdown that renders correctly.

## Evidence

Every behavior claim cites `file:line`. A claim about Claude Code behavior names the documentation page it relies on. Start the summary with a count, and say "nothing to fix" when there is nothing.

## Always check

- Hooks exit 2 with a reason on every blocked path, and never block on their own internal errors silently.
- Every git call in a hook that reads the working tree (`diff`, `status`, `ls-files`) keeps `-c core.fsmonitor=false`.
- A change to a phase's steps is matched in the gatekeeper's check for that phase and in the README.

## Always human

- `.claude/hooks/`
- `.claude/settings.json`
