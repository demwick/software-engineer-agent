<!--
  software-engineer-agent
  Copyright (C) 2026 demwick
  Licensed under the GNU Affero General Public License v3.0 or later.
  See LICENSE in the repository root for the full license text.
-->

# Changelog

All notable changes to `software-engineer-agent` are documented here.
This project follows [Keep a Changelog](https://keepachangelog.com/) and
[Semantic Versioning](https://semver.org/).

## [Unreleased] — v2.2.0

### Added
- **Iter 4: auto-injection of `_common.md`.** New `hooks/subagent-start`
  hook wired to the Claude Code `SubagentStart` event. Reads
  `agents/_common.md` from `CLAUDE_PLUGIN_ROOT` and injects it into
  every SEA subagent's launch context via the `additionalContext`
  channel. Filters on the stdin `agent_type` field (plugin-qualified,
  e.g. `software-engineer-agent:researcher`) so other plugins'
  subagents are untouched.
- Live-validated against a real `claude --plugin-dir` session: the
  researcher agent quoted Rule 7 verbatim from its launch context
  without reading any file, confirming auto-injection works end-to-end.

### Changed
- Removed the manual `**Read agents/_common.md first.**` imperative
  from every SEA agent file (`researcher.md`, `planner.md`,
  `executor.md`, `verifier.md`). The `SubagentStart` hook supersedes
  it; the file now carries a short HTML comment pointing readers at
  `hooks/subagent-start` instead.

### Eval coverage
- `evals/suites/agents/prompt-quality.sh` extended: asserts the manual
  imperative is absent from every agent file, the hook script exists
  and is executable, and `hooks.json` registers `SubagentStart`.

## [2.1.0] — 2026-04-15

Prompt-quality patterns release. Installs Demonstrate Comprehension
(Step 0), Evidence-Bearing Exit Reports (Rule 7), per-task scope
bounds, and per-plan risk gates across the planner/executor/sea-go
stack. Iteration 3 risk-gate state machine validated end-to-end against
a real `claude --plugin-dir` session on 2026-04-15 (two gate pause +
resume cycles, marker round-trip, cancel path).

### Added
- `_common.md` Rule 7 (Evidence-Bearing Exit Reports): every agent's exit report
  must include actual command output, not a paraphrase.
- Step 0 (Demonstrate Comprehension) in `researcher.md`, `planner.md`, `executor.md`:
  agents state task understanding in structured `UNDERSTOOD:` format before any tool call.
- `evals/suites/agents/prompt-quality.sh`: structural regression protection for both
  additions (Rule 7 presence, Step 0 presence, verifier exclusion).
- Per-task `Allowed paths` / `Forbidden paths` fields in `planner.md` Mode B plan schema.
- Pre-commit scope check (Step 5.5) in `executor.md`: detects out-of-scope files before
  committing; emits `STATUS: blocked` with scope-violation reason.
- `evals/fixtures/plans/sample-plan-with-scope.md`: fixture plan demonstrating scope bounds.
- `evals/suites/agents/scope-creep-detection.sh`: structural simulation of scope-violation
  detection logic.
- `evals/suites/agents/prompt-quality.sh` extended with scope-bound assertions.
- Per-plan `risk_gates` section in `planner.md` Mode B plan schema with
  gate-kind taxonomy (`destructive-git`, `filesystem-destruction`,
  `dependency-removal`, `schema-migration`, `unsafe-shell`,
  `network-state-mutation`).
- Gate-pause protocol in `executor.md`: new `STATUS: gate` exit, writes
  `.sea/phases/phase-N/gate-pending.json`, marks task status `gated` in
  `progress.json`, and resumes via "gate resumed" context on re-launch.
- Step 4.5 "Risk gate inspection" and "Resume after gate" branch in
  `skills/sea-go/SKILL.md`: surfaces gates for explicit user confirmation
  before executor launch and on each `STATUS: gate` return.
- `docs/STATE.md` documents the new `.sea/phases/phase-N/gate-pending.json`
  marker (writer, readers, format, invariants).
- `evals/fixtures/plans/sample-plan-with-gates.md`: fixture plan with one
  task per gate kind.
- `evals/suites/agents/risk-gate-flow.sh`: structural simulation of the
  gate-pending marker round-trip; does not run a real executor.
- `evals/suites/agents/prompt-quality.sh` extended with risk-gate
  assertions (planner, executor, sea-go).

## [2.0.0] — 2026-04-15

v2.0.0 is a disciplined scope cut and state-model consolidation driven
by the refactor documented in
`docs/specs/2026-04-15-scope-and-state-refactor.md`. It removes five
user-facing commands and two agents whose methodology is better served
by composition with external plugins, and bumps the project state
schema from 1 to 2 with automatic one-way migration.

### Removed (BREAKING)

- **Commands:** `/sea-ship`, `/sea-review`, `/sea-debug`, `/sea-milestone`,
  `/sea-undo`. Command surface narrowed from 11 to 6.
- **Agents:** `reviewer` (Sonnet) and `debugger` (Haiku). Agent surface
  narrowed from 6 to 4 (plus `_common.md`, the shared operating
  constitution). Both had no callers after the commands above were
  deleted.

### Changed (BREAKING)

- **State schema bumped from 1 to 2.** `scripts/state-update.sh` now
  auto-migrates `schema_version: 1` → `2` on first touch. The bump is
  the contract that the project uses the two-file auto-QA marker scheme
  described below. Migration is one-way and idempotent; there is no
  rollback in the script. The `pre-scope-cut` git tag is the floor.
- **Auto-QA marker split into two files.** The `.sea/.needs-verify`
  marker is now **existence-only** — the hook ignores its content.
  A new sibling file `.sea/.verify-attempts` holds the retry counter
  as `{"attempts": N}`, written atomically via `jq` to a `mktemp` file,
  then `mv`-ed into place. `hooks/auto-qa` clears both files on every
  terminal state (pass, loop-protection give-up, hard give-up,
  host-compat fail, missing test runner). A v1 backward-compatibility
  fallback reads the marker's legacy integer content when
  `.verify-attempts` is absent, so migrated v1 projects keep working
  through the rollover.

### Changed

- **`/sea-roadmap` absorbs `/sea-milestone`.** A new "Adding a milestone
  to a completed project" section in `skills/sea-roadmap/SKILL.md`
  documents the clarify-questions + planner Mode A + milestone boundary
  marker + `current_milestone` state field flow. Plain `/sea-roadmap
  add "<description>"` still covers single-phase appends; the milestone
  flow triggers when the description spans multiple phases or the user
  explicitly names a new milestone.
- **`/sea-go` delegates review and debug to composition.** Step 5
  (blocked executor) now recommends `obra/superpowers:debugging` or
  `addyosmani/agent-skills:debugging` if installed. Step 6.5 (previously
  the internal reviewer call) now notes the availability of
  `addyosmani/agent-skills:code-review` if installed instead of
  invoking a SEA-owned reviewer.
- **Auto-QA retry constants.** `hooks/auto-qa` now exports
  `MAX_RETRIES=2` and `TEST_TAIL_LINES=30` as named constants at the
  top of the file with rationale comments. Block-decision messages
  reference the constant so raising the retry budget in one place
  updates every user-visible message.
- **Agent `maxTurns` rationale.** Every surviving agent
  (`executor` 30, `planner` 20, `researcher` 15, `verifier` 12) now has
  a YAML-comment rationale explaining the cap and how to tune it.

### Added

- `docs/STATE.md` v2.0.0 audit with per-file writer/reader/missing/
  corrupted details, cross-file invariants (now nine, including a new
  invariant pairing `.needs-verify` and `.verify-attempts`), and a
  "what if state.json and roadmap.md disagree?" decision matrix. The
  v1.0.0 reference is preserved verbatim as a historical subsection.
- `docs/specs/2026-04-15-scope-and-state-refactor.md` — the spec that
  drove this release.
- `docs/specs/2026-04-15-scope-and-state-refactor-journal.md` —
  phase-by-phase journal of the refactor execution.
- `docs/migration/v1-to-v2.md` — migration guide for anyone on `v1.x`.
- `CHANGELOG.md` — this file.
- `evals/suites/state/v1-to-v2-migration.sh` — verifies the schema
  migration is correct and idempotent.
- `evals/suites/hooks/auto-qa-two-file-full-cycle.sh` — regression
  for the two-file marker scheme's retry-then-give-up cycle.
- `evals/fixtures/states/v1-legacy.json` — legacy v1 state fixture for
  the migration eval. The four shared state fixtures
  (fresh/executing/blocked/planning) were bumped to `schema_version: 2`.
- Migration from v1.x section in `README.md` mapping each deleted
  command to its composition replacement.

### Fixed

- Documentation drift between `README.md`, `DESIGN.md`, and the
  filesystem (phantom counts, `[NAME]` placeholder, `Draft` status).
- Overloaded `.sea/.needs-verify` marker that encoded both "verify
  needed" and "retries so far" in the same file.
- Missing rationale for `maxTurns: 30` and the loop-protection
  threshold `2` in `hooks/auto-qa`.

### Migration

See [`docs/migration/v1-to-v2.md`](docs/migration/v1-to-v2.md) for the
full migration path — composition replacements for every deleted
command, how the state schema auto-migration works, how to verify it,
and how to recover if something goes wrong.

### Notes

- `plugin.json` version bumped from `1.0.0` → `2.0.0`.
- The `pre-scope-cut` git tag marks the pre-v2.0.0 `main` HEAD and is
  the only rollback floor. State schema migrations are one-way:
  reverting the code does not roll back a migrated `.sea/state.json`
  in a user project.
