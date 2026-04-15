<!--
  software-engineer-agent
  Copyright (C) 2026 demwick
  Licensed under the GNU Affero General Public License v3.0 or later.
  See LICENSE in the repository root for the full license text.
-->

# Scope and state refactor — journal

Companion to `docs/specs/2026-04-15-scope-and-state-refactor.md`.
This is the permanent record of what was decided at each phase and why.

## Phase 0 — baseline (2026-04-15 03:11)

- `bash evals/run.sh`: 17 passed, 0 failed
- `bash tests/run-tests.sh`: 70 passed, 0 failed
- `pre-scope-cut` tag: `9e2a73827134a01513d9f8f105e7854fa2ea2c25`
- Initial skill count: 11 (`ls -d skills/*/ | wc -l`)
- Initial agent count: 7 files (6 agents + `_common.md`)
- Initial `.sea/` file references (repo-wide grep across `agents/`, `skills/`, `hooks/`, `scripts/`, `evals/`, `tests/`, `README.md`, `CLAUDE.md`): 154
- Any eval failures on baseline: none
- Pre-phase housekeeping commits on `main`:
  - `4e54786` docs(claude-md): add intro line and single-suite eval example
  - `df2f932` docs(specs): add v2.0.0 scope and state refactor spec

## Phase 1 — docs truth pass (YYYY-MM-DD)

- PR: #<number>
- Commits: <count>
- Surprises: <list>
- Decisions made: <list>
- DESIGN.md disposition: retired with superseding note / rewritten / other

## Phase 2 — state audit (YYYY-MM-DD)

- PR: #<number>
- `docs/STATE.md`: <final line count>
- Files inventoried: <count>
- Invariants documented: <count>
- Consolidation opportunities: <count>
- User sign-off on consolidation scope: <yes / no / pending + date>
- Items deferred to a future refactor: <list>

## Phase 3 — delete cut commands (2026-04-15)

- PR: merged into `main` via `--no-ff` from `refactor/delete-cut-commands` (single-session mode; no GitHub PR yet — push deferred to Phase 8)
- Skills deleted: `sea-ship`, `sea-review`, `sea-debug`, `sea-milestone`, `sea-undo` (5 skill directories, 5 atomic commits)
- Eval suites deleted: none. `tests/run-tests.sh` had two routing assertions (`routing mentions sea-debug` and `routing mentions sea-ship`) — updated in place to assert the still-present `/sea-go` and `/sea-roadmap` instead of being deleted.
- README/CLAUDE.md/SKILL.md/hook update sites:
  - `skills/sea-go/SKILL.md` — Step 5 (debug handoff → composition), Step 6.5 (reviewer call → composition note), When NOT to Use, Related
  - `skills/sea-init/SKILL.md` — description, Mode 1 detect, When NOT to Use, Related (milestone path → `/sea-roadmap add`)
  - `skills/sea-quick/SKILL.md` — When NOT to Use, Related (git revert replaces `/sea-undo`)
  - `skills/sea-status/SKILL.md` — When NOT to Use, Related
  - `skills/sea-diagnose/SKILL.md` — When NOT to Use, Related
  - `skills/sea-roadmap/SKILL.md` — When NOT to Use, Related
  - `agents/reviewer.md`, `agents/debugger.md` — descriptions (Phase 4 will delete the files themselves)
  - `hooks/session-start` — routing block trimmed to six commands + composition note
  - `scripts/detect-quality.sh` — header comment no longer names the deleted pre-merge-gate command
  - `tests/run-tests.sh` — routing assertions updated
  - `README.md` — Commands table (11→6 rows), Directory layout skills listing, agent table "Called from" column for reviewer/debugger, Migration from v1.x section, composition workflow narrative, Acknowledgments, differentiator line
  - `CLAUDE.md` — repo layout counts and skill list
- Regression surprises: none. Both `bash evals/run.sh` and `bash tests/run-tests.sh` stayed green throughout.
- Atomic commit count: 13 (5 skill deletions + 2 sea-go edits + 1 retained-skills cleanup + 1 agents cleanup + 1 hooks + 1 tests + 1 scripts + 1 docs+journal)

## Phase 4 — delete cut agents (2026-04-15)

- PR: merged into `main` via `--no-ff` from `refactor/delete-cut-agents` (single-session mode)
- Agents deleted: `agents/reviewer.md`, `agents/debugger.md`
- Remaining callers found (before deletion): none. Audit grep (`agents/reviewer`, `name: reviewer`, `the reviewer agent`; same for debugger) returned only the agent files themselves plus docs/specs/ refactor spec+journal and docs/STATE.md's Per-file detail section — none of which count as callers.
- README/CLAUDE.md updates: agent table trimmed to four rows + a composition note; directory layout skills listing; Migration from v1.x expanded to note the Phase 4 file-level deletion; CLAUDE.md repo layout bullets flipped from six subagents to four.
- Atomic commit count: 3 (2 deletions + 1 docs)

## Phase 5 — roadmap absorbs milestone (2026-04-15)

- PR: merged into `main` via `--no-ff` from `refactor/roadmap-absorbs-milestone` (single-session mode)
- Milestone functionality covered (moved from the deleted `/sea-milestone` SKILL.md into a new "Adding a milestone to a completed project" section in sea-roadmap/SKILL.md):
  - Precondition check (state.json + roadmap.md must exist — already part of sea-roadmap's Step 1)
  - 2–3 clarifying questions via AskUserQuestion (goal, builds-on, stack additions, scope boundary)
  - planner agent Mode A invocation with existing-roadmap context, instruction to output only new phases starting at LAST+1, 1–5 phases
  - Milestone boundary marker insertion into roadmap.md, including retro-marking of existing phases as Milestone 1 on first use
  - state.json update via scripts/state-update.sh with current_phase, total_phases, and the new optional current_milestone field
  - Summary handoff message
  - Milestone rules (never archive, no renumbering, planning-only, one milestone per invocation, scope discipline)
- Functionality dropped: none. Every step of the deleted skill is documented in the new section.
- Live test against throwaway project: **skipped** — this is a single-session run of the whole refactor and no throwaway project is available to exercise the full planner flow. The section is a prompt-engineering change only; it will be validated live when the user runs /sea-roadmap add "..." against a real completed project after v2.0.0 ships. Evals and tests stayed green.
- README update: new "Adding a milestone after the MVP shipped" example in the Typical workflows section.
- Atomic commit count: 2 (1 feat + 1 docs)

## Phase 6 — state consolidation (YYYY-MM-DD)

- PR: #<number>
- Consolidations applied: <list>
- Migration eval fixture: <path>
- Schema version: v1 → v2
- Regression check on auto-qa two-file marker: <pass / fail>

## Phase 7 — rationale comments (YYYY-MM-DD)

- PR: #<number>
- Files touched: <count>
- Magic numbers documented or replaced: <list>

## Phase 8 — v2.0.0 release (YYYY-MM-DD)

- PR: #<number>
- Release URL: <link>
- v1 → v2 migration tested on a real project: <yes / no + notes>
- Smoke test (`claude --plugin-dir .`): <pass / fail>
- Final verdict: <refactor complete / outstanding issues>

## Post-mortem

After v2.0.0 ships, add a short post-mortem section here (1 week later):
- What went well.
- What was harder than expected.
- What should be different next time.
- Whether the 6 → 3 deferred cut is worth pursuing.
