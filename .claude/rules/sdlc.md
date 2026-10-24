# AI-native SDLC

This project runs changes through the AI-native SDLC skills. A task lives in `sdlc/<slug>/` on branch `sdlc/<slug>` and moves through one Claude Code session per phase. A phase is finished when its artifact has `status: accepted`.

| Phase | Start with | Writes |
|---|---|---|
| intent | `/sdlc-intent <idea or ticket>` | `task.yaml`, `intent.md` |
| spec | `/sdlc-spec <slug>` | `spec.md` |
| plan | `/sdlc-plan <slug>` | `plan.md` |
| build | `/sdlc-build <slug>` | code, tests, `build.md` |
| test | `/sdlc-test <slug>` | tests, fixes, `test.md` |
| deploy | `/sdlc-deploy <slug>` | pull request, `deploy.md` |

`/sdlc-maintain` turns alerts, incidents and scan findings into new intents. `/sdlc-setup` holds one-time project setup. `/sdlc-status` shows every task. On a `sdlc/<slug>` branch, hooks block code edits until plan.md is accepted and block code commits until `$SDLC_VERIFY` passes.

## In every SDLC session

- **Files are the handoff.** Never rely on an earlier session. Read `sdlc/<slug>/task.yaml` and the artifacts before acting, and record decisions in the artifacts, not only in chat.
- **Questions go through the `grilling` skill.** Finish all research, tool calls and subagents first, then ask the whole round at once: short, simple questions, each with your recommended answer, worded so "yes" accepts it. Ask whenever something needs the user's decision, before or during implementation. If `grilling` is not among your available skills, stop and tell the user to install it: `npx skills add https://github.com/mattpocock/skills --skill grilling -a claude-code -g -y` (https://skills.sh/mattpocock/skills/grilling).
- **Check facts with context7.** Before relying on any library, framework, SDK, API, CLI or cloud-service detail you are not fully sure of, query the context7 MCP tools. If context7 is unavailable, say so and use the official documentation.
- **Browser checks use Playwright** (the Playwright MCP tools, or the project's Playwright test runner) unless the user asks for another tool, such as Claude in Chrome.
- **Never weaken a check to make it pass.** Fix the code, not the test.

## Approving a phase (task.yaml `gate_mode`)

Before any approval, run the `sdlc-gatekeeper` agent on the phase and resolve what it reports.

- `solo`: ask the user to approve, as a grilling question that includes the gatekeeper's verdict. Only after an explicit yes, set `status: accepted`, `approved_by: <git config user.name>` and `approved_at: <YYYY-MM-DD>`.
- `auto`: when the gatekeeper returns PASS, set `status: accepted` and `approved_by: sdlc-gatekeeper` yourself. Ask the user only about decisions that are theirs.
- `strict`: never set `accepted` on your own. Commit the artifact as `draft`, tell the user who must accept it (intent and spec: the product owner; plan: the engineer, or a tech lead for higher-risk changes), and print `.claude/sdlc-scripts/next.sh <slug>` for them to run once it is accepted; skip the rest of "Ending a phase". For deploy, the code owner's approving review is the acceptance: when `gh pr view <n> --json reviewDecision` shows `APPROVED`, set deploy.md to `accepted` with `approved_by: <reviewer>`.

## Ending a phase

1. Commit the phase's files: `sdlc(<slug>): <phase> <accepted|draft>`.
2. Weigh the next phase's model, effort and permission mode. The defaults are in `.claude/sdlc-scripts/next.sh --defaults`. Values the user set in task.yaml (`<phase>_model`, `<phase>_effort`, `<phase>_permission`) always win. If a default clearly does not fit this task (its size, risk or ambiguity), pass `--model`, `--effort` or `--permission` and give the reason in one line. Do not choose the `fable` model or `bypassPermissions` yourself; use them only when the user asks.
3. Run `.claude/sdlc-scripts/next.sh <slug> [flags]`. With `run_mode: manual` it prints a command: show it to the user unchanged, to run in a new terminal. With `run_mode: autonomous` it starts the next phase as a background session: tell the user they can follow it with `claude agents` and `claude attach <slug>-<phase>`, then stop.

## Context compaction

Claude cannot run `/compact` or `/clear`; long phases are compacted automatically. When summarizing, keep the task slug and phase, `gate_mode` and `run_mode`, open questions with their recommended answers, failing checks, and anything not yet written to the artifacts. After compaction, re-read task.yaml and the current artifact. A SessionStart hook re-injects the task state after compaction and on resume.
