# ai-native-sdlc

My implementation of Anthropic's [AI-native SDLC playbook](https://claude.com/resources/articles/the-ai-native-sdlc-playbook) ([course](https://academy.claude.com/courses/ai-native-sdlc-playbook)) as Claude Code skills, agents, rules and hooks. Copy one `.claude/` folder into a project and every change moves through intent, design, plan, build, test and deploy, one Claude Code session per phase, with each phase's output committed as a markdown artifact the next phase reads.

Not affiliated with Anthropic. [playbook-notes.md](playbook-notes.md) summarizes the playbook in my own words and maps each of its plays to a command here.

## How it works

```text
/sdlc-intent ──> /sdlc-spec ──> /sdlc-plan ──> /sdlc-build ──> /sdlc-test ──> /sdlc-deploy
  intent.md        spec.md          plan.md        build.md        test.md        deploy.md + PR
      ^                                                                                 │
      └──────────────── /sdlc-maintain (alerts, incidents, scans become new intents) ◄──┘
```

- A task lives in `sdlc/<slug>/` on branch `sdlc/<slug>`. `task.yaml` holds its settings, and each phase writes one artifact with YAML frontmatter (`status: draft | accepted | rejected`).
- A phase is finished when its artifact is `accepted`. It then prints the command that starts the next phase in a new, named session (`<slug>-<phase>`), or starts it by itself in autonomous mode.
- Files are the handoff, so no phase needs an earlier session. Old sessions stay available for backtracking (`claude -r <slug>-<phase>`), but nothing depends on them.
- Every question to you goes through the [`grilling`](https://skills.sh/mattpocock/skills/grilling) skill. Claude first finishes its research, then asks one round of short questions, each with a recommended answer you can accept with "yes".

| Phase | Command | Writes | Default model, effort, permission mode |
|---|---|---|---|
| intent | `/sdlc-intent <idea or ticket>` | `task.yaml`, `intent.md` | opus, high, acceptEdits |
| spec | `/sdlc-spec <slug>` | `spec.md` (numbered requirements R1, R2, ...) | opus, xhigh, acceptEdits |
| plan | `/sdlc-plan <slug>` | `plan.md` (steps, a proof per requirement) | opus, xhigh, plan |
| build | `/sdlc-build <slug>` | code, tests, `build.md` | sonnet, high, auto |
| test | `/sdlc-test <slug>` | tests, fixes, `test.md` | sonnet, high, auto |
| deploy | `/sdlc-deploy <slug>` | pull request, `deploy.md` | opus, high, default |
| | `/sdlc-maintain breach\|oncall\|scan\|triage` | new agent-written intents | opus, high, default |
| | `/sdlc-setup <play>` | one-time project setup | opus, high, default |
| | `/sdlc-status [slug]` | nothing (read-only) | |

The defaults live in `.claude/sdlc-scripts/next.sh`. Before each handoff Claude weighs them against the task and may change them, giving a one-line reason. Per-task overrides you ask for go in `task.yaml` (for example `build_model: opus`) and always win. Claude never picks Fable or `--dangerously-skip-permissions` on its own; both are used only when you ask.

## Install

Built for the Claude Code CLI in a terminal. The skills, agents, rules and hooks are plain Claude Code configuration, but the handoff commands, session names, `claude -r` backtracking and autonomous mode (`claude --bg`, `claude agents`) are CLI features. The desktop app and IDE extensions are untested.

Prerequisites: Claude Code, git, the GitHub CLI (`gh`, signed in), `jq`, and the `grilling` skill:

```sh
npx skills add https://github.com/mattpocock/skills --skill grilling -a claude-code -g -y
```

Copy the folders into your project:

```sh
git clone https://github.com/bakirgdev/ai-native-sdlc /tmp/ai-native-sdlc
mkdir -p your-project/.claude
cp -R /tmp/ai-native-sdlc/.claude/agents /tmp/ai-native-sdlc/.claude/hooks /tmp/ai-native-sdlc/.claude/rules \
      /tmp/ai-native-sdlc/.claude/sdlc-scripts /tmp/ai-native-sdlc/.claude/skills your-project/.claude/
```

Then copy `.claude/settings.json` if your project has none, or merge its `env`, `permissions`, `enabledPlugins` and `hooks` into yours. Add `.claude/settings.local.json` and `.claude/worktrees/` to your `.gitignore`. Then, in the project, from the default branch:

```sh
claude "/sdlc-setup verify"
```

This sets `SDLC_VERIFY`, the one command that proves the project works. Until it is set, the commit gate blocks code commits on SDLC branches. Pick and change anything you like; everything is plain markdown and POSIX shell.

## Walkthrough

From an empty `.claude/` to a merged change. Run every step in the project folder; each phase runs in its own session.

**Once per project, from the default branch:**

1. `/sdlc-setup verify`: one command that proves the project works. Required: code commits on SDLC branches are blocked until it is set.
2. `/sdlc-setup claude-md`: a short CLAUDE.md with commands, conventions and mistakes to avoid.
3. `/sdlc-setup review`: `REVIEW.md`, saying what failure means in this project, the nit cap, paths to skip, and the paths that always need a human.
4. `/sdlc-setup gates`: approval hooks, plus the branch protection and CODEOWNERS that make the always-human paths binding on GitHub.
5. Later, when you need them: `evals` (regression suite, including reviewer cases), `pipeline` (CI/CD), `bands <metric>` (production alerts), `policy-skill`, `guardrail`.

**Per change:**

| Step | Run | What happens | What you do |
|---|---|---|---|
| 1. Intent | `/sdlc-intent <idea or ticket>` | Claude asks about scope, users and constraints, then writes `intent.md` and `task.yaml` on branch `sdlc/<slug>` | Answer one question round: slug, `gate_mode`, `run_mode`, `pr`. Correct the intent and accept it |
| 2. Spec | `/sdlc-spec <slug>` | Turns the intent into numbered requirements (R1, R2, ...) and flags conflicting policies | Settle the flagged concerns, accept |
| 3. Plan | `/sdlc-plan <slug>` | Files, ordered steps, a proof per R#, risks with rollback, and the risk tier (`low`, `medium`, `high`) | Challenge the plan and accept it. Code stays blocked until you do |
| 4. Build | `/sdlc-build <slug>` | Test-first implementation, parallel steps in worktrees; every code commit runs the check command | Answer questions if scope changes |
| 5. Test | `/sdlc-test <slug>` | A fresh context proves each R# with tool output and fixes gaps test-first | Accept the evidence |
| 6. Deploy | `/sdlc-deploy <slug>` | Raises the risk tier if the diff touches risky paths, reviews the branch at that depth (at most three rounds), fixes confirmed findings, opens the PR with Risk and How to revert, works CI and comments | Decide on findings Claude calls wrong or intentional, and where each SDLC feedback entry goes. Say yes to the merge for `medium` and `high` risk |
| 7. After release | `/sdlc-maintain triage` | Lists agent-written intents: alerts, scans, and pre-existing bugs found in review | Fix now, schedule or dismiss each |

Every phase ends by printing the next command (or starting it, in autonomous mode). `/sdlc-status` shows where every task stands. Details for each part follow below.

## Use

Start a task:

```sh
claude -n new-task --model opus --effort high --permission-mode acceptEdits "/sdlc-intent users can't reset their password from mobile"
```

The intent phase settles everything in one grilling round:
- **Slug**: a proposal plus alternatives, or your own.
- **Approval mode** and **run mode**: see below.
- **PR handling**: `ask` (Claude asks before pushing, opening and merging) or `auto` (Claude does all three).
- **Per-phase overrides** of model, effort and permission mode.

Every phase ends by printing the next command, for example:

```sh
cd '/path/to/project' && claude -n 'mobile-password-reset-spec' --model opus --effort xhigh --permission-mode acceptEdits '/sdlc-spec mobile-password-reset'
```

### Approval modes (`gate_mode`)

Before every approval the `sdlc-gatekeeper` agent checks the phase's artifact against the ones before it.

| Mode | Who approves each phase |
|---|---|
| `solo` (default) | You, with a yes in chat. Claude records `approved_by` and commits. |
| `auto` | Claude, when the gatekeeper passes. You are asked only about decisions that are yours. |
| `strict` | The playbook's roles: the product owner accepts intent and spec, an engineer or tech lead accepts the plan, and the code owner approves and merges the PR. Claude never approves. |

### Run modes (`run_mode`)

| Mode | How the next phase starts |
|---|---|
| `manual` (default) | You run the printed command in a new terminal. |
| `autonomous` | The finished phase starts the next one as a background session (`claude --bg`), named `<slug>-<phase>`. You are pulled in only for questions and approvals. `claude agents` lists the sessions, and "Needs input" means one is waiting for you; `claude attach <slug>-<phase>` opens it. Claude Code's `inputNeededNotifEnabled` setting can push that to your phone. A phase set to `bypassPermissions` is never started automatically. |

Claude cannot run `/clear` or `/compact` itself, so autonomy uses fresh sessions instead of clearing one. Within a phase, Claude Code compacts automatically when needed. The always-loaded rule says what a summary must keep, and a SessionStart hook re-injects the task state after compaction and on resume.

### Code review

`/sdlc-deploy` reviews the branch before it pushes, following [how the Claude Code team does code review](https://claude.dev/blog/solving-code-review-at-anthropic/).

- **The change sets the risk tier.** The plan sets `risk: low | medium | high` in task.yaml. Deploy raises it to `high` when the diff touches CI or release workflows, `.claude/`, `CLAUDE.md`, `REVIEW.md` or a path under `## Always human` in REVIEW.md. The tier never goes down.
- **Depth follows the tier.** `low`: the `sdlc-reviewer` agent. `medium`: plus `/code-review high` and `/security-review`. `high`: `sdlc-reviewer` on opus, `/code-review max` and `/security-review`. A fresh `sdlc-reviewer` then verifies the Important (including all security) and Pre-existing findings, and only confirmed ones are fixed, test-first.
- **Severity** is Important, Nit or Pre-existing. Pre-existing bugs are not fixed in the PR; each becomes a new draft intent for `/sdlc-maintain triage`.
- **At most three rounds.** Later rounds review only the new commits and never repeat a finding. After three, Claude asks you to rethink the approach.
- **Every finding gets an outcome** in deploy.md (`fixed`, `wrong`, `intentional`, `unimportant`, `deferred-intent`), which shows how noisy review is.
- **Merge by tier.** `low` follows `pr:`. `medium` and `high` always need your yes, even with `pr: auto` or `gate_mode: auto`.
- `/sdlc-setup review` writes `REVIEW.md`: what failure means in your repository, a nit cap, paths to skip, evidence rules and always-human paths. The managed Code Review service reads it too; its PR comments are handled like any other finding. `/sdlc-setup gates` suggests the branch protection that makes always-human paths binding, and `/sdlc-setup evals` can score the reviewer on past incidents.

### Improving the SDLC

The flow is meant to keep getting better from its own use. When a session runs into a part of it that gets in the way (an unclear or contradicting step, a gate that blocks correct work or lets wrong work through, a default that does not fit, a step that catches nothing, an outdated claim about Claude Code, a noisy REVIEW.md or a flaky check command), it does not quietly work around it. It adds a bullet under `## SDLC feedback` in that phase's artifact: what happened, why it hurts, and the suggested change. The gatekeeper and reviewer report theirs too.

`/sdlc-deploy` collects every bullet, adds one when review was noisy (two or more findings of one class ended `wrong` or `unimportant`), and asks where each goes:

- `issue`: a flaw in the SDLC files, filed on this repository (or your fork) with `gh issue create`. Claude shows the draft first, with project-private details left out, and files it only after your yes;
- `task`: something your project owns, such as its check command, REVIEW.md or CLAUDE.md, created as a new intent for `/sdlc-maintain triage`;
- `dropped`, with a reason.

The flow is never changed mid-task to get past a problem: the session follows it as written and records the suggestion.

### Status

- `/sdlc-status [slug]` shows every task's phase, status and approver, and the next command. It also reads tasks whose branch is not checked out.
- `.claude/sdlc-scripts/status.sh` prints the same thing in any terminal without Claude, so you can check while a phase is busy.
- `/btw what phase are we in?` asks the running session without interrupting it (no tool access).
- Status line: call `.claude/sdlc-scripts/status.sh --line` from your own status line script, run in the project directory. A project `statusLine` would replace yours, so none is shipped.

### Backtracking

`claude -r <slug>-<phase>` reopens an earlier phase's session. `--fork-session` branches it without changing the original. To redo a phase, set its artifact back to `draft`, then run `.claude/sdlc-scripts/next.sh <slug> --phase <phase>`. A change to an accepted artifact sends every later artifact back to `draft` too.

### Workspace mode (several repositories)

For tasks that change several repositories at once. Use it when one folder, a git repository or not, holds the repositories as subfolders:

```text
work/                 Claude starts here: .claude/ and sdlc/<slug>/ live in this folder
  api/   (git repo)   branch sdlc/<slug> when the task changes it
  web/   (git repo)   branch sdlc/<slug> when the task changes it
```

1. Copy `.claude/` into `work/` and run `claude "/sdlc-setup workspace"` there. It finds every folder with `.git` directly inside `work/`, asks for each repository's check command, and writes `.claude/sdlc-workspace.yaml`. That file switches the mode on; delete it to switch back. Run the play again when repositories are added or removed.
2. Use the same commands as in a single repository. The intent phase asks which repositories the task changes (`repos:` in task.yaml) and creates `sdlc/<slug>` in each.
3. The plan gives every path its repository and a merge order across repositories. Build can run one agent per repository in parallel (`sdlc-repo-implementer`), and deploy opens one PR per repository and merges them in that order.
4. The task files are committed only when `work/` is itself a git repository and `sdlc/` is not git-ignored there. Otherwise they stay on your disk, and keeping them is up to you.

Always start Claude in `work/`. The gates check every repository there: a code commit anywhere waits until the task's plan is accepted and that repository's check passes.

## What is in `.claude/`

| Path | Purpose |
|---|---|
| `skills/sdlc-*/SKILL.md` | The 9 commands. Phase skills are user-invoked only; `sdlc-status` can also be used by Claude. |
| `agents/sdlc-gatekeeper.md` | Read-only, opus. Checks each phase's artifact against everything before it; PASS or FAIL. This is the playbook's independent confidence gate. |
| `agents/sdlc-reviewer.md` | Read-only code review against intent, spec, plan, CLAUDE.md and REVIEW.md, or verification of other reviewers' findings. Used by `/sdlc-deploy`. |
| `agents/sdlc-verifier.md` | Fresh-context checks: the verify command, each requirement's proof, Playwright against the mock. Reports only. |
| `agents/sdlc-implementer.md` | Single-repo mode: runs one parallel-safe plan step in its own git worktree. |
| `agents/sdlc-repo-implementer.md` | Workspace mode: implements one repository's plan steps in place and leaves the commit to the main session. |
| `agents/sdlc-test-writer.md` | Writes the failing test before a fix. A hook scoped to this agent limits its Edit and Write calls to test files. |
| `agents/sdlc-diagnoser.md` | Read-only incident and control-band diagnosis for `/sdlc-maintain`. |
| `rules/sdlc.md` | Always loaded, like a CLAUDE.md section: phases, grilling, context7, Playwright, approval modes, handoff, compaction. |
| `rules/sdlc-artifacts.md` | Loaded only when Claude touches `sdlc/**`: task.yaml keys, frontmatter, status values, how accepted artifacts change. |
| `hooks/sdlc-plan-gate.sh` | On a `sdlc/<slug>` branch, blocks edits outside `sdlc/` until plan.md is accepted. |
| `hooks/sdlc-commit-gate.sh` | On a `sdlc/<slug>` branch, blocks code commits until plan.md is accepted and `$SDLC_VERIFY` passes. Commits of test files alone pass, so a failing test can be committed before its fix. It looks at every changed and untracked file, so keep the tree clean. |
| `sdlc-scripts/next.sh`, `sdlc-scripts/status.sh`, `sdlc-scripts/lib.sh` | The handoff command (prints or launches), the status report, shared helpers. |
| `settings.json` | The hooks above, `SDLC_VERIFY`, the plugin list, and pre-approval for the read-only `status.sh` and `next.sh --defaults`. Running `next.sh` for a handoff goes through normal permission checks, so a background session is never started without auto mode's classifier or your approval. Project-local only; nothing touches `~/.claude`. |

Want the SDLC rules inside CLAUDE.md instead of a rule file? Paste `rules/sdlc.md` into it as a section and delete the file.

## Plugins

`settings.json` declares the plugins below under `enabledPlugins`. Claude Code does not install plugins from a project file. Until you install them, `/plugin` lists them as enabled but not installed. Install them with `claude plugin install <name>@claude-plugins-official --scope project`. The skills use them when present and never require them, except for context7 and Playwright, which the rules rely on.

| Plugin | Author | Used for |
|---|---|---|
| `context7` | Upstash | Up-to-date docs for any library, API or CLI Claude is not sure about. Rules require it. |
| `playwright` | Microsoft | Default browser and UI checks in build and test. |
| `feature-dev` | Anthropic | `code-explorer` and `code-architect` agents for design and plan research. |
| `code-simplifier` | Anthropic | Cleans changed code at the end of build. |
| `pr-review-toolkit` | Anthropic | `pr-test-analyzer` and `silent-failure-hunter` in test, `code-reviewer` in deploy. |
| `security-guidance` | Anthropic | Security warnings on edits and an LLM review of each turn's diff and each commit. It costs extra model calls; `SECURITY_REVIEW_MODEL` picks a cheaper model. |
| `claude-md-management` | Anthropic | `/revise-claude-md` for `/sdlc-setup claude-md`. |
| `hookify` | Anthropic | Drafts guardrail hooks for `/sdlc-setup guardrail`. |
| `skill-creator` | Anthropic | Writes and tests policy skills for `/sdlc-setup policy-skill`. |
| `claude-security` | Anthropic | Deep vulnerability scans for `/sdlc-maintain scan`. |

- **Disabled in this project:** `superpowers`. It is a competing workflow: its SessionStart hook pushes brainstorming and its own plan files ahead of everything, which would fight these phases.
- **Worth adding per project:**
  - the language server plugin for your stack (`typescript-lsp`, `pyright-lsp`, `gopls-lsp`, `rust-analyzer-lsp` and others);
  - `code-modernization` for legacy code;
  - `chrome-devtools-mcp` for performance and Lighthouse work;
  - your vendors' plugins (Sentry, Datadog, Linear and others) for the maintain phase.
- **Not used:**
  - the GitHub MCP plugin, because the `gh` CLI covers GitHub;
  - `ralph-loop`, whose Stop-hook loop works against the approval gates.

**MCP.** The SDLC needs no project MCP server, so no `.mcp.json` ships. Put general servers in your user scope (`claude mcp add --scope user`), and project-specific ones in that project's `.mcp.json`: issue tracker, deploy targets, observability.

## Customizations over the playbook

These are my choices on top of the playbook, recorded so the flow can be copied and refreshed later.

1. **Sessions.** One Claude Code session per phase, named `<slug>-<phase>`. Sessions are kept for optional backtracking, never required: committed files are the handoff.
2. **Model per phase.** Each phase has a default model, effort and permission mode. Claude weighs them before each handoff, and per-task overrides go in `task.yaml`. Only the latest model of each tier, and no Fable.
3. **Handoff command.** Each phase ends with a ready-to-run command for the next one: directory, session name, model, effort, permission mode, and the skill with its arguments. `--dangerously-skip-permissions` is used only on request.
4. **Task folder.** Artifacts are committed under `sdlc/<slug>/`. The slug is proposed in the intent phase with alternatives, and you can choose your own for that task.
5. **Questions.** Every question goes through the `grilling` skill: all research first, then one round of simple questions with recommended answers. Questions can come up again mid-implementation. Without grilling installed, the skills stop and print the install command.
6. **Plan and build are separate.** The playbook's Build stage is split into plan and build, each in its own session.
7. **Approval modes.** `solo` (the default), `auto` and `strict`. PR handling is `ask` or `auto`, and with `auto` Claude merges.
8. **Autonomous mode.** An opt-in run mode chains the phases through background sessions.
9. **Tools.** context7 for anything uncertain, Playwright as the default browser tool, the `gh` CLI instead of a GitHub MCP.
10. **Local only.** Hooks and settings are project-local, and distribution is a git repo to copy from, not a plugin.
11. **One-time setup.** The playbook's one-time plays (CLAUDE.md, REVIEW.md, policy skills, guardrails, approval gates, evals, CI/CD, control bands) live in `/sdlc-setup`, so each phase skill stays one linear workflow.
12. **Workspace mode.** One folder holding several repositories, so one task can change several repositories at once, each on its own `sdlc/<slug>` branch.
13. **Risk-scaled code review.** Based on [how the Claude Code team does code review](https://claude.dev/blog/solving-code-review-at-anthropic/). See "Code review" above.
14. **SDLC feedback.** Every session records where the flow itself fell short, and deploy turns each entry into an issue upstream, a project task, or a dropped note. See "Improving the SDLC" above.

## Limitations

- **The hooks are guardrails against mistakes, not a security boundary.**
  - A file written through a shell command skips the plan gate until the commit gate sees it.
  - The commit gate does not try to work out which repository a command commits to. While this project's SDLC branch has unmet conditions, any command that mentions `commit` is blocked, including commits to other repositories. Commits by `sdlc-implementer` in its own worktree are exempt and verified after the merge.
  - For enforcement that sees the real commit, add a native git `pre-commit` hook (`core.hooksPath`) running the same checks. It needs setup in every clone.
  - The check commands live in files Claude can edit (`SDLC_VERIFY` in `.claude/settings.json`, `.claude/sdlc-workspace.yaml`), like the tests themselves. Review changes to them in the diff.
  - In `solo` and `auto` modes the agent records the approval. In `strict` mode the hard boundary is branch protection with a code owner's review.
- **Starting a phase with a skill as the first prompt** (`claude "/sdlc-spec x"`) was verified with background sessions (`claude --bg`) and `claude -p`.
- **Session transcripts expire** after `cleanupPeriodDays` (30 days by default). Raise it if you rely on backtracking.
- **`grilling` is a third-party skill** and updates upstream.

## License

MIT, see [LICENSE](LICENSE). The playbook itself is Anthropic's; this repo links to it and does not copy it.
