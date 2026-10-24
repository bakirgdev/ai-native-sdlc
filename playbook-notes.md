# Playbook notes

These are our own study notes on Anthropic's AI-native SDLC playbook, written for people who want to understand the method behind the `/sdlc-*` commands in this repo. The playbook has two forms: an article, [The AI-native SDLC playbook](https://claude.com/resources/articles/the-ai-native-sdlc-playbook), and a course, [AI-native SDLC playbook](https://academy.claude.com/courses/ai-native-sdlc-playbook). Both cover the same six stages and their plays. Read the originals for the full text, templates and worked examples; nothing here replaces them. Where the article and course differ, a line says so.

## The idea in brief

- The premise: code generation is no longer the slow part. The human-speed steps around it (planning, review, testing, deploying) become the bottleneck, controls written for human-authored code stop fitting, and governance by committee gets expensive.
- The answer is to rebuild each stage around what agents can do while people stay accountable for every decision that needs judgment.
- Six stages: Plan, Design, Build, Test, Deploy, Maintain. They are grouped as stages but are not strictly linear. Teams can transform them in any order that suits their needs.
- The spine is a chain of committed artifacts. Each stage ends by writing one to version control and the next stage starts by reading it:
  - `intent.md` (Plan)
  - `spec.md` (Design)
  - `plan.md` (Build)
  - the diff with its tests (Build, Test)
  - the PR with its review findings (Deploy)
  - the incident record, which becomes a new `intent.md` (Maintain)
- Accepting an artifact is the trigger for the next stage: accepted intent starts design, an approved spec starts planning, a merged PR starts the pipeline, a breached control band in production writes the next intent.
- The chain of commits doubles as the audit trail: who asked for what, what the agent produced, who approved it.
- Early artifacts are Markdown because a non-engineer and an agent can both read and act on the same file. From Build onward the artifact is code and its records.
- Humans concentrate at the gates, reviewing what the agent flagged instead of starting each stage from scratch.
- Adoption path: prompt each step by hand first. The end state is a loop where each accepted artifact fires the next gate.
- Closing line of the playbook: "The loop keeps running. Human judgement stays above it." (playbook)

## Play dependencies

Each play lists its prerequisites. The course describes a dependency graph of twelve plays in five rows. The article shows the same graph as a figure, and its extra plays (hooks as build-time guardrails, recurring scans, Claude on call) are not part of the twelve.

- No prerequisites (adopt any of these first): Capture intent, CLAUDE.md, Skills, Feedback loop, Hooks as approval gates, Plan mode.
- Subagents: need CLAUDE.md; the feedback loop helps.
- Evals: need CLAUDE.md and the feedback loop.
- Requirements and design: need Capture intent and Skills.
- PR review: needs Evals and Subagents; Skills help.
- CI/CD: needs PR review and Hooks.
- Closing the loop: needs CI/CD and Capture intent.
- CLAUDE.md helps Skills but is not required for them.

Inconsistency: the PR-review play's own text lists its prerequisites as an updated CLAUDE.md, skills (if passes enforce written policy) and defined subagents. The graph instead shows Evals and Subagents, with Skills as a soft help. Treat the graph and the play text as two views and satisfy both if unsure.

A smaller mismatch: the Plan mode text says the intent artifact is a prerequisite if one exists and that CLAUDE.md helps, while the graph puts Plan mode in the no-prerequisite row. These agree if if one exists is read as optional.

## Stage 1: Plan

Shift: requirements gathered by committee and written up by hand give way to the originator brainstorming with Claude and committing the result as `intent.md`, readable by humans and actionable by machines. Ownership no longer passes through backlog entries, stories and refinement meetings.

