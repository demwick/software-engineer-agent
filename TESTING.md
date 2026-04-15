<!--
  software-engineer-agents
  Copyright (C) 2026 demwick
  Licensed under the GNU Affero General Public License v3.0 or later.
  See LICENSE in the repository root for the full license text.
-->

# Testing Checklist

Structural / syntactic checks are already green (JSON parse, bash syntax, frontmatter present). The rest has to be run inside a real Claude Code session because it requires live skill dispatch, subagent spawning, and hook invocation.

## Load the plugin

From the repo root:

```bash
claude --plugin-dir /Users/demirel/Projects/Plugins/software-engineer-agents
```

Inside the session, confirm discovery:

```
/help
```

You should see six `software-engineer-agents:*` skills and four agents listed under Agents (run `/agents`).

If anything is missing, start with `claude --debug-file /tmp/software-engineer-agents.log --plugin-dir ...` and `tail -f /tmp/software-engineer-agents.log` in another terminal — the debug log shows every hook registration and every skill load.

## 1. Empty project — `/sea-init` Mode A (from-scratch)

```bash
mkdir /tmp/pwtest-a && cd /tmp/pwtest-a
claude --plugin-dir /Users/demirel/Projects/Plugins/software-engineer-agents
```

In the session:

```
/sea-init I want a CLI todo app in Go with SQLite
```

**Expect:**
- A few clarifying questions (target user, MVP features, stack confirmation)
- A scaffold that runs `go run .` (or similar) cleanly
- `.sea/state.json` with `"mode": "from-scratch"`
- `.sea/roadmap.md` with 3–7 phases
- `.sea/` appended to `.gitignore`
- Closing message: "Run /sea-go to start Phase 1"

