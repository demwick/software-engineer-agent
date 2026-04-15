---
name: sea-go
description: Advance a SEA-managed project by exactly one phase — read roadmap, pick next pending phase, plan it if needed, run executor, let the auto-QA Stop hook verify. **This is the main SEA command** — use it aggressively whenever the user says any of "continue", "go", "next step", "keep going", "advance", "run the next phase", "do the next thing", "work on the project", or whenever the user has a SEA project in progress and wants forward motion. Also the default response when the user says "continue where we left off" in a session with an active .sea/state.json.
argument-hint: [optional phase number or "next"]
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

<!--
  software-engineer-agents
  Copyright (C) 2026 demwick
  Licensed under the GNU Affero General Public License v3.0 or later.
  See LICENSE in the repository root for the full license text.
-->

# /sea-go

Advance the project by one phase. Announce at the start: **"Using the go skill to run the next phase."**

Argument: $ARGUMENTS (optional — a phase number, or empty = next pending phase)

## Step 1: Preconditions

1. Check `.sea/state.json` and `.sea/roadmap.md` exist.
   - If missing → tell the user *"No project state found. Run /sea-init first."* and stop.
2. Read both files.

## Step 2: Pick the Phase

- If $ARGUMENTS is a number → use that phase (error out if it's already done or doesn't exist).
- Otherwise → use the first phase whose status is `pending` or `in-progress`.
- If every phase is `done` → celebrate briefly and tell the user the project is complete. Stop.

Show the user: *"Starting Phase N: <name>"* before continuing.

## Step 3: Plan the Phase (if no plan yet)

Check `.sea/phases/phase-N/plan.md`.

- **Plan exists** → read it, skip to Step 4.
- **No plan** → launch the `planner` agent in **Mode B (Phase Planning)**. Pass the roadmap entry for Phase N as context. The planner writes `.sea/phases/phase-N/plan.md`.

Read the plan. If it contains any `[[ ASK: ... ]]` markers, surface those questions to the user and stop. Do not guess.

## Step 4: Choose the Pipeline

The plan's "Complexity" line tells you which pipeline to run:

| Complexity | Pipeline |
|------------|----------|
| trivial | `executor` only |
| medium | `executor` only (verifier runs via Stop hook) |
| complex | `researcher` → `executor` (verifier runs via Stop hook) |

For **complex** only: before calling executor, launch the `researcher` agent with the plan's context section to gather any deep knowledge the executor will need. Read the report yourself — do not dump it to the user.

## Step 4.5: Risk gate inspection

After choosing the pipeline and BEFORE launching the executor:

1. Read the plan's `risk_gates` section.
2. If `risk_gates` is **missing**, the plan is pre-v2.1.0. Emit a warning:
   *"WARNING: plan has no risk_gates section (pre-v2.1.0); running without
   gate checks."* Proceed to Step 5.
3. If `risk_gates: []`, the planner asserted no gates. Proceed.
4. If `risk_gates` contains entries, surface each to the user:

   ```
   Phase N contains <count> risk gate(s):
     Gate 1 — task <id> (<kind>): <reason>
       Confirmation prompt: <text>
     Gate 2 — task <id> (<kind>): <reason>
       Confirmation prompt: <text>

   Review the gates. Confirm to proceed, or cancel to revise the plan.
   The executor will pause at each gate task and request individual
   confirmation before running it.
   ```

5. Wait for **explicit** user confirmation. Do not accept ambiguous
   responses ("sounds good", "ok"). Require "confirm" or an equivalent
   specific acknowledgment. On any non-confirmation, surface the plan
   path and stop.

## Step 5: Execute

Before launching, check `.sea/phases/phase-N/progress.json`:

- **Exists** → read it. The phase was interrupted mid-execution. Tell the user *"Resuming Phase N from task <current_task> (tasks <completed_tasks> already done)."*
- **Absent** → fresh start.

Launch the `executor` agent. Pass it:
- The path to the plan file
- The plan's context section
- Any researcher findings (for complex phases)
- **Resume context** if `progress.json` existed: *"Skip tasks <completed_tasks>; resume at task <current_task>."*

Wait for executor to finish. It returns `STATUS: done`, `STATUS: blocked`, or `STATUS: gate`.

- **blocked** → surface executor's report to the user verbatim, mark the phase `in-progress` in state.json, and stop. If `obra/superpowers:debugging` or `addyosmani/agent-skills:debugging` is installed, recommend invoking it for structured triage. Otherwise surface the executor's blocked report as-is and let the user decide. SEA does not own debug methodology in v2.0.0 — compose with specialized plugins.
- **gate** → run "Resume after gate" (below), then re-launch executor.
- **done** → arm auto-QA (next step).

### Resume after gate

If the executor returns `STATUS: gate`:

