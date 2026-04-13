<!--
  software-engineer-agent
  Copyright (C) 2026 demwick
  Licensed under the GNU Affero General Public License v3.0 or later.
  See LICENSE in the repository root for the full license text.
-->

# State File Layout

This document describes what software-engineer-agent writes inside a project's `.sea/` directory and how each file is used. You don't need to create any of these by hand — `/sea-init` generates them. This doc is the reference when you want to inspect, tweak, or debug state.

## Directory Layout

```
<project-root>/
└── .sea/                # added to .gitignore automatically by /sea-init
    ├── state.json               # canonical runtime state
    ├── roadmap.md               # human-readable phase list
    ├── diagnose.json            # latest health report (if /sea-diagnose has run)
    ├── .needs-verify            # transient marker — triggers the auto-QA hook
    ├── .last-verify.log         # last test-runner output (written by auto-qa)
    └── phases/
        ├── phase-1/
        │   ├── plan.md          # planner's output for this phase
        │   └── summary.md       # executor's completion note
        ├── phase-2/
        │   ├── plan.md
        │   └── progress.json    # in-flight task progress (deleted on phase complete)
        └── archived-YYYYMMDD-phase-N/   # old plans, never deleted
```

## `state.json`

Canonical runtime state. Every command that mutates state updates this file. Schema:

```json
{
  "schema_version": 1,
  "mode": "from-scratch",
  "created": "2026-04-14T00:12:33Z",
  "current_phase": 2,
  "total_phases": 5,
  "last_session": "2026-04-14T03:47:01Z",
  "last_edit":    "2026-04-14T03:47:01Z",
  "last_commit":  "a1b2c3d"
}
```

| Field | Written by | Purpose |
|-------|-----------|---------|
| `schema_version` | `/sea-init` | Integer. Bump when state-shape changes; readers run migrations if older. |
| `mode` | `/sea-init` | `from-scratch` or `finish-existing` — affects /sea-go pipeline defaults |
| `created` | `/sea-init` | ISO-8601 UTC timestamp of initialization |
| `current_phase` | `/sea-go`, `/sea-roadmap` | Number of the active phase |
| `total_phases` | `/sea-init`, `/sea-roadmap` | Total phases in the roadmap |
| `last_session` | `/sea-go` end, `SessionStart` | Last time a command ran |
| `last_edit` | `PostToolUse` hook (`state-tracker`) | Last time any file was edited in this project by Claude |
| `last_commit` | `/sea-go` end, `/sea-quick` end | Short SHA of the most recent software-engineer-agent commit |

## `roadmap.md`

Human-readable phase list. The planner writes it, the user can hand-edit it, and `/sea-roadmap` edits it programmatically. Format:

```markdown
# Project Roadmap

## Project: <name>
## Created: <ISO date>
## Status: in-progress

## Phases

### Phase 1: <short name>
**Goal:** <one sentence>
**Scope:** <bullet list>
**Deliverable:** <what you end with>
**Depends on:** none | Phase X
**Status:** done | in-progress | pending

### Phase 2: ...
```

`Status` transitions: `pending` → `in-progress` → `done`. Once a phase is `done`, the `/sea-roadmap` skill refuses to remove or reorder it.

## `phases/phase-N/plan.md`

One plan file per phase, written by the `planner` agent in Mode B (Phase Planning) and consumed by the `executor`. Format:

```markdown
# Phase N Plan: <name>

## Context
<2-3 sentences>

## Complexity
trivial | medium | complex

## Pipeline
<describes which agents will be used>

## Tasks

### Task 1: <short name>
- **What:** <one sentence>
- **Files:** path1, path2 (new | modified)
- **Steps:**
  1. ...
  2. ...
- **Verification:** <exact command, expected output>
- **Commit:** `type(scope): message`

### Task 2: ...
```

If the planner cannot decide something, it inserts `[[ ASK: question ]]` markers. The `/sea-go` skill stops and surfaces these to the user before calling the executor.

## `phases/phase-N/progress.json` (transient)

Written by the executor after each successful task commit so the phase can resume after a crash, context reset, or `STATUS: blocked` exit.

```json
{
  "phase": 2,
  "current_task": 3,
  "completed_tasks": [1, 2],
  "last_commit": "a1b2c3d",
  "updated": "2026-04-14T05:21:00Z"
}
```

`/sea-go` checks this file before launching the executor:
- **Present** → resume context: skip `completed_tasks`, restart at `current_task`.
- **Absent** → fresh start at task 1.

Deleted automatically when the phase completes — `summary.md` becomes the historical record.

## `phases/phase-N/summary.md`

Written after the phase completes successfully. Short, appendable, human-readable:

```markdown
# Phase N Summary

Completed: <ISO now>
Commits: <count>  (<first-sha>..<last-sha>)
Files touched: <list>

Notes:
<2-3 sentences on what shipped, any deviations from the plan, anything the user should know>
```

## `diagnose.json`

Latest output from `/sea-diagnose`. Schema:

```json
{
  "generated": "2026-04-14T05:10:00Z",
  "focus": "all",
  "tests":    { "status": "warn", "findings": ["..."] },
  "errors":   { "status": "pass", "findings": [] },
  "security": { "status": "fail", "findings": ["..."] },
  "priority_actions": [
    "Add rate limiting to POST /api/login (src/routes/auth.ts:42)",
    "..."
  ]
}
```

Each section's `status` is one of `pass`, `warn`, `fail`. `/sea-status` reads this file to show the last audit result in its header.

## `.needs-verify` (transient)

A marker file created by `/sea-go` and `/sea-quick` after the executor finishes. Contains a single integer: the retry count (starts at `0`).

The `Stop` hook (`hooks/auto-qa`) checks for this file when Claude finishes responding:

1. No marker → hook exits 0, Claude stops normally
2. Marker exists → hook runs `scripts/detect-test.sh`, then runs the detected test command
3. Pass → marker is deleted, Claude stops
4. Fail → marker's counter is incremented, hook returns `{"decision": "block", "reason": "..."}`, Claude auto-retries the fix
5. After 2 failed retries → marker is deleted, hook returns a block with a "give up, report to user" reason

This file is transient: never commit it, never rely on its existence, never edit it by hand.

## `.last-verify.log` (transient)

Raw stdout + stderr of the last test run, written by `hooks/auto-qa`. Overwritten every run. Useful for debugging when auto-QA reports a failure — you can open it directly instead of re-running tests manually.

## Cross-Session Memory (NOT in `.sea/`)

Each subagent has its own `MEMORY.md` managed by the platform, stored under `.claude/agent-memory/<agent-name>/MEMORY.md`. This is distinct from `.sea/`:

| Location | Lifetime | Scope | Contents |
|----------|---------|-------|----------|
| `.sea/` | Project | Per-project runtime state | Roadmap, phase plans, current state |
| `.claude/agent-memory/<agent>/` | Agent, per project | Accumulated across sessions | Patterns, decisions, known pitfalls |

The platform loads the first 25KB of each `MEMORY.md` into the corresponding subagent at startup — we do not hand-manage this.

## Gitignore

`/sea-init` appends the following to `.gitignore` if it isn't already there:

```
# software-engineer-agent runtime state
.sea/
```

`.claude/agent-memory/` is NOT gitignored by default — agent learnings can legitimately be shared via git (they never contain secrets if the agent follows its rules). Decide per project whether to commit them.
