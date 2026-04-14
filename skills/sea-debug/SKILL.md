---
name: sea-debug
description: Systematic triage when something breaks — reproduces the failure, isolates the minimal repro, forms ranked hypotheses, tests them cheapest-first, identifies the root cause, and proposes a minimum fix. Launches the debugger subagent (Haiku, read-only + bash). Writes evidence to .sea/debug/session-N/. **Use this skill aggressively whenever** the user says any of "it's broken", "why is X failing", "debug this", "help me fix this", "what's wrong", "this doesn't work", "something is off", "why does X happen", or whenever /sea-go executor returns STATUS: blocked. Read-only with respect to source code — diagnosis only, never patches directly.
argument-hint: [optional description of the failure]
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write
---

<!--
  software-engineer-agent
  Copyright (C) 2026 demwick
  Licensed under the GNU Affero General Public License v3.0 or later.
  See LICENSE in the repository root for the full license text.
-->

# /sea-debug

Announce: **"Using the debug skill to triage this failure."**

Argument: $ARGUMENTS — optional one-sentence description of what's broken. If empty, the skill will ask.

## Step 1: Resolve the Failure Context

If `$ARGUMENTS` is non-empty, use it as the failure description.

If `$ARGUMENTS` is empty, check for recent failure signals before asking:

1. `.sea/.last-verify.log` exists and mtime < 10 minutes old → *"Last auto-QA run failed X minutes ago — triage that?"*
2. `.sea/phases/phase-*/` has a phase with `progress.json` still present (meaning executor was mid-phase and didn't finish cleanly) → offer to triage the blocked phase
3. Neither signal → ask: *"What failed? Paste the error message or describe what's broken."* and stop.

## Step 2: Create the Session Directory

```bash
# Find next session number
next=$(ls -d .sea/debug/session-* 2>/dev/null | wc -l | tr -d ' ')
next=$((next + 1))
mkdir -p ".sea/debug/session-$next"
```

Store the session number in a variable — the debugger agent will write to that path.

## Step 3: Seed the Evidence

Before launching the debugger, write whatever you already have to the session directory:

- `error.log` — paste the error, stacktrace, failing command from $ARGUMENTS or `.sea/.last-verify.log`
- A one-line `context.md` noting: repo SHA, clean/dirty working tree, which phase is active if any

This gives the debugger a head start — it doesn't have to re-discover evidence you already have in context.

## Step 4: Launch the Debugger Agent

Launch the `debugger` agent with:
- The session directory path
- The failure description / error log path
- The list of recently touched files (`git diff --name-only HEAD~5..HEAD` if relevant)
- Instruction: *"Run the five-phase triage. Write all intermediate files to the session directory. Return the final JSON verdict."*

The debugger returns one of:

```json
{"status": "diagnosed", "session": N, "confidence": "high|medium|low", "root_cause_path": "..."}
{"status": "non-reproducible", "session": N, "conditions_path": "..."}
{"status": "inconclusive", "session": N, "hypotheses_tested": N, "report_path": "..."}
```

## Step 5: Surface the Diagnosis and Route

**diagnosed (high confidence)**:
> ✅ Root cause identified. <one-line summary>
> See `<root_cause_path>` for the full diagnosis and recommended fix.
>
> The recommended fix is a Prove-It-pattern pair (failing test + fix).
> Run `/sea-quick "implement fix from session-N root-cause.md"` to apply.

**diagnosed (medium/low confidence)**:
> ⚠️ Probable cause identified, confidence: <level>. <one-line summary>
> See `<root_cause_path>`. The debugger recommends testing the fix in isolation before integrating.

**non-reproducible**:
> ⚠️ Could not reproduce the failure deterministically. See `<conditions_path>` for the conditions observed.
> Options: (a) gather more repro data, (b) ship a defensive change with logging, (c) add monitoring and revisit. Do not ship a speculative fix for a non-reproducible bug.

**inconclusive**:
> ❌ Triage exhausted <N> hypotheses without a confirmed root cause. See `<report_path>` for what was tried.
> Recommend: share the report with the user, gather fresh context, re-run `/sea-debug` with more specific input, or escalate to a human reviewer.

## Step 6: Do Not Auto-Fix

Like `/sea-review`, this skill separates diagnosis from remediation. The debugger is strictly read-only with respect to source code. The user (or executor via `/sea-quick`) applies the fix. This separation:

- Keeps the triage audit trail clean
- Prevents cascading automated changes from a wrong diagnosis
- Preserves the Prove-It discipline (test commit → fix commit)

## Rules

- **One session per invocation.** Don't chain multiple debuggers in one call.
- **Never auto-apply a recommended fix.** The skill's output is a report, not a diff.
- **Session directories are permanent.** Never delete old `session-*/` dirs — they're history. Old sessions help diagnose similar failures later.
- **Escalate on deep repo damage.** If the debugger reports the working tree is corrupted (missing files, broken git state), stop and tell the user to check before running any automated fix.
- **Respect the _common.md stop-the-line rule.** Do not keep adding features or running other skills while a triage is in progress — fix the bug first, then resume.