1. Read `.sea/phases/phase-N/gate-pending.json`.
2. Surface the `confirmation_prompt` to the user with the gate `kind`
   and `reason`.
3. Wait for **specific** confirmation ("confirm" or explicit task
   acknowledgment — no ambiguous responses).
4. **On confirmation:** re-launch the executor with resume context
   *"Resume from gate at task <id>. User confirmed."* The executor
   deletes the marker and proceeds.
5. **On non-confirmation:** mark the phase `blocked` in state, leave
   the marker in place, and tell the user:
   *"Phase N paused at task <id>. Delete `.sea/phases/phase-N/gate-pending.json`
   to unblock, or run `/sea-quick 'modify task <id>'` to revise."*

Do not auto-confirm gates. Do not skip the re-launch. The human loop
is the point.

## Step 6: Arm the Auto-QA Hook

Before your response ends, arm the auto-QA marker. In v2.0.0 the marker is **existence-only** — content is ignored. The retry counter lives in a sibling file `.sea/.verify-attempts` that `hooks/auto-qa` writes atomically.

```bash
mkdir -p .sea && : > .sea/.needs-verify
```

Do **not** write a number into `.needs-verify`; the hook no longer reads it. Do **not** create `.verify-attempts` yourself either — the hook owns it. Just touch the marker.

The `Stop` hook (`hooks/auto-qa`) will detect the marker, run the project's test runner, and either clear both files (pass) or return a `block` decision and bump `.verify-attempts` so Claude auto-fixes (up to 2 retries). Do **not** invoke the verifier agent manually — the hook handles it.

For the full protocol — retry counter semantics, host-compat post-check, failure recovery format, test runner detection order — see `references/auto-qa-protocol.md`.

## Step 6.5: Optional external review (composition)

v2.0.0 removed the internal reviewer in favor of composition. After auto-QA passes, if `addyosmani/agent-skills:code-review` is installed, note its availability in the phase summary report so the user can opt in. Do **not** invoke a reviewer agent directly — SEA no longer owns a reviewer in v2.0.0. If no external review skill is installed, skip this step silently.

## Step 7: Update State and Report

On verifier success:

1. Update `.sea/state.json` via the `state-update.sh` helper — **never write state.json directly with Write/Edit**. The helper jq-merges, preserves required fields (`schema_version`, `mode`, `created`), auto-refreshes `last_session`, and validates the result:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/state-update.sh" \
       current_phase=<N+1> \
       last_commit=<short-sha-of-HEAD>
   ```
   Pass any additional fields as extra `KEY=VALUE` args. JSON-parseable values (numbers, booleans, arrays) keep their type; everything else becomes a string.
2. Update `.sea/roadmap.md`: mark Phase N as `done`.
3. Write a short summary to `.sea/phases/phase-N/summary.md`:
   ```markdown
   # Phase N Summary
   Completed: <ISO now>
   Commits: <count>
   Files touched: <list>
   Notes: <2-3 sentences>
   ```
4. Tell the user:
   > Phase N complete. Next: Phase N+1 "<name>". Run `/sea-go` when ready.

## Rules

- **Do not skip the planner** for medium/complex phases, even if the phase "looks obvious". The plan is the contract the executor works against.
- **Do not run verifier yourself** — the Stop hook does it. Calling it manually creates a double-verification loop.
- **Respect blockers** — if executor reports `blocked`, do not try to unstick it; surface it to the user.
- **One phase per /sea-go invocation.** Do not chain phases.
- **Never delete or rewrite commits** the executor made. If something's wrong, the next phase or a `/sea-quick` fixes it.

## When NOT to Use

- No `.sea/` exists yet → use `/sea-init` first
- All phases are `done` → suggest `/sea-roadmap add "<next milestone>"` to extend the roadmap
- The user wants a single small fix that doesn't fit a phase → use `/sea-quick`
- A phase is currently blocked due to a real failure → invoke an external debugging skill (`obra/superpowers:debugging` or `addyosmani/agent-skills:debugging` if installed) to triage first
- The user only wants to inspect state without advancing → use `/sea-status`
- The user wants to add or remove phases without running them → use `/sea-roadmap`

## Related

- `/sea-status` — check progress before running this command
- `/sea-init` — creates the roadmap this command consumes
- `/sea-quick` — for small touchups discovered mid-phase
- **External**: `agent-skills:incremental-implementation` + `agent-skills:test-driven-development` — pair well with the executor when installed
- **External**: `superpowers:executing-plans` — alternative executor for very long phases
- **External**: `addyosmani/agent-skills:code-review` — v2.0.0 delegates post-phase review to this skill (see Step 6.5)
- **External**: `obra/superpowers:debugging` / `addyosmani/agent-skills:debugging` — v2.0.0 delegates blocked-executor triage here (see Step 5)
- **External**: `addyosmani/agent-skills:shipping` — v2.0.0 delegates pre-merge gate work here
