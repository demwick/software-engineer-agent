---
name: sea-quick
description: Run a small, self-contained task without planning — straight to execute and commit. Use for typos, small fixes, single-file edits, dependency bumps, README touch-ups, rename operations. Not for anything that touches more than a couple of files or introduces new abstractions.
argument-hint: <task description>
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

<!--
  software-engineer-agent
  Copyright (C) 2026 demwick
  Licensed under the GNU Affero General Public License v3.0 or later.
  See LICENSE in the repository root for the full license text.
-->

# /sea-quick

Run a small task directly — no planning, no research, no roadmap update. Announce at the start: **"Using the quick skill for a small task."**

Task: $ARGUMENTS

## Step 1: Sanity Check

If $ARGUMENTS is empty, ask the user what they want done and stop.

Look at the task and judge: is this really small?

**Reject the shortcut** and tell the user to use `/sea-go` instead if ANY of these apply:
- Touches more than 3 files
- Introduces a new module, route, or abstraction
- Changes the data model or database schema
- Needs research ("figure out how X works")
- Is vague ("improve the performance", "clean up the code")
- Has security implications (auth, secrets, permissions)

If it's genuinely small, continue.

## Step 2: Execute

Launch the `executor` agent. Pass it:
- The task from $ARGUMENTS
- Instruction: *"This is a quick task, not a planned phase. Do the work, verify it locally if possible, and commit atomically. There is no plan file."*

Executor returns `done` or `blocked`.

- **blocked** → surface the report to the user verbatim, stop. Do not retry.
- **done** → arm auto-QA if the project already has software-engineer-agent state (next step).

## Step 3: Arm the Auto-QA Hook (conditionally)

Only if `.sea/` **already exists** in the project, arm the Stop hook:

```bash
echo 0 > .sea/.needs-verify
```

If the project is NOT software-engineer-agent-initialized, skip this — quick tasks never create `.sea/` themselves.

When armed, the Stop hook auto-runs the project's test runner (via `scripts/detect-test.sh`). On pass, it clears the marker and lets Claude stop. On fail, it returns a `block` decision so Claude auto-retries the fix (up to 2 retries).

You do NOT invoke the verifier agent manually. Trust the hook.

## Step 4: Report

Once done, write a one-sentence summary:

> Quick task done: <what>. Commit: <short-sha>.

## Rules

- **No plan files, no roadmap mutation.** Do not write to `.sea/roadmap.md` or create phase dirs — quick tasks don't affect the roadmap. The `.needs-verify` marker in Step 3 is the only exception, and only in already-initialized projects.
- **One commit only.** If the task splits naturally into multiple commits, it wasn't a quick task — stop and suggest `/sea-go`.
- **No scope creep.** Executor stays strictly within the user's request. If it notices something else wrong, note it in the report and move on — don't fix it.
- **No /sea-go redirect loop.** If you rejected the task as too-big, don't silently promote to /sea-go. The user runs that explicitly.
