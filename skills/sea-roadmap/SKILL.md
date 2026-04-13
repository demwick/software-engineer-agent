---
name: sea-roadmap
description: View or edit the project roadmap — list phases, add a phase, remove a phase, reorder phases, rename a phase. Read or edit the canonical roadmap file. Use when the user wants to see or change the phase list without running /sea-init again.
argument-hint: [show | add <description> | remove <N> | move <N> <to> | rename <N> <new-name>]
allowed-tools: Read, Write, Edit, Glob, Bash
---

<!--
  software-engineer-agent
  Copyright (C) 2026 demwick
  Licensed under the GNU Affero General Public License v3.0 or later.
  See LICENSE in the repository root for the full license text.
-->

# /sea-roadmap

View or modify `.sea/roadmap.md`. Announce: **"Using the roadmap skill."**

Argument: $ARGUMENTS (optional — `show` or empty to view; one of the edit verbs to modify)

## Step 1: Preconditions

If `.sea/roadmap.md` doesn't exist, tell the user:
> No roadmap found. Run `/sea-init` first.

Then stop.

Read the current roadmap. Parse it into an in-memory phase list (number, name, status, goal, scope, deliverable, dependencies).

## Step 2: Dispatch on the Verb

Parse $ARGUMENTS. If empty → default to `show`.

### `show`

Format the roadmap and print it:

```
📍 Roadmap
━━━━━━━━━━━━━━━━━━━━

✅ Phase 1: <name>   — done
⏳ Phase 2: <name>   — in-progress
📋 Phase 3: <name>   — pending
📋 Phase 4: <name>   — pending

Progress: ██████░░░░  2/4

Run /sea-go to advance.
```

No file writes for `show`.

### `add <description>`

Add a new phase at the end. Confirm with the user first — show the exact block you plan to append, then wait for approval.

Use this template:

```markdown
### Phase <N+1>: <short-name derived from description>
**Goal:** <description, rewritten as one sentence>
**Scope:** TBD — run `/sea-go` to let the planner fill this in.
**Deliverable:** TBD
**Depends on:** Phase N
**Status:** pending
```

After approval, append to `.sea/roadmap.md`. Update `state.json`'s `total_phases`.

### `remove <N>`

Refuse to remove a phase whose status is `done` — those are historical record. Show the user the phase you're about to remove and ask for confirmation. On confirm:

1. Delete the phase block from `roadmap.md`.
2. Renumber all subsequent phases (Phase N+1 → N, N+2 → N+1, …).
3. If the removed phase had a plan dir at `.sea/phases/phase-N/`, move it to `.sea/phases/archived-<timestamp>-phase-N/` rather than deleting.
4. Update `state.json`: decrement `total_phases`; if `current_phase > N`, decrement `current_phase`.

### `move <N> <to>`

Reorder: move phase N to position `to`. Refuse if either slot is a `done` phase — done phases are anchored. Swap the blocks, renumber, and renumber any phase dirs in `.sea/phases/` accordingly (use the same archive-on-rename pattern to avoid losing data if something goes wrong).

Show a diff of the old order vs new order and ask for confirmation before writing.

### `rename <N> <new-name>`

Just change the `### Phase N: <name>` header line. No confirmation needed — it's cosmetic.

## Step 3: After Any Edit

- Re-read the roadmap to make sure the file is still well-formed.
- Run `show` to display the updated roadmap to the user.
- Do NOT commit — roadmap edits are local config, not project changes.

## Rules

- **Done phases are immutable.** Never remove, reorder, or renumber a phase with status `done`.
- **Confirm before destructive edits.** `remove` and `move` always ask first, `add` asks before writing, `rename` doesn't need to.
- **Archive, don't delete.** If you have to discard a phase directory, move it to `archived-<timestamp>-…/`.
- **Keep `state.json` consistent.** Any operation that changes phase numbers must update `total_phases` and possibly `current_phase`.
- **Do not launch agents.** Roadmap edits are mechanical — no planner, no executor. If the user wants planner help to redesign phases, they should use `/sea-init` with the archive flow.
