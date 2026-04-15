<!--
  software-engineer-agents
  Copyright (C) 2026 demwick
  Licensed under the GNU Affero General Public License v3.0 or later.
  See LICENSE in the repository root for the full license text.
-->

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Context for developing the `software-engineer-agents` plugin itself. This file is loaded into every Claude Code session run from inside this repo — keep it short and action-oriented.

## What this repo is

A Claude Code native plugin that automates core software engineering responsibilities (architecture, planning, implementation, testing, code review, debugging, docs). See `README.md` for the user-facing pitch and `DESIGN.md` for the architectural rationale.

## Repo layout

- `.claude-plugin/plugin.json` — manifest (name, version, license, author, repo)
- `agents/*.md` — four subagents with YAML frontmatter: `researcher`, `planner`, `executor`, `verifier` (plus `_common.md`, the shared operating constitution). v2.0.0 removed `reviewer` and `debugger` — code review and systematic debugging are delegated to composition with `addyosmani/agent-skills` and `obra/superpowers`.
- `skills/*/SKILL.md` — six user-facing commands (post v2.0.0 scope cut): `sea-init`, `sea-go`, `sea-quick`, `sea-diagnose`, `sea-status`, `sea-roadmap`
- `hooks/hooks.json` + `hooks/run-hook.cmd` + `hooks/{session-start,auto-qa,state-tracker}` — three hooks, one polyglot wrapper
- `scripts/detect-test.sh` — auto-detects the project's test runner across 8 ecosystems
- `docs/STATE.md` — reference for the runtime `.sea/` directory layout
- `examples/state/` — populated sample state files for documentation
- `TESTING.md` — live-testing checklist against a real Claude Code session

## Hard rules

1. **Native APIs only.** Skills, subagents, hooks, and `.claude-plugin/plugin.json` — nothing else. No MCP servers, no custom runtime, no external dependencies beyond `bash`, `jq`, and `git`.
2. **Token efficiency matters.** Use Haiku for read-only or fast-turn agents (`researcher`, `verifier`). Use Sonnet only where judgment matters (`planner`, `executor`). Read-only agents must never get `Write` or `Edit` — use `disallowedTools` or an explicit `tools:` allowlist.
3. **Zero configuration.** Never ask the user to edit a settings file, pick a model, or set a preference. Auto-detect everything (test runner, project type, mode).
4. **Lean on platform built-ins.** Cross-session memory → subagent `memory: project` field. Auto-QA loop → `Stop` hook with `decision: "block"`. Context injection → `SessionStart` hook with `additionalContext`. Never reinvent these with custom scripts.
5. **Side-effect commands are user-invocable only.** `init`, `go`, `quick` → `disable-model-invocation: true`. Read-only commands → auto-invocable. Do not invert this.
6. **AGPL-3.0-or-later.** Every source file has the four-line AGPL header. JSON manifests are the only exception (JSON has no comment syntax) and are covered by reference to the root `LICENSE`.

## Build / test / validate

There is no build step. Validation is:

```bash
# JSON syntax
python3 -c "import json; json.load(open('.claude-plugin/plugin.json'))"
python3 -c "import json; json.load(open('hooks/hooks.json'))"

# Bash syntax for every hook script
for f in hooks/session-start hooks/auto-qa hooks/state-tracker hooks/run-hook.cmd scripts/detect-test.sh; do
    bash -n "$f" && echo "✓ $f"
done

# Frontmatter presence
for f in agents/*.md skills/*/SKILL.md; do
    head -1 "$f" | grep -q '^---$' && echo "✓ $f"
done

# Smoke-test the session-start hook
CLAUDE_PLUGIN_ROOT="$(pwd)" bash hooks/session-start
```

For the full deterministic test suite (hooks, state, detect-test, frontmatter):

```bash
bash evals/run.sh
```

This is what CI (`.github/workflows/evals.yml`) runs on every pull request.

To run a single eval suite in isolation (each suite is a self-contained bash script under `evals/suites/<group>/<name>.sh`):

```bash
bash evals/suites/hooks/auto-qa-blocks-on-failing-tests.sh
```

For live testing in Claude Code, run:

```bash
claude --plugin-dir "$(pwd)"
```

Then follow `TESTING.md`. Use `--debug-file /tmp/sea.log` when hooks misbehave and `tail -f /tmp/sea.log` in another terminal.

## Commit conventions

- **Conventional commits.** `feat(agents): add …`, `fix(hooks): …`, `docs(readme): …`, `chore(license): …`
- **Atomic commits.** One logical change per commit. If a diff touches multiple concerns, split it.
- **No `--no-verify`**, **no `git push --force`** unless I explicitly ask for it.

## Scope of "the plugin"

The plugin exists to drive **other** projects, not to drive its own development. When working on this repo:

- **Do not** run `/sea-init` or `/sea-go` against this repo — they'd try to scaffold a Node app or plan phases inside the plugin, which is nonsense.
- **Do not** create `.sea/` inside this repo. It's gitignored in user projects; this repo's `.gitignore` also excludes it as a safety belt.
- **Do** use Claude's built-in tools (Read, Edit, Bash, Grep) for direct changes to plugin source files.

## Gotchas

- Hook scripts are **extensionless** on purpose. Claude Code's Windows auto-detection prepends `bash` to any command containing `.sh`, which breaks the polyglot wrapper. Keep them extensionless.
- `run-hook.cmd` is a polyglot file: `cmd.exe` reads the batch block, bash interprets `: << 'CMDBLOCK'` as a no-op and continues past `CMDBLOCK` to the Unix section. Don't touch the structure.
- Adding a comment header to a JSON file will silently break plugin loading. Skip JSON files when adding license headers.
- Frontmatter in agents and skills must start on line 1 — no BOM, no header comment before `---`. HTML comments go **after** the closing `---`.
- Every write to `state.json` from a hook script must use `jq` (or bail) — manual `sed`/`awk` on JSON is fragile and will eventually corrupt the file.
- Skills must update `state.json` **only** through `scripts/state-update.sh`. Raw `Write`/`Edit` on an existing state.json risks dropping `schema_version`, `mode`, or other required fields (this actually happened during V1 testing). The helper jq-merges, preserves required fields, auto-refreshes `last_session`, and validates before writing. The only exception is the initial `Write` from `sea-init` when the file doesn't exist yet.
- **Progressive disclosure**: every `skills/<name>/SKILL.md` should stay under 500 lines (agentskills.io spec recommendation). When a skill's core workflow fits in one screen but protocol details, edge cases, or reference material would bloat it, extract those into `skills/<name>/references/<topic>.md` and link from SKILL.md with a one-line pointer (*"For X, see `references/X.md`"*). Never deep-nest — keep references one level below SKILL.md. The runtime loads SKILL.md on skill activation but only loads `references/` files when the agent explicitly reads them.

## Current known gaps

- `evals/` covers the deterministic plumbing (hooks, state schema, detect-test, frontmatter) but deliberately skips LLM behavior. A green CI means the plumbing is intact, not that the plugin's agent output is good — use `TESTING.md`'s live-test checklist for that.
- Live end-to-end evals against a real `claude` CLI are post-V1 (see `docs/specs/2026-04-14-evaluation-layer-design.md` → Follow-Up Work).
- Marketplace distribution is post-V1. Until then, local `--plugin-dir` is the install path.
- The `/software-engineer-agents:` namespace prefix is long. Autocomplete makes it tolerable, but a shorter alias could be worth exploring later.

## When in doubt

Read `DESIGN.md`. It explains *why* each architectural decision was made. If a proposed change contradicts a decision there, the change should come with an update to `DESIGN.md` that explains what changed and why.
