---
name: sea-undo
description: Roll back the most recent phase or quick task by reverting its commits. Inspects the phase summary or recent git history, lists the commits, asks for confirmation, then runs `git revert` (non-destructive — creates new commits). Use when a phase went wrong and you want a clean rollback without losing history.
argument-hint: [phase <N> | last]
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

<!--
  software-engineer-agent
  Copyright (C) 2026 demwick
  Licensed under the GNU Affero General Public License v3.0 or later.
  See LICENSE in the repository root for the full license text.
-->

# /sea-undo

Revert recent work safely. Announce: **"Using the undo skill to roll back recent commits."**

Argument: $ARGUMENTS
- empty or `last` → the most recently completed phase (or the last `/sea-quick` commit if no phase summary is fresher)
- `phase <N>` → that specific phase

## Step 1: Identify the Target

Run `git rev-parse --is-inside-work-tree` first. If not a git repo, tell the user *"Not a git repository — nothing to undo."* and stop.

**For a phase target:**

1. Read `.sea/phases/phase-N/summary.md`. Extract the commit range (`<first-sha>..<last-sha>`).
2. If `summary.md` is missing, fall back to `.sea/phases/phase-N/progress.json` and use its `last_commit` plus `git log` to walk back through the phase commits.
3. If neither exists, refuse: *"Phase N has no recorded commits — nothing to undo."*

**For `last`:**

1. Find the highest-numbered `phases/phase-*/summary.md`. Use that phase as the target.
2. If no summary exists, list the last 5 commits via `git log --oneline -5` and ask the user which to revert.

## Step 2: Sanity Checks (Hard Stops)

Refuse and report — do **not** prompt past these:

- Working tree is dirty (`git status --porcelain` non-empty) → *"Uncommitted changes present. Stash or commit them before undo."*
- Any target commit is not in the current branch's history → *"Commit `<sha>` is not reachable from HEAD; refusing to revert."*
- Target commits include a merge commit → *"Refusing to auto-revert merges. Do this manually."*
- Target commits have already been pushed to a shared remote (`git branch -r --contains <sha>` returns anything other than your own fork) → warn the user and require an explicit *"yes, revert published commits"* before continuing.

## Step 3: Confirm with the User

Show the commit list **in reverse chronological order** (newest first — that's the order revert will use):

```
About to revert 4 commits from Phase 2:

  c4d5e6f feat(api): add list endpoint
  b3c4d5e feat(api): add create endpoint
  a2b3c4d test(api): scaffold api tests
  912a3b4 chore(api): add fastify dep

This will create 4 NEW revert commits (history preserved).
Proceed? (yes/no)
```

Wait for explicit `yes`. Anything else → stop.

## Step 4: Revert

For each commit, **newest first**, run:

```bash
git revert --no-edit <sha>
```

If a revert fails with conflicts:

1. Run `git revert --abort`
2. Stop immediately
3. Report which commit failed and tell the user to resolve manually

Do **not** chain `git reset --hard` as a fallback. Do **not** use `--no-verify`.

## Step 5: Update State

If the target was a phase:

1. Mark the phase `pending` again in `.sea/roadmap.md`.
2. Update `.sea/state.json`: set `current_phase` back to N, refresh `last_session` and `last_commit`.
3. Move `.sea/phases/phase-N/summary.md` → `.sea/phases/phase-N/summary.md.reverted-<timestamp>` (don't delete — it's history).
4. Delete `.sea/phases/phase-N/progress.json` if it exists.
5. Leave `plan.md` in place — the user can re-run `/sea-go` to retry the phase against the same plan.

If the target was a `/sea-quick` commit, no `.sea/` mutations needed.

## Step 6: Report

```
Undo complete.
- Reverted: 4 commits (912a3b4..c4d5e6f)
- New revert commits: 4 (HEAD: <sha>)
- Phase 2 status: pending (re-run /sea-go to retry)
```

## Rules

- **Never destructive.** `git revert` only — no `reset --hard`, no `push --force`, no branch deletion.
- **One target per invocation.** Don't chain phases. If the user wants to undo Phases 3 and 2, they run undo twice.
- **Done phases are revertable.** Unlike `/sea-roadmap remove`, undo's whole job is rolling back done work.
- **Stop on conflict.** Don't try to be clever — bail out with `git revert --abort` and let the user handle it.
- **Trust the summary.** If `summary.md` says commits `a..b`, that's the contract. Don't recompute via `git log` unless the summary is missing.
