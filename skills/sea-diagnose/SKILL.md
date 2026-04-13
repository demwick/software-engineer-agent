---
name: sea-diagnose
description: Generate a project health report covering test coverage, error handling consistency, and basic security posture. Use when the user asks "how is this project doing", "what's broken", "audit this repo", or when you need a baseline before recommending next steps.
argument-hint: [optional focus area — "tests", "security", "errors", or empty for all]
allowed-tools: Read, Glob, Grep, Bash, Write
---

<!--
  software-engineer-agent
  Copyright (C) 2026 demwick
  Licensed under the GNU Affero General Public License v3.0 or later.
  See LICENSE in the repository root for the full license text.
-->

# /sea-diagnose

Produce a prioritized health report for the current project. Announce: **"Using the diagnose skill to audit this project."**

Focus: $ARGUMENTS (optional — one of `tests`, `security`, `errors`, or empty for all three)

## Step 1: Launch the Researcher

Launch the `researcher` agent with a diagnose-specific prompt:

> Analyze this codebase as a health audit, not a general survey. Cover ONLY these three dimensions:
>
> 1. **Test coverage.** Are there test files at all? What fraction of modules have tests? Are critical paths (auth, data access, business logic) covered? Is there a test runner configured?
>
> 2. **Error handling.** Is error handling consistent across the codebase? Unhandled promise rejections, swallowed exceptions (`catch (e) {}`), missing error boundaries, missing logging on error paths.
>
> 3. **Security basics.** Hardcoded secrets in files or git history, missing input validation on user-facing endpoints, SQL built by string concat, XSS risk points (unescaped user input in HTML), permissive CORS, missing rate limiting on public endpoints.
>
> Return findings with file:line references. Skip anything outside these three areas.

If $ARGUMENTS names a single focus, tell the researcher to only cover that one.

## Step 2: Format the Report

Read the researcher's findings and format them for the user:

```
📊 Project Health Report
━━━━━━━━━━━━━━━━━━━━━━━━

🧪 Tests
  Status: ✅ / ⚠️ / ❌
  <one-paragraph summary>
  Critical gaps:
    • ...
    • ...

🛡️ Error Handling
  Status: ✅ / ⚠️ / ❌
  <one-paragraph summary>
  Critical gaps:
    • file:line — what's wrong
    • ...

🔒 Security
  Status: ✅ / ⚠️ / ❌
  <one-paragraph summary>
  Critical gaps:
    • file:line — what's wrong
    • ...

🎯 Priority Actions
  1. <most critical, one sentence, with file path>
  2. ...
  3. ...
```

Use the status keys consistently:
- ✅ = solid or acceptable for the project's maturity
- ⚠️ = has gaps but nothing blocking
- ❌ = serious gap, should be fixed before shipping

## Step 3: Save the Report

Write the report to `.sea/diagnose.json`:

```json
{
  "generated": "<ISO now>",
  "focus": "<tests|security|errors|all>",
  "tests":    { "status": "pass|warn|fail", "findings": [...] },
  "errors":   { "status": "pass|warn|fail", "findings": [...] },
  "security": { "status": "pass|warn|fail", "findings": [...] },
  "priority_actions": ["...", "...", "..."]
}
```

If `.sea/` doesn't exist yet, create it (but do not create `state.json` or `roadmap.md` — those belong to `/sea-init`).

## Step 4: Suggest Next Step

End the report with one of:

- If there's no roadmap yet:
  > Run `/sea-init` to convert these priorities into a roadmap.
- If there's already a roadmap:
  > These findings can be folded into the next phase. Review `.sea/roadmap.md` and decide.

## Rules

- **Read-only.** Diagnose never modifies source code. The only file writes allowed are `.sea/diagnose.json` and `.sea/` itself.
- **No false alarms.** If a finding is speculative, mark it ⚠️, not ❌. Do not inflate severity.
- **Evidence required.** Every ❌ finding must have a file:line reference. If you can't cite it, downgrade to ⚠️.
- **Scope discipline.** Do not audit code style, performance, architecture, or tooling — that's outside the three focus areas.
- **Respect the focus argument.** If the user asked for just `security`, do not slip in test-coverage findings.
