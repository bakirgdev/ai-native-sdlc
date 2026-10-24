---
paths:
  - "sdlc/**"
---

# SDLC artifact format

- `sdlc/<slug>/task.yaml` holds flat `key: value` lines only, because the scripts read it with awk. Keys: `slug`, `title`, `created`, `branch`, `gate_mode` (`solo`, `auto`, `strict`), `run_mode` (`manual`, `autonomous`), `pr` (`ask`, `auto`), and optional per-phase overrides such as `build_model: opus`, `build_effort: high`, `build_permission: auto`. Overrides apply to this task only; add them when the user asks.
- Each phase writes one artifact: intent `intent.md`, spec `spec.md`, plan `plan.md`, build `build.md`, test `test.md`, deploy `deploy.md`. Each starts with YAML frontmatter: `slug`, `phase`, `status`, `approved_by`, `approved_at`. intent.md also has `author` and `ticket`.
- `status` is `draft` (being written or reworked), `accepted` (its gate passed) or `rejected`. Intents written by `/sdlc-maintain` can also be `scheduled` or `dismissed` (add a `reason:` line). Only the approval rules in `.claude/rules/sdlc.md` set `accepted`.
- An accepted artifact is the contract for later phases. A small deviation that keeps the requirements (a different file, a renamed function) goes under `## Changes` with a date and reason, and the status stays. A change to scope, requirements or design sets the artifact back to `draft`, is recorded under `## Changes`, passes its gate again, and sets every later artifact back to `draft`.
- Keep artifacts short and factual. Paste tool output literally in fenced `text` blocks; never paraphrase evidence.