- Capture as intent.md. Command here: `/sdlc-intent`.
  - Intent can enter from a person's idea, a filed ticket, or an incident alert from Maintain.
  - Steps: the originator describes the problem in their own words; Claude asks the analyst questions (scope, users, constraints, success); Claude writes it up with the organization's template (problem, proposed outcome, affected users and systems, constraints, open questions), which can itself be a skill; the originator corrects it; it is committed to a shared home.
  - Setup is one-time and owned by a technical person: an agreed template, a version-controlled home that the product owner watches, and a decision on who may write there. Simplest home for one product is a folder in its repo; a separate repo only pays off when intent spans many repos. Non-git users can commit through a connector from claude.ai or Cowork.
  - The product owner always reviews and corrects an agent-written intent before it is committed, whatever triggered it.

Governance:
- Evidence is the committed file: author, timestamp, full revision history in git.
- The product owner decides accept or reject. That decision, which sends intent into Design, is recorded as a merge or a closed review.

Measures:
- Leading: time from first conversation to a committed `intent.md` (git history on the intent home). Expected to fall from a multi-week cycle to hours.
- Lagging: survival rate (share of intents the product owner accepts into Design rather than closes), plus the count of changes made to the intent after the first `spec.md` commit for the same change.

## Stage 2: Design

Shift: requirements and design stop being two phases run by two teams. They collapse into one prompted session where Claude turns the accepted intent into a spec, constrained by organizational skills (brand, security, compliance, UX), with concerns flagged. Policy is applied while writing, not found in a review weeks later.

- Requirements and design. Command here: `/sdlc-spec`.
  - Prerequisites: an intent plus the policies written as skills. Only a product owner with Claude access is needed, no engineering skill.
  - Steps: open a session with the skills loaded and the intent attached; prompt for a full spec that names constraints and demands flagged concerns, especially contradictory policies; review the spec against the original idea (does it solve the problem, are open questions answered or carried forward); clear flagged concerns with their policy owners first; commit `spec.md` next to `intent.md`; the product owner decides whether to proceed, consulting a tech lead for higher-risk work. A human always makes that call.
  - Automation path: run by hand, then make it an org-level slash command, then make intent acceptance trigger a non-interactive job that opens the spec as a pull request, so the product owner's first touch is the review.
  - Front-end shortcut: the product owner can mock the design in Claude Design (beta) from the intent and export it to Claude Code.
  - The course shows numbered requirements in the spec so that the plan and review can cite them. That is a course illustration, not a rule.

Governance:
- The live policy is applied as constraints during writing. The spec, the prompt and the skill versions in force are all in version control.
- The product owner signs off and routes each concern to its named policy owner.

Measures:
- Leading: elapsed time between the intent commit and the spec commit, against the old requirements-plus-design cycle.
- Lagging: requirements rework after build starts, counted as `spec.md` commits dated after the first `plan.md` commit for the same change.

## Stage 3: Build

Shift: nothing is implemented without an accepted plan; institutional knowledge becomes files the agent reads; guardrails run as code instead of habit. The engineer's role moves toward steering several streams.

- Plan mode as the default start. Commands here: `/sdlc-plan` (the plan), then `/sdlc-build` (implementation).
  - Start in plan mode, give Claude the intent and spec, and ask for a plan naming files to change, order of work and the tests that prove it. Claude cannot edit files until the engineer accepts the plan.
  - Probe it: what could break, which step is riskiest, what alternatives were rejected. Iterate until someone who never saw the conversation could implement from it. Commit as `plan.md`, accept, implement (often one pass).
  - If implementation drifts from the plan, update `plan.md` in the same commit. A hook can enforce that sync.
  - Governance and measures below.
- The CLAUDE.md. Command here: `/sdlc-setup claude-md`.
  - A short repo-root file with what a new joiner needs: commands, conventions, architecture, recurring mistakes. Start from `/init`, trim hard, commit it, and add a correction whenever Claude errs twice. Keep it under about a page because all of it is read every session and stale lines cost context.
- Skills as institutional knowledge. Command here: `/sdlc-setup policy-skill`.
  - Use a skill for knowledge that must be applied consistently; leave other material to CLAUDE.md or a prompt. Steps: pick one inconsistently enforced rule with a named owner; write it as a skill folder whose frontmatter says when it triggers; place it in the repo (or ship it via a plugin); test that it triggers under varied phrasings; change it only with the policy owner's sign-off.