**Fail conditions:**
- Over-scaffolding (auth, feature flags, analytics — anything not in the MVP)
- No `.sea/` folder created
- `disable-model-invocation: true` not respected (Claude auto-runs init — it shouldn't)

## 2. `/sea-status` on a populated project

Still in `/tmp/pwtest-a`:

```
/sea-status
```

**Expect:**
- Mode, progress bar, active phase, last session, last commit
- Progress bar is ASCII-block style, ten chars wide
- Sub-second response
- No agent invocations (check the transcript — `status` is pure file-read)

## 3. `/sea-go` — first phase execution

```
/sea-go
```

**Expect:**
- "Starting Phase 1: <name>" announcement
- Planner agent runs first (phase plan didn't exist yet), writes `.sea/phases/phase-1/plan.md`
- Executor agent runs, produces commits
- Stop hook fires, runs `go test ./...` (or whatever detect-test picks)
- If tests pass: state updates, roadmap marks Phase 1 as `done`
- Summary printed, next-phase hint shown

**Fail conditions:**
- Verifier agent is invoked manually by the skill (should only run via Stop hook)
- State file doesn't update
- Commits are not atomic (more than one logical task per commit)

## 4. Auto-QA retry path

Introduce a deliberate test failure before running `/sea-go` on Phase 2:

```bash
# In the project that's under /sea-go, edit a test file to assert something false
```

Then:

```
/sea-go
```

**Expect:**
- Executor finishes → touches `.sea/.needs-verify`
- Stop hook runs tests → fails → returns block decision
- Claude reads the block reason, tries to fix the failure
- Stop hook runs again → on the retry, either passes or increments the counter
- After at most 2 retries, hook gives up and Claude stops with a "report to user" message

**Check:** `cat .sea/.last-verify.log` shows the last test run output.

**Fail conditions:**
- Infinite loop (hook keeps retrying indefinitely) — the counter or `stop_hook_active` check is broken
- Hook silently passes even though tests failed
- `.needs-verify` is left behind after the hook gives up

## 5. Existing project — `/sea-init` Mode B (finish existing)

```bash
cd /path/to/some/half-done/project
claude --plugin-dir /Users/demirel/Projects/Plugins/software-engineer-agents
```

```
/sea-init
```

**Expect:**
- Researcher agent runs, produces a short report (tech stack, findings, priority actions)
- Claude summarizes in own words — does NOT dump the researcher's full report
- Asks the user whether to build a completion roadmap
- On confirmation, planner agent runs in Mode A, produces a roadmap focused on the gaps
- `.sea/` created with the state files
- Never calls the executor — Mode B is planning-only

## 6. `/sea-diagnose` health audit

```
/sea-diagnose
```

**Expect:**
- Researcher agent runs with the diagnose-specific prompt
- Output in the exact 📊 Project Health Report format from `skills/diagnose/SKILL.md`
- Three sections: Tests / Error Handling / Security
- Every ❌ finding has a file:line reference
- `.sea/diagnose.json` written

Also try `/sea-diagnose security` — expect only the security section, no tests/errors sections.

## 7. `/sea-quick` — happy path

```
/sea-quick add a "License" badge to the README
```

**Expect:**
- Executor runs, one file edited, one commit
- Stop hook runs the project's tests (if any)
- Single-sentence completion summary
- No `.sea/` mutations beyond the `.needs-verify` marker

## 8. `/sea-quick` — reject over-large task

```
/sea-quick refactor the entire auth layer to use OAuth2
```

**Expect:**
- Skill rejects the task on the sanity check (touches many files, introduces new abstraction)
- Tells the user to use `/sea-go`
- No executor invocation, no commits

## 9. `/sea-roadmap` CRUD

```
/sea-roadmap
```

Should just show the current roadmap.

```
/sea-roadmap add "add E2E tests with Playwright"
```

Should propose the new phase block and wait for confirmation. On confirm, appends to `roadmap.md` and bumps `total_phases` in `state.json`.

```
/sea-roadmap remove 3
```

Refuses if Phase 3 is `done`. Otherwise archives `.sea/phases/phase-3/` to `archived-<timestamp>-phase-3/` and renumbers subsequent phases.

## 10. `SessionStart` context injection

Close the Claude Code session and restart it in a software-engineer-agents-initialized project:

```bash
cd /tmp/pwtest-a
claude --plugin-dir /Users/demirel/Projects/Plugins/software-engineer-agents
```

At the first prompt:

```
where am i?
```

**Expect:** Claude answers using the session state (mode, active phase, last commit) WITHOUT calling `/sea-status`. That's the injection working — the hook put the state in context before Claude's first turn.

Claude should NOT volunteer this context unless you ask about software-engineer-agents state. Test by starting a normal unrelated conversation ("what is 2+2?") — Claude shouldn't mention the plugin.

## 11. Superpowers side-by-side

With both plugins loaded:

```bash
claude --plugin-dir /Users/demirel/Projects/Plugins/software-engineer-agents
```

(Superpowers is already installed user-wide in the test environment.)

- `/sea-go` still works
- `/superpowers:brainstorming` still works
- Neither plugin's SessionStart hook clobbers the other (both run, both inject their own context)

## 12. `jq` missing — graceful degradation

Temporarily rename jq on the path (or run in a container without it):

```bash
mv "$(which jq)" /tmp/jq-backup
```

Start Claude Code, run `/sea-status`. The status command should still work (it doesn't need jq). Run `/sea-go` on a project — hooks should gracefully no-op instead of crashing (auto-qa and state-tracker have `command -v jq || exit 0` guards).

Restore jq:

```bash
mv /tmp/jq-backup "$(which jq)"
```

## Cleanup

```bash
rm -rf /tmp/pwtest-a
```

---

## Known gaps (deliberate, for now)

- No unit tests for bash scripts — they're small enough to eyeball, and live testing via the checklist above catches the integration risks.
- No tests for `MEMORY.md` curation — we defer to the platform's built-in management.
- No test for marketplace distribution — out of scope for V1.

## When something fails

1. `claude --debug-file /tmp/software-engineer-agents.log --plugin-dir ...`
2. Reproduce the failure
3. `tail -100 /tmp/software-engineer-agents.log` — look for `hook`, `skill`, `agent` events
4. For hook failures specifically, pipe fake JSON to the script manually:
   ```bash
   echo '{}' | CLAUDE_PLUGIN_ROOT=/Users/demirel/Projects/Plugins/software-engineer-agents \
     bash /Users/demirel/Projects/Plugins/software-engineer-agents/hooks/auto-qa
   echo "exit=$?"
   ```
5. For agent failures: launch the agent directly from Claude Code (`Use the planner agent to ...`) and see what it does with a minimal prompt.
