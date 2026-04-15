---
name: sea-quick
description: Run a small, self-contained engineering task immediately — no planning phase, straight to executor + atomic commit + auto-QA. **Use this skill aggressively whenever** the user asks for any of "fix X", "quick fix", "small change", "typo", "bump dependency", "rename X", "just change X to Y", "update README", "small refactor", or any task that reads as "one commit's worth of work". Also use when /sea-diagnose has just flagged 1-3 small priority actions — the skill will auto-detect the recent diagnose and offer to fix the top action. **Do not use** for tasks touching >3 files, introducing new modules/abstractions, or having security implications — those go to /sea-go.
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

## Step 1: Resolve the Task

If `$ARGUMENTS` is non-empty, use it directly — skip to the size check below.

If `$ARGUMENTS` is **empty**, check for a recent diagnose report before asking the user:

1. Does `.sea/diagnose.json` exist?
2. Is its `generated` timestamp within the last 30 minutes?
3. Does it have a non-empty `priority_actions` array?

If all three are yes, propose fixing the top priority action:

> *"No task given, but diagnose <N> minutes ago flagged 3 priority actions:*
>   1. *<first action>*
>   2. *<second action>*
>   3. *<third action>*
> *Want me to fix #1 (or all three in one commit)? (yes/no/other)"*

Wait for the user's answer. Acceptable responses:
- `yes` or `1` → treat the first action as the task
- `all` → bundle all actions (reject later if it breaks size rules)
- any other text → treat that as the task description
- `no` → ask *"What would you like done?"* and stop

If there's **no recent diagnose**, fall back to asking the user what they want and stop.

## Step 2: Size Check

Look at the resolved task and judge: is this really small?

**Reject the shortcut** and tell the user to use `/sea-go` instead if ANY of these apply:
- Touches more than 3 files
- Introduces a new module, route, or abstraction
- Changes the data model or database schema
- Needs research ("figure out how X works")
- Is vague ("improve the performance", "clean up the code")
- Has security implications (auth, secrets, permissions)

If it's genuinely small, continue.

## Step 3: Execute

Launch the `executor` agent. Pass it:
- The resolved task (from `$ARGUMENTS` or the diagnose priority action picked in Step 1)
- Instruction: *"This is a quick task, not a planned phase. Do the work, verify it locally if possible, and commit atomically. There is no plan file."*

Executor returns `done` or `blocked`.

- **blocked** → surface the report to the user verbatim, stop. Do not retry.
- **done** → arm auto-QA if the project already has software-engineer-agent state (next step).

## Step 4: Arm the Auto-QA Hook (conditionally)

Only if `.sea/` **already exists** in the project, arm the Stop hook:

```bash
echo 0 > .sea/.needs-verify
```

If the project is NOT software-engineer-agent-initialized, skip this — quick tasks never create `.sea/` themselves.

When armed, the Stop hook auto-runs the project's test runner (via `scripts/detect-test.sh`). On pass, it clears the marker and lets Claude stop. On fail, it returns a `block` decision so Claude auto-retries the fix (up to 2 retries).

You do NOT invoke the verifier agent manually. Trust the hook.

## Step 5: Report

Once done, write a one-sentence summary:

> Quick task done: <what>. Commit: <short-sha>.

If the task came from `.sea/diagnose.json` priority_actions, also suggest re-running diagnose to confirm the fix and surface the next action:

> Re-run `/sea-diagnose` to verify and see the next priority.

## Rules

- **No plan files, no roadmap mutation.** Do not write to `.sea/roadmap.md` or create phase dirs — quick tasks don't affect the roadmap. The `.needs-verify` marker in Step 4 is the only exception, and only in already-initialized projects.
- **One commit only.** If the task splits naturally into multiple commits, it wasn't a quick task — stop and suggest `/sea-go`.
- **No scope creep.** Executor stays strictly within the user's request. If it notices something else wrong, note it in the report and move on — don't fix it.
- **No /sea-go redirect loop.** If you rejected the task as too-big, don't silently promote to /sea-go. The user runs that explicitly.

## When NOT to Use

- Task touches more than 3 files → use `/sea-go` (deserves a planned phase)
- Task introduces a new module, route, or abstraction → `/sea-go`
- Task changes a data model or database schema → `/sea-go`
- Task is vague ("improve performance", "clean up") → `/sea-diagnose` first, then `/sea-go`
- Task has security implications (auth, secrets, permissions) → `/sea-go`
- Task is a bug fix that can't be captured in a single test → `/sea-go` (planner enforces Prove-It splitting)
- The user is mid-phase in `/sea-go` → finish that phase first, then quick

## Related

- `/sea-diagnose` — produces the priority actions this skill auto-detects in Step 1
- `/sea-go` — where to escalate if a quick task turns out to be larger
- **Native `git revert`** — to roll back a quick task that turned out wrong (SEA no longer ships a revert wrapper in v2.0.0; the migration guide has the details)
- **External**: `obra/superpowers:debugging` / `addyosmani/agent-skills:debugging` — when a quick task fails unexpectedly and needs triage
- **External**: `agent-skills:code-simplification` — paired well with simple refactor quick tasks
