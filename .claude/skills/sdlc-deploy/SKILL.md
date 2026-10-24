---
name: sdlc-deploy
description: Sixth SDLC phase. Ships a tested task. Pushes the branch, opens a pull request linked to the task's artifacts, reviews it in a fresh subagent, works through CI failures and review comments until only approval remains, and merges when the task allows it. Use after /sdlc-test.
argument-hint: "<slug>"
disable-model-invocation: true
allowed-tools:
  - Bash(.claude/sdlc-scripts/status.sh)
  - Bash(.claude/sdlc-scripts/status.sh *)
---

# Deploy

The agent takes the change up to the merge gate. Who passes that gate depends on the task's settings.

## Task state

!`.claude/sdlc-scripts/status.sh $ARGUMENTS`

## Steps

1. Pick the task: the slug from the input, else the current `sdlc/<slug>` branch, else ask which one from the table above. Switch to its branch. test.md must be `accepted`.
2. Push and open the pull request. With `pr: ask` in task.yaml, ask once before pushing and opening; with `pr: auto`, go ahead. Follow the repository's PR conventions. In the body, link every file in `sdlc/<slug>/`, list the R# coverage from test.md, and paste the final verify output. In workspace mode, open one PR per repository in `repos:`, each linking the others; when the task files are not committed, paste the spec's requirements into each body instead of linking them.
3. Review it in a fresh subagent that did not write the code: `pr-review-toolkit:code-reviewer` when installed, otherwise a general-purpose subagent. Give it the diff, `REVIEW.md` if one exists, CLAUDE.md, spec.md and plan.md, and ask for three passes (bugs, security, compliance with the spec's R#), with each finding tagged Important or Nit. Fix the Important findings test-first, as in `/sdlc-test`. Push, and reply on the PR with what changed.
4. Work the PR until only approval remains. Watch `gh pr checks <n>` and the unresolved comments (`gh pr view <n> --comments`). Fix each, push, and reply in each thread. If the same check fails the same way after two attempts, stop and report it. Escalate any comment that needs a human decision.
5. Write `sdlc/<slug>/deploy.md` from the template, approve it for the task's `gate_mode` (`.claude/rules/sdlc.md`), then commit and push it.
6. Merge:
   - `pr: auto` with green checks: merge with the repository's merge method (`gh pr merge`).
   - `pr: ask`: ask first.
   - `strict` mode: the code owner approves and merges.
   - Workspace mode: merge in the order of `## Merge order` in plan.md.
   Never bypass branch protection or required reviews.
7. After each merge, follow the repository's documented release process (its CLAUDE.md, CONTRIBUTING or release workflow): propose the version, then tag or release, and watch the pipeline it starts. Creating tags and releases is visible to others: ask first unless `pr: auto`. If the changed service has no control bands yet, suggest `/sdlc-setup bands`. Ask before deleting the branch. Report the task complete and show `.claude/sdlc-scripts/status.sh <slug>`.

## deploy.md

```markdown
---
slug: <slug>
phase: deploy
status: draft
approved_by:
approved_at:
---

# Deploy: <title>

PR: <url> (one line per repository in workspace mode)

## Review findings
| Severity | File:line | Finding | Resolution |
| --- | --- | --- | --- |

## Checks
<final state of the PR checks>

## Release
<pipeline run and result, or: none configured>
```