- Hooks as build-time guardrails (article only; the course folds it into the skills page). Command here: `/sdlc-setup guardrail`.
  - A skill is advisory; a hook is the deterministic layer behind it. Typical build hooks: block edits to protected paths, run formatter and linter after edits, keep credentials out of the diff, back any skill whose policy must hold.
  - Keep them fast and scoped to the changed file; heavy checks belong at commit or PR. Hooks that wait for a human belong in Deploy, since a prompt in Build stalls every parallel session.
  - The course adds that an after-edit hook cannot undo the edit (it only feeds the message back), and that a shell rewrite bypasses an edit hook, so the same check should also run as a required PR check.
- Parallel sessions and subagents. Commands here: `/sdlc-build` (parallel steps) and the `sdlc-implementer` agent.
  - A parallel session is a full Claude Code instance in its own git worktree; a subagent is a scoped helper inside one session with its own context and tool limits, suited to recurring jobs such as verifying the app.
  - Steps: split work along independent files using the plan; one worktree per task; start with two or three sessions, since the ceiling is how many streams one person can review properly; define repeated jobs as subagents in the repo, each with a name, a trigger description and a tool list.
- Auto mode (sidebar). Once guardrails mature (tuned CLAUDE.md, policy skills, blocking hooks, runnable tests), auto mode becomes the default for routine work with a tight spec and small blast radius. Attention shifts from watching edits to reviewing artifacts after longer autonomous runs. It also underpins running the whole SDLC autonomously. This repo's opt-in run mode relates to it; see the departures section.
- Legacy systems and the source of truth (sidebar, applies to every artifact). Existing records live in Jira, requirements tools, Figma, change boards, and auditors accept them. For each artifact name exactly one source of truth; others hold a copy or link. Three setups: the repo is authoritative; the legacy system is authoritative and Markdown files are working copies synced via an MCP connector; or minimum linkage (artifacts note the record ID, records carry the commit SHA), accepting two sources of truth. Coexistence is fine if linked or declared.

Governance:
- Plan mode: design review happens before code exists, while changing course is only a document edit. Plan revisions and the accepting person are logged. Routine changes are approved by the engineer; higher-risk goes to a tech lead or architect.
- CLAUDE.md: version controlled, changes land in git history, code owners approve changes in PR review.
- Skills: a control, but advisory. A must-hold policy needs a deterministic backstop (a blocking hook or a PR-time check). Skill use shows in session traces; the policy owner reviews skill changes like code.
- Parallel work: controls must come from repo configuration (hooks, permission settings) so they cover every session; activity is logged and attributed to the engineer who ran it.

Measures:
- Plan mode, leading: share of changes merging from the first implementation pass, and time from plan approval to merged PR. Lagging: rework cycles per change and how often the merged diff still matches `plan.md`.
- CLAUDE.md, leading: how often Claude repeats a mistake the file should have caught (tracked in git history). Lagging: time to first merged PR for a new team member.
- Skills, leading: time from a policy change being approved to the updated skill merging. Lagging: PR review findings that cite the policy, which should trend to zero. If they do not, the skill is not triggering or has drifted from the official policy.
- Parallel sessions, leading: concurrent sessions per engineer while review quality holds (from the OpenTelemetry export) and share of the day spent steering rather than waiting. Lagging: merged changes per engineer per week, read next to the rework rate.

## Stage 4: Test

Shift: QA gates at stage boundaries give way to every session checking its own work before a human looks, and to evals that run continuously and regression-test the agent's own configuration.

- Give Claude a feedback loop. Commands here: `/sdlc-build` (inner loop), `/sdlc-test` (independent verification), `/sdlc-setup verify` (one-time setup).
  - The loop runs throughout the task as often as needed. It differs from a verifier subagent, which is one packaging of the final check in a fresh context so the verdict is not colored by the code's authoring assumptions.
  - Prerequisites: a suite and build runnable with one command each; for UI work, a browser or screenshot tool.
  - Steps: wrap checks in a single target that exits non-zero on failure; list commands with healthy-output examples in CLAUDE.md; set quantifiable targets; for bug fixes write the failing test first, commit it, then fix without touching it; for UI iterate with screenshots against the mock (two or three rounds is normal); make show-the-output part of done; protect the loop by blocking edits to test files during fix tasks (a hook), or reject test-touching diffs in review.
