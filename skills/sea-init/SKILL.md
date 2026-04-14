---
name: sea-init
description: Bootstrap a project — works for both blank directories (new MVP from idea) and existing codebases (analyze gaps and build a completion roadmap). Use when the user says "let's start this project", "I have an idea", "analyze this repo", or when no `.sea/` exists yet.
argument-hint: [optional project description or goal]
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

<!--
  software-engineer-agent
  Copyright (C) 2026 demwick
  Licensed under the GNU Affero General Public License v3.0 or later.
  See LICENSE in the repository root for the full license text.
-->

# /sea-init

You are bootstrapping a project. First figure out which mode applies, then follow it. Announce at the start: **"Using the init skill to bootstrap this project."**

Initial argument (may be empty): $ARGUMENTS

## Step 1: Detect Mode

Run these checks in order:

1. Is `.sea/` already present? → **state already exists, do NOT overwrite.** Ask the user whether to re-run init (which will archive the old state) or to use `/sea-status` instead. Stop here unless they confirm.
2. Is the current directory effectively empty? (only README, LICENSE, .git, or nothing) → **Mode A: From-Scratch MVP**
3. Otherwise → **Mode B: Finish Existing Project**

## Mode A: From-Scratch MVP

Goal: turn an idea into a scaffolded project with a phased roadmap.

1. **Clarify the idea.** Ask the user, one topic at a time, using the `AskUserQuestion` tool when possible:
   - What are you building? (one sentence)
   - Who is the target user?
   - What are the 3 must-have features for the MVP?
   - Any stack preference, or do you want a recommendation?
   - Any existing spec, design, or reference to link?

   If $ARGUMENTS already answers some of these, skip those questions.

2. **Propose a stack.** Based on answers, recommend a minimal stack (2-3 options only, lead with your pick). Wait for confirmation before scaffolding.

3. **Scaffold.** Create the project skeleton: minimal files to `npm install && npm run dev` (or equivalent). Do not over-engineer. No auth boilerplate unless it's in the MVP. No CI yet.

4. **Build the roadmap.** Launch the `planner` agent in **Mode A (Roadmap Planning)** with the clarified idea and stack. It returns a 3-7 phase roadmap.

5. **Write state files** (see "State Files to Create" below).

6. **Show the roadmap** to the user, confirm, and tell them: *"Run /sea-go to start Phase 1."*

## Mode B: Finish Existing Project

Goal: understand what exists, find the gaps, prioritize, and produce a completion roadmap.

1. **Launch the `researcher` agent** with the prompt: *"Analyze this codebase. Produce the standard report: tech stack, structure, findings, priority actions. Focus on: test coverage, error handling, security basics, doc coverage."*

2. **Read the researcher's report.** Do not dump it to the user verbatim — summarize the top 3 findings and top 3 priority actions in your own words.

3. **Confirm the direction** with the user: *"Here's what I found. Want me to build a completion roadmap around these priorities, or should I focus elsewhere?"*

4. **Launch the `planner` agent** in **Mode A (Roadmap Planning)** with the researcher's findings as context. It returns phases that close the gaps.

5. **Write state files** (see below).

6. **Show the roadmap** and tell the user: *"Run /sea-go to start Phase 1."*

## State Files to Create

Create `.sea/` at the project root with:

- `.sea/roadmap.md` — the planner's output (human-readable phase list)
- `.sea/state.json`:
  ```json
  {
    "schema_version": 1,
    "mode": "from-scratch" | "finish-existing",
    "created": "<ISO 8601 UTC>",
    "current_phase": 1,
    "total_phases": <N>,
    "last_session": "<ISO 8601 UTC>",
    "last_commit": "<short-sha or null>"
  }
  ```

  Always include `schema_version`. Future plugin versions check this field on read; if a state file is missing it or has an older value, they may run a migration before proceeding.

  The **initial** state.json write happens via `Write` (file doesn't exist yet). All **subsequent** mutations from any skill must go through `scripts/state-update.sh` so required fields are never dropped:
  ```bash
  bash "${CLAUDE_PLUGIN_ROOT}/scripts/state-update.sh" KEY=VALUE [KEY=VALUE ...]
  ```
- `.sea/phases/` — empty dir for future phase plans

Also add `.sea/` to `.gitignore` (create the file if missing, append if it's there).

## Rules

- **Ask before overwriting.** If `.sea/` already exists and the user wants a fresh init, move the old one to `.sea-archive-<timestamp>/` rather than deleting it.
- **Do not auto-commit during init.** Creating state files should not produce a git commit. The first commit belongs to the first real phase.
- **Scaffold only what MVP needs.** No feature-flag frameworks, no analytics SDKs, no optional middleware.
- **Do not call `executor` here.** Init is planning-only. Execution happens in `/sea-go`.
