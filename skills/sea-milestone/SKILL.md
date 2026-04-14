---
name: sea-milestone
description: Extend a completed (or in-progress) SEA project with a new milestone — a fresh chunk of phases for a new direction like "add a web UI", "V1.1 cleanup", or "migrate to Postgres". Unlike /sea-init which archives old state, this **preserves history** and appends new phases to the existing roadmap. **Use this skill whenever** the user says any of "add a milestone", "next milestone", "V2 of this", "add feature X to the finished project", "plan the next chunk", "extend the roadmap", "what's next after MVP", or whenever the MVP has shipped and the user describes a new direction. Preferred over /sea-init re-run whenever the existing project is a valid foundation.
argument-hint: <milestone description>
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

<!--
  software-engineer-agent
  Copyright (C) 2026 demwick
  Licensed under the GNU Affero General Public License v3.0 or later.
  See LICENSE in the repository root for the full license text.
-->

# /sea-milestone

Announce: **"Using the milestone skill to add a new milestone to this project."**

Argument: $ARGUMENTS — a one-sentence description of the new milestone (e.g. *"add a FastAPI web UI on top of the existing CLI"*).

## Step 1: Preconditions

1. If `.sea/state.json` or `.sea/roadmap.md` is missing, tell the user *"No project found. Run /sea-init first."* and stop.
2. If `$ARGUMENTS` is empty, ask the user: *"What's the next milestone? (one sentence)"* and wait.
3. Read `state.json` and `roadmap.md`. Note the current highest phase number — call it `LAST`.

## Step 2: Clarify the Milestone

Ask the user 2–3 quick questions, one topic at a time (use `AskUserQuestion` when available):

- What's the goal of this milestone in one sentence?
- Which existing code does it build on vs. replace?
- Any stack additions needed? (new dependency, new service, new runtime)
- Scope boundary — what's explicitly NOT in this milestone?

If `$ARGUMENTS` already answers some of these, skip them.

## Step 3: Plan the Milestone

Launch the `planner` agent in **Mode A (Roadmap Planning)** with:
- Existing roadmap context (so it doesn't duplicate earlier phases)
- Clarified milestone goal and scope
- Instruction: *"Output only the new phases — do not restate prior phases. Phase numbers should start at <LAST+1>. Each phase: goal, scope, deliverable, depends-on. 1–5 phases. Format as markdown matching the existing roadmap."*

Planner returns a block of new phase entries.

## Step 4: Append to Roadmap

Read `.sea/roadmap.md`. If there's no milestone boundary marker yet, add one right above the new phases:

```markdown
---

## Milestone 2: <short name>
Started: <ISO date>
Goal: <one sentence>

### Phase <LAST+1>: ...
...
```

If this is the project's first explicit milestone, also retro-mark the earlier phases. Insert above Phase 1:

```markdown
## Milestone 1: <mode-derived name, e.g. "MVP">
Started: <created timestamp from state.json>
```

Append the planner's new phase block beneath the new milestone header. Preserve every earlier phase verbatim — do not renumber, do not remove, do not re-touch existing status lines.

## Step 5: Update State (via helper)

Use `scripts/state-update.sh` — never raw-write state.json:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/state-update.sh" \
    current_phase=<LAST+1> \
    total_phases=<LAST + new_phase_count> \
    current_milestone=2
```

The helper jq-merges and preserves `schema_version`, `mode`, `created`, and refreshes `last_session`. If `current_milestone` wasn't in the schema before, it gets added as a new optional field — `state-update.sh` treats unknown keys permissively.

## Step 6: Show and Hand Off

Print a short summary to the user:

```
Milestone 2 added: "<goal>"
- New phases: <LAST+1> ... <LAST+count>
- Total phases: <new total>
- Plan files: not yet written — /sea-go will generate them per phase

Run /sea-go when ready to start Phase <LAST+1>.
```

## Rules

- **Never archive or overwrite.** Unlike `/sea-init`, milestone always preserves history. Done phases stay done.
- **Do not renumber existing phases.** New phases pick up where the last one left off.
- **Do not call executor.** Milestone is planning-only, same as init.
- **Do not auto-commit.** Roadmap edits are runtime state, not project code.
- **One milestone per invocation.** If the user describes two directions, ask which one to tackle first and defer the other to a second `/sea-milestone` call.
- **Respect scope discipline.** If the described work doesn't fit a milestone (e.g. it's a single fix), suggest `/sea-quick` and stop. If it's bigger than ~5 phases, suggest splitting and stop.

## When NOT to Use

- No `.sea/` exists at all → `/sea-init` first
- The user described a single small fix → `/sea-quick "<task>"`
- The user wants only one extra phase → `/sea-roadmap add "<description>"` is lighter
- The user wants to fundamentally restart with a different stack → `/sea-init` (which archives the old state)
- The current milestone has unfinished phases → finish them with `/sea-go` first, or explicitly confirm parallel milestones

## Related

- `/sea-init` — the right tool when archiving + fresh start is desired (this skill's opposite)
- `/sea-roadmap add` — lighter alternative for adding a single phase without invoking planner
- `/sea-go` — natural next step to start the first phase of the new milestone
- `/sea-status` — see the new milestone reflected in the progress display
- `/sea-ship` — pre-merge gate before declaring the previous milestone done and starting this one
