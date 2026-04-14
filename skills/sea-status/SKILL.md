---
name: sea-status
description: Show the current project state — active phase, roadmap progress, last session, last commit. Read-only. Use when the user asks "where am I", "what's the status", "what did I do last time", or as a quick check before running /sea-go.
argument-hint: [empty]
allowed-tools: Read, Glob, Bash
---

<!--
  software-engineer-agent
  Copyright (C) 2026 demwick
  Licensed under the GNU Affero General Public License v3.0 or later.
  See LICENSE in the repository root for the full license text.
-->

# /sea-status

Report the current project state in a compact, scannable format. Announce: **"Using the status skill."**

No agent is invoked — this skill is pure read-and-format.

## Step 1: Check What Exists

Look for these files in order:

1. `.sea/state.json` — the canonical state
2. `.sea/roadmap.md` — phase list
3. `.sea/diagnose.json` — latest health report (optional)
4. `.sea/phases/phase-<current>/plan.md` — active phase plan (optional)

If none exist, tell the user:
> No project state found. Run `/sea-init` to bootstrap.

Then stop.

## Step 2: Read State

Parse `.sea/state.json`. Extract: `mode`, `current_phase`, `total_phases`, `last_session`, `last_commit`.

Parse `.sea/roadmap.md`. Count phases by status: `done`, `in-progress`, `pending`.

If `.sea/diagnose.json` exists, read its `generated` timestamp and overall status.

If `.sea/.last-verify.log` exists, read its mtime (file modification time) and the last ~10 lines. Parse them lightly to surface:
- When the last test run happened (human-readable: "2m ago")
- Pass/fail from the log tail (look for "passed", "failed", "FAIL", "Error", non-zero exit mention)
- The test command if still recoverable from the log header

Never re-run the tests yourself — status is read-only. Stale logs are better than slow status.

## Step 3: Git Context (Quick)

Run `git log --oneline -3` and `git status --short` to get the last three commits and any uncommitted changes. Fail silently if not a git repo.

## Step 4: Format the Report

```
📍 Project Status
━━━━━━━━━━━━━━━━━━━━━━━

Mode:         <from-scratch | finish-existing>
Progress:     <done>/<total> phases complete  [<bar>]

🎯 Active Phase
  Phase <N>: <name>
  Status: <pending | in-progress>
  Plan: <✓ exists | — not yet planned>

📋 Roadmap
  ✅ Phase 1: <name>
  ✅ Phase 2: <name>
  ⏳ Phase 3: <name>  ← current
  📋 Phase 4: <name>
  📋 Phase 5: <name>

🕒 Last Session
  When: <human-readable, e.g. "3 hours ago">
  Last commit: <short-sha> <subject>

🩺 Last Diagnose
  <date> — <overall status>, or "never run"

🧪 Last Test Run
  <e.g. "2m ago — pytest: 12 passed"> | "never run"

🔧 Working Tree
  <clean | N files modified, M staged>

Next: /sea-go
```

The progress bar is 10 chars: `██████░░░░` style. Round down.

## Rules

- **Read-only.** Never write to `.sea/`, never commit, never modify anything.
- **Fail soft.** If a file is missing or malformed, note it in the report — don't crash the whole skill.
- **Compact.** This skill should run in under a second and return a single screen of output. No long prose.
- **No agent calls.** Everything here is file reads and git commands; launching researcher/planner/etc would be wasteful.
- **Human-readable timestamps.** "3 hours ago" beats "2026-04-14T05:21:00Z" for the user-facing line. The raw ISO value stays in state.json.
