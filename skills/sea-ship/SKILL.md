---
name: sea-ship
description: Pre-merge / pre-deploy quality gate — runs the full project checklist (tests, lint, typecheck, build, security audit, git state, secrets scan) and reports PASS/WARN/FAIL per category with a rollback plan. Does NOT deploy — prepares. **Use this skill aggressively whenever** the user says any of "ship it", "ready to merge", "ready to deploy", "pre-PR check", "is this production ready", "can I merge this", "final check", "ship the MVP", or after all SEA phases complete and before the project goes anywhere near main/production. Read-only for source code — only writes `.sea/ship-report.json`.
argument-hint: [optional — "dry" to skip slow gates, "full" for everything]
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

<!--
  software-engineer-agent
  Copyright (C) 2026 demwick
  Licensed under the GNU Affero General Public License v3.0 or later.
  See LICENSE in the repository root for the full license text.
-->

# /sea-ship

Announce: **"Using the ship skill to run the pre-merge quality gate."**

Argument: $ARGUMENTS — optional
- empty or `full` → run all detected gates
- `dry` → skip slow gates (build, audit) for a fast smoke check

## Step 1: Preconditions

1. Not a git repo → tell the user *"sea-ship requires a git repository"* and stop.
2. Working tree has uncommitted changes → warn but proceed: *"⚠️ Working tree is not clean — the report reflects the committed state, not what's on disk."*

## Step 2: Detect the Quality Matrix

Run the detection helper:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-quality.sh" .
```

Output is a list of `category: command` lines. Parse into five slots:

- `test`
- `lint`
- `typecheck`
- `build`
- `audit`

Missing slots stay empty — the report will show them as `not-configured` (not a failure).

## Step 3: Run the Gates in Order

Run in this order and capture each command's stdout+stderr and exit code:

| Order | Gate | Fail cost | dry mode? |
|---|---|---|---|
| 1 | `test` | HIGH | always run |
| 2 | `lint` | LOW (warnings ok) | always run |
| 3 | `typecheck` | HIGH | always run |
| 4 | `build` | HIGH | skipped in dry |
| 5 | `audit` | MEDIUM | skipped in dry |

Save each command's log to `.sea/ship/<category>.log`. Save an overall report to `.sea/ship-report.json`.

Do not parallelize — run sequentially so a fast failure aborts later slow gates.

## Step 4: Extra Checks (Always Run)

Regardless of detected matrix:

### 4a. Git state
```bash
git status --short        # uncommitted files
git log --oneline -5      # recent commits
git rev-parse --abbrev-ref HEAD   # current branch
```

Record: dirty? branch name? commits since last tag (if any tag exists).

### 4b. Untracked files scan
Any untracked file matching suspicious patterns is a **warning**:
```
.env
*.pem
*.key
credentials*
secrets*
*.sqlite
*.db
*.log (root of repo only)
```

### 4c. Secrets scan (shallow)
Grep committed diff of last 5 commits for obvious patterns:
```bash
git log -p -5 | grep -E '(api[_-]?key|secret|password|token|bearer)\s*[:=]\s*["\x27][a-zA-Z0-9_-]{16,}'
```
Any hit is **critical** — block the report verdict.

### 4d. TODO / FIXME scan
Count `TODO|FIXME|XXX|HACK` in the working tree. Report as info (not a gate).

## Step 5: Compose the Report

Write `.sea/ship-report.json`:

```json
{
  "generated": "<ISO now>",
  "verdict": "ready|ready-with-warnings|not-ready",
  "mode": "full|dry",
  "gates": {
    "test":      {"status": "pass|fail|warn|not-configured", "command": "...", "summary": "..."},
    "lint":      {...},
    "typecheck": {...},
    "build":     {...},
    "audit":     {...}
  },
  "extra": {
    "git": {"branch": "...", "dirty": true|false, "commits_since_tag": 12},
    "untracked_suspicious": ["..."],
    "secrets_found": false,
    "todo_count": 7
  },
  "rollback_plan": "git revert HEAD~5..HEAD  # last phase's commits"
}
```

Verdict rules:
- **ready** — every detected gate passes, no secrets, no critical extras
- **ready-with-warnings** — any gate is `warn`, any untracked suspicious file, OR any `audit` failure with non-high severity
- **not-ready** — any HIGH-cost gate (`test`, `typecheck`, `build`) fails, or secrets found, or critical audit finding

## Step 6: Surface the Report

```
🚀 Pre-Ship Report
━━━━━━━━━━━━━━━━━━━━
Branch: main
Working tree: clean

✅ Tests         npm test (12 passed, 0 failed)
✅ Lint          npm run lint (0 warnings)
✅ Typecheck     tsc --noEmit (0 errors)
⚠️ Build         npm run build (1 warning: bundle size 520KB > 500KB target)
✅ Audit         npm audit --audit-level=high (0 high, 2 moderate)
ℹ️ Git           5 commits since last tag
ℹ️ Untracked     none
ℹ️ Secrets       no patterns found
ℹ️ TODO          7 in source

Verdict: READY WITH WARNINGS (1 warning to acknowledge)

Rollback plan:
  git revert HEAD~5..HEAD  # last phase's 5 commits

Next steps:
  - Address bundle size warning (not blocking)
  - Merge: ready to ship
```

For `not-ready`:
```
❌ Verdict: NOT READY
Failing gates:
  - Typecheck: 3 errors in src/auth/login.ts
  - Secrets: api_key literal in commit 8a2f1c3

Do NOT merge. Fix the failing gates and re-run /sea-ship.
```

## Step 7: Do NOT Deploy

`/sea-ship` is a **preparation** skill. It never:
- Tags a release
- Pushes to a remote
- Triggers a CI pipeline
- Touches production
- Modifies source code
- Creates a PR

It produces evidence that the user can show a reviewer, a CI pipeline, or themselves. Deployment is explicit and manual.

## Rules

- **Read-only with respect to source code.** Only writes `.sea/ship-report.json` and `.sea/ship/*.log`.
- **Never override a `not-ready` verdict silently.** If the user asks to ignore a failure, note it explicitly in the report with timestamp and reason.
- **Sequential gate execution.** Parallelizing would save time but lose the fast-fail order — test failures should abort before we spend 30s on a build.
- **Respect the dry mode.** `dry` skips slow gates (build, audit). Useful for quick smoke checks mid-development, but NOT valid for actual ship decisions.
- **Secrets scan is shallow.** Document in the report footer: *"Secrets scan checks committed diff of last 5 commits only — use a dedicated tool like gitleaks or trufflehog for full history scans."*

## When NOT to Use

- The user wants commit-level review (5 axes) → `/sea-review`
- The user wants project-wide audit (test/error/security baseline) → `/sea-diagnose`
- A failing test exists → `/sea-debug` first; ship will block on it anyway
- Phases are still in progress → `/sea-go` until done, then ship
- The user wants the plugin to actually deploy (push, tag, CI trigger) → ship doesn't do that, you still run the deploy command yourself

## Related

- `/sea-go` — finish all phases before running ship
- `/sea-review` — do a code-level review before the gate; ship complements it but does not replace it
- `/sea-diagnose` — earlier-stage health audit; ship is the final gate
- `/sea-debug` — when ship blocks on a failing gate
- `/sea-quick` — to fix small ship-blocking issues (e.g. a typecheck error)
- `/sea-undo` — rollback option if ship reveals a bad recent commit
- **External**: `agent-skills:shipping-and-launch` — broader pre-launch playbook including a11y, observability, rollout strategy
- **External**: `agent-skills:ci-cd-and-automation` — for actually wiring deploys around the gate this skill produces
