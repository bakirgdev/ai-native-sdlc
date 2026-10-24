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

### Status

- `/sdlc-status [slug]` shows every task's phase, status and approver, and the next command. It also reads tasks whose branch is not checked out.
- `.claude/sdlc-scripts/status.sh` prints the same thing in any terminal without Claude, so you can check while a phase is busy.
- `/btw what phase are we in?` asks the running session without interrupting it (no tool access).
- Status line: call `.claude/sdlc-scripts/status.sh --line` from your own status line script, run in the project directory. A project `statusLine` would replace yours, so none is shipped.

### Backtracking

`claude -r <slug>-<phase>` reopens an earlier phase's session. `--fork-session` branches it without changing the original. To redo a phase, set its artifact back to `draft`, then run `.claude/sdlc-scripts/next.sh <slug> --phase <phase>`. A change to an accepted artifact sends every later artifact back to `draft` too.

## What is in `.claude/`

| Path | Purpose |
|---|---|
| `skills/sdlc-*/SKILL.md` | The 9 commands. Phase skills are user-invoked only; `sdlc-status` can also be used by Claude. |
| `agents/sdlc-gatekeeper.md` | Read-only, opus. Checks each phase's artifact against everything before it; PASS or FAIL. This is the playbook's independent confidence gate. |
| `agents/sdlc-verifier.md` | Fresh-context checks: the verify command, each requirement's proof, Playwright against the mock. Reports only. |
| `agents/sdlc-implementer.md` | Runs one parallel-safe plan step in its own git worktree. |
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
  - `ralph-loop`, whose Stop-hook loop works against the approval gates;
  - review bots, because code review is deferred.

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
11. **One-time setup.** The playbook's one-time plays (CLAUDE.md, policy skills, guardrails, approval gates, evals, CI/CD, control bands) live in `/sdlc-setup`, so each phase skill stays one linear workflow.
12. **Code review is deferred.** `/sdlc-deploy` runs a fresh-subagent review; a fuller review setup will come separately.

## Limitations

- **The hooks are guardrails against mistakes, not a security boundary.**
  - A file written through a shell command skips the plan gate until the commit gate sees it.
  - The commit gate does not try to work out which repository a command commits to. While this project's SDLC branch has unmet conditions, any command that mentions `commit` is blocked, including commits to other repositories. Commits by `sdlc-implementer` in its own worktree are exempt and verified after the merge.
  - For enforcement that sees the real commit, add a native git `pre-commit` hook (`core.hooksPath`) running the same checks. It needs setup in every clone.
  - In `solo` and `auto` modes the agent records the approval. In `strict` mode the hard boundary is branch protection with a code owner's review.
- **Starting a phase with a skill as the first prompt** (`claude "/sdlc-spec x"`) was verified with background sessions (`claude --bg`) and `claude -p`.
- **Session transcripts expire** after `cleanupPeriodDays` (30 days by default). Raise it if you rely on backtracking.
- **`grilling` is a third-party skill** and updates upstream.

## License

MIT, see [LICENSE](LICENSE). The playbook itself is Anthropic's; this repo links to it and does not copy it.