- Continuous evals in CI. Command here: `/sdlc-setup evals`.
  - Evals are the AI-native counterpart of stage-gate QA: a suite that runs when the agent's configuration changes (model swap, prompt rewrite, edits to CLAUDE.md, skills or hooks). It is a live suite; cases that stop discriminating are replaced, and new ones come from monitoring.
  - Prerequisites: CLAUDE.md and the feedback loop. Needs CI that can run Claude Code non-interactively and an API key with budget. Teams may instead run evals offline on a cadence.
  - Steps: collect 20 to 50 real tasks with accepted outcomes; write each as a prompt plus checks (tests, lint, unchanged behavior, policy); run on a schedule and on configuration changes; gate config changes on the result; every production incident adds an eval written by the owning team.
  - Course detail: runs start from the commit before the original task, apply the configuration under test, grade from a copy made beforehand, and fail any run that changes files outside the allowed set, so the agent cannot pass by editing the checks. The course also warns against the flag that skips CLAUDE.md, skills and hooks, since those are what is under test. The article gives only a short sketch.

Governance:
- Feedback loop: verification-before-done and the test-file edit block are hooks where guarantees are wanted. Evidence is toolchain output (test log, build log, screenshot diff). Logged in the session transcript (forwarded via OpenTelemetry) and the PR check run. The code owner approves and can focus on intent and risk.
- Evals: the pass-rate threshold is a merge check, runs are logged for comparison over time, and the team owning the configuration change approves it.

Measures:
- Feedback loop, leading: first-pass CI success rate for agent changes. Lagging: review time per PR and change failure rate.
- Evals, leading: pass rate over time and how long an incident takes to become a permanent eval. Lagging: regressions caught in CI versus found in production.

## Stage 5: Deploy

Shift: humans reading every line and governance by periodic review cycles give way to layered agentic review (human review kept for regulated and critical code) and governance enforced as the agent acts. The agent may do everything up to the production gate and nothing beyond it.

- AI in the PR review loop. Command here: `/sdlc-deploy` (the review itself is deferred in this repo, see the README).
  - Claude reviews incoming PRs against policy and also handles comments on its own PRs, so humans judge intent and risk. Every PR gets the same passes, with findings ranked by severity.
  - Setup: managed Code Review service (enabled by an admin; the course says an Owner of the Claude organization) or the Claude Code action in your own CI, optionally via Bedrock, Vertex or Foundry. Branch protection requiring a code owner is worthwhile.
  - Steps: the tech lead writes `REVIEW.md` defining passes (bugs, security, compliance against spec, plan and design principles), what counts as important versus a nit, and what to skip; findings never approve or block alone, a code owner still approves (a platform engineer can gate on the published severity counts); tagging `@claude` on a comment makes Claude fix and push (in the managed service it requests a fresh review); Claude can shepherd its own PRs to green; repeated review findings go into CLAUDE.md; monthly tuning rates findings and caps nits.
- Hooks as approval gates. Command here: `/sdlc-setup gates`.
  - Build hooks allow or block silently. A gate hook can also ask, pausing until a person approves. The article words it as a specific person approving; the course words it as the session's own user confirming, or the hook looking for a recorded approval by someone else (such as a release manager) and blocking until it exists.
  - Not deploy-specific: hooks apply wherever Claude acts (for example, blocking migration edits without a change ticket in Build, or test-file edits in Test).
  - Steps: leadership with change management and compliance lists the approval gates that must survive; the platform engineer turns each into a hook that allows, asks or blocks; team hooks live in repo settings, non-negotiable ones in managed settings that engineers cannot disable; blocks explain themselves and name the route to approval.
  - The managed-settings worked example for regulated enterprises combines: secret and network deny rules with a pre-approved safe inner loop; no way to widen rules or bypass permissions; an OS-level sandbox that refuses to start if unavailable, with credential files and environment secrets withheld; managed-only hooks, MCP servers and plugin sources; and a minimum client version. It is a starting point to tailor, since every deny trades against capability. The course adds that managed-only hooks also block project-level hooks, so gates must then be defined in the managed file.
