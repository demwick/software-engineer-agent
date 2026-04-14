---
name: sea-review
description: Run a structured 5-axis code review on the most recent phase's commits — correctness, readability, architecture, security, performance. Launches the reviewer subagent (Sonnet, read-only), produces `.sea/phases/phase-N/review.md`, and returns a verdict. **Use this skill whenever** the user says any of "review this phase", "review the last change", "is this good", "check the quality", "audit the code", "code review", "is this ready to merge", or after any /sea-go phase completes if the phase was medium or complex. Read-only — never modifies code, only flags issues for the executor or user to fix.
argument-hint: [phase <N> | last | range <from>..<to>]
allowed-tools: Read, Glob, Grep, Bash, Write
---

<!--
  software-engineer-agent
  Copyright (C) 2026 demwick
  Licensed under the GNU Affero General Public License v3.0 or later.
  See LICENSE in the repository root for the full license text.
-->

# /sea-review

Announce: **"Using the review skill to run a 5-axis code review."**

Argument: $ARGUMENTS
- empty or `last` → review the most recent completed phase
- `phase <N>` → review phase N's commit range from its summary.md
- `range <from>..<to>` → review an arbitrary git range

## Step 1: Resolve the Review Target

If $ARGUMENTS is `range <from>..<to>`:
- Validate both refs exist (`git rev-parse`)
- Skip to Step 2 with that range

Otherwise (empty, `last`, or `phase N`):
1. If `.sea/state.json` missing, tell the user *"No SEA project found."* and stop.
2. For `last`: find the highest-numbered `phases/phase-*/summary.md`.
3. For `phase N`: read `.sea/phases/phase-N/summary.md`.
4. Extract the commit range from the summary's `Commits:` line (format `<first-sha>..<last-sha>`).
5. If summary missing but phase exists: walk `git log` backward from HEAD until you've covered the phase's commit count (also in state.json if recorded).

If no valid range resolves, stop and report.

## Step 2: Preconditions

- Working tree must be clean-ish — uncommitted changes are OK (they're not part of the review range) but warn if there are any.
- Git must be available.
- Range must resolve to ≥ 1 commit. If the range is empty, tell the user there's nothing to review.

## Step 3: Launch the Reviewer Agent

Launch the `reviewer` agent with:
- The git commit range
- The phase number (if applicable)
- The expected output path: `.sea/phases/phase-<N>/review.md` (or `.sea/reviews/ad-hoc-<timestamp>.md` for range-based reviews)
- Instruction: *"Review these commits across the 5 axes. Write the full report to the output path. Return the final JSON verdict line."*

The reviewer returns:
```json
{"verdict": "pass|warn|block", "critical_count": 0, "report_path": "<path>"}
```

## Step 4: Surface the Verdict

Read the report file. Parse the verdict.

**If pass**:
> ✅ Review passed. 0 critical, N important findings. See `<report_path>`.
> (brief summary of any suggestions)

**If warn**:
> ⚠️ Review passed with warnings. 0 critical, N important findings. See `<report_path>`.
> Top 3 important findings:
> 1. ...
> 2. ...
> 3. ...
> Recommend addressing these before merging.

**If block**:
> ❌ Review blocked merge. N critical findings. See `<report_path>`.
> Critical findings:
> 1. file:line — <failure mode> → <recommended fix>
> 2. ...
> Run `/sea-quick "fix review finding #1"` or edit the code directly. Do NOT merge until critical findings are addressed.

## Step 5: Do NOT Auto-Fix

`/sea-review` is strictly a review pass. It does not invoke the executor to fix findings. The user decides whether to:
- Fix via `/sea-quick`
- Add a new phase via `/sea-roadmap add`
- Override and accept the findings
- Re-run review after manual fixes

This separation keeps review audits distinct from execution.

## Rules

- **One agent call per invocation.** Don't re-run review on the same range without user input.
- **Do not mutate the commit range.** No rebase, no squash, no revert from inside /sea-review.
- **Do not update state.json.** Review is read-only with respect to runtime state.
- **Phase number optional.** For ad-hoc `range` reviews, write to `.sea/reviews/ad-hoc-<timestamp>.md` and skip state updates.
- **Respect the verdict.** Never override block to pass without explicit user approval. If the user overrides, note it in the report footer with a timestamp.