- CI/CD integration and deployment. Commands here: `/sdlc-setup pipeline` and `/sdlc-deploy`.
  - Claude runs non-interactively in the pipeline for judgment steps, in a sandbox with scoped credentials, and deployment is exposed through MCP so the workflow that built a change can also ship and roll it back, inside per-environment gates.
  - Steps: begin read-only (triage a failed build, summarize a flaky test, draft a changelog); add write steps that always arrive as PRs under branch protection; sandbox with short-lived scoped tokens and no standing production credentials; expose deploy, status and rollback as per-environment MCP tools (an allowlist, not a credentialed script); tier autonomy (dev free, staging in between, production prepared by the agent and authorized by a release manager through a hook); make rollback the most rehearsed path, because Maintain relies on it.
  - Course detail: one MCP server per environment, because allow rules name the server and tool, not arguments; production keeps release off the allowlist so the hook is the only way through and failure means denial.

Governance:
- PR review: separation of duties holds because the writing agent cannot approve. `REVIEW.md` applies to all PRs; findings, fixes, ratings and approvals live in PR history, so the PR is the audit record. A human approves through branch protection. The article points to a separate Anthropic piece on composing these controls at scale.
- Gates: enforced every time for everyone, decisions logged with timestamps, and the gate defines what counts as approval (approved ticket or release manager sign-off).
- CI/CD: the agent acts up to the production gate and cannot pass it. Branch protection forces PRs; the production hook blocks until a named release manager authorizes; non-interactive runs use the agent's own identity so logs separate agent actions from the triggering engineer; permission tiers per environment.

Measures:
- PR review, leading: time to first review (should fall to minutes) and share of comments resolved without a human touching the branch. Lagging: defects and vulnerabilities caught before merge versus escaping.
- Gates, leading: time spent waiting at each gate (hook decisions with timestamps and verdicts in the OpenTelemetry export). Lagging: gate violations reaching production, before and after hooks.
- CI/CD, leading: share of pipeline failures triaged without paging a human. Lagging: DORA measures already emitted by CI and deployment tooling.

## Stage 6: Maintain

Shift: maintenance stops being reactive. A trigger (band breach, ticket, channel message, schedule) invokes Claude with no person in the invocation path; Claude diagnoses, acts only through gated routes, and writes findings as a new `intent.md`. People triage and review; they no longer start the work.

- Closing the loop on metrics. Commands here: `/sdlc-maintain breach`, `/sdlc-maintain triage` and `/sdlc-setup bands`.
  - This stage runs headless, with an independent confidence gate between stages (a deterministic check or an adversarial reviewing agent) deciding whether output continues or escalates to a human.
  - Prerequisites: intent format, agent-accelerated PR review, hooks as an action boundary, and a rehearsed rollback.
  - Steps: pick one metric with a stable rolling baseline (CI failure rate, post-deploy 5xx rate, PR cycle time); write a deterministic, tested detection script using mean and standard deviation over a rolling window plus drift rules so slow drift is caught too, with no model involved; define response tiers in version-controlled config: log at the lowest band, read-only diagnosis at the middle, and at the top only a PR into the review gate or a pre-approved runbook; trigger by schedule, webhook or cron, running stateless and non-interactive; the agent writes its diagnosis as `intent.md` in the Plan format; the service owner or on-call engineer triages (fix now, schedule, dismiss, with dismissals tuning the bands); each shipped fix adds an eval.
  - Course detail: explains control bands (mean and sigma over about 30 days of readings), why the lowest tier only logs (noise alone trips it often, and even the top tier trips about monthly), and that a drift rule counts as the middle tier. It also includes a full detection script and an incident walk-through that ends in a rollback and an auto-written intent.
  - Examples from both: CI failure breach leads to quarantining a flaky test or a revert PR; a post-deploy 5xx breach with a recent deploy triggers the existing rollback; a cycle-time drift produces a report for engineering leadership.
- Recurring codebase scans (article only). Command here: `/sdlc-maintain scan`.
  - A security scan is a point-in-time statement about both the code and the model, and both go stale. Run scans on a schedule with no human invoking them, and route findings through the same gates as any change.
  - The article presents Claude Security (public beta, Enterprise) as a hosted form, with validated, confidence-rated findings and patches reviewed in Claude Code on the web. Setup needs admin enablement, a GitHub app, usage settings with a spend limit and premium seats.
  - Steps: connect repos and group them by owner; run a first full baseline on critical repos (expect surprises in code thought clean); schedule per project (weekly is a sensible default); triage by confidence and dismiss with a reason; bounded findings go through the PR review gate; wider issues become an `intent.md`; each released fix adds an eval for that vulnerability class; export to the existing tracker where auditors expect the record.
  - It augments, not replaces, deterministic static analysis and dependency scanning in CI.
- Claude on call with Claude Tag (article only; the course has a short version). Command here: `/sdlc-maintain oncall`.
  - Incidents also arrive in chat. Claude Tag (public beta, Slack) makes Claude a channel member under its own identity as first responder, with the conversation staying in the channel as history. It checks via MCP that the metric is back to baseline, confirms in the thread, and writes the post-mortem to a version-controlled lessons file for future investigations.
  - Tickets work the same way: small bounded fixes arrive as PRs through the review gate, and anything larger becomes an `intent.md`, which restarts the loop.

Governance:
- Metrics loop: tier boundaries come from version-controlled config; permissions and managed settings deny production access; invocations, findings and triage decisions are timestamped; a service owner triages and approves; fixes pass the normal review gate; runbooks were approved in advance.
- Scans: admin controls set which repos, who holds a seat, and the spend limit; every finding has a validation result and confidence, every dismissal a reason, so history is an audit record. Fixes reach production only via review and branch protection.
- On call: the channel is the audit trail (request, diagnosis, human authorization, fix).

Measures:
- Metrics loop, leading: time from band breach to an `intent.md` in the triage queue, against the old incident-to-post-mortem time. Lagging: share of findings that become merged fixes, and repeat incidents of the same class (should fall as evals accumulate).
- Scans, leading: share of connected repos on a schedule, and time from reported finding to patch entering review. Lagging: vulnerabilities found by scans versus in production or by external report, and findings per scan trending down on repeatedly scanned repos.
- On call: the source gives no separate measures.

## Closing thoughts

- Models and harnesses are advanced enough to transform the whole lifecycle, not only code production, while keeping human judgment central and respecting enterprise governance and regulation.
- The playbook draws on practices the Applied AI team runs for customers.
- The article ends with a resource list for platform teams (admin setup, settings and managed settings, permissions, sandboxing, hooks, skills, plugin marketplaces, managed MCP, third-party cloud deployment, network config, OpenTelemetry monitoring, compliance API, security model). The course ends with a similar list.

## Where this repo departs from the playbook

- One session per phase. Each command ends by printing the next phase's command instead of firing it automatically, so a human starts every stage in a fresh session.
- Plan is split from build: `/sdlc-plan` produces and commits `plan.md`; `/sdlc-build` implements. The playbook treats plan mode and implementation as one play.
- Artifacts live in a per-task folder, `sdlc/<slug>/`, rather than in a shared intent home plus separate locations.
- Gate approval modes (solo, auto, strict). The playbook assumes distinct roles (product owner, tech lead, code owner); here one person often holds all of them, so the mode sets how much self-approval is allowed.
- An opt-in autonomous run mode, a lighter relative of the playbook's auto mode and headless loop. It stays off unless asked for.
- Questions to the user go through the `grilling` skill.
- Code review is deferred: `/sdlc-deploy` covers the pipeline and release side, and the PR review loop is not implemented yet (see the README).
