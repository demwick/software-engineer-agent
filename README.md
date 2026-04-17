<!--
  software-engineer-agents
  Copyright (C) 2026 demwick
  Licensed under the GNU Affero General Public License v3.0 or later.
  See LICENSE in the repository root for the full license text.
-->

# Software Engineer Agents

> **Your AI software engineer. Not just a code writer — a full teammate.**

`software-engineer-agents` is a Claude Code plugin that takes on the day-to-day responsibilities of a software engineer. It designs, plans, implements, tests, and documents — driven by a single command you run when you want the project to move forward.

---

## What it does

| Responsibility | How |
|---|---|
| **System design** | Analyzes your project, picks the right approach, splits the MVP into phases |
| **Planning** | Produces atomic, verifiable task plans with explicit dependencies |
| **Implementation** | Writes code phase by phase, one atomic commit per task |
| **Testing & QA** | Auto-runs your test suite after every change — blocks on failure, auto-fixes, retries |
| **Debugging** | Health audit with prioritized, actionable findings |
| **Documentation** | Each agent builds and maintains its own memory across sessions |

---

## Three modes

**From scratch** — *"I want to build a SaaS app"*
Clarifies the idea, scaffolds the project, splits the MVP into 3–7 phases, drives each through plan → implement → QA.

**Finish an existing project** — *"I have a half-done repo"*
Analyzes the codebase, finds the gaps, builds a completion roadmap, closes them phase by phase.

**Single task** — *"Fix that button"*
Straight to execute and commit. No planning overhead.

---

## Commands

| Command | What it does |
|---|---|
| `/sea-init [idea]` | Bootstrap a new or existing project — scaffold + roadmap |
| `/sea-go [phase]` | Advance one phase: plan → implement → auto-QA |
| `/sea-quick <task>` | Single task, single atomic commit |
| `/sea-diagnose [focus]` | Health audit: tests, error handling, security |
| `/sea-status` | Show current state and progress |
| `/sea-roadmap [verb]` | View or edit the phase list |

Commands with side-effects (`init`, `go`, `quick`) are **user-invoked only** — Claude will never trigger them automatically. Read-only commands (`diagnose`, `status`, `roadmap`) can be called automatically when the context calls for them.

---

## How it works in practice

**Starting from nothing:**

```
/sea-init I want to build a recipe sharing app with Next.js and SQLite
→ clarifying questions, scaffold, 5-phase roadmap

/sea-go
→ Phase 1: data layer — 4 atomic commits, tests pass

/sea-go
→ Phase 2: list UI — one commit breaks a test,
   Stop hook catches it, Claude auto-fixes, re-verifies, continues
```

**Finishing an existing repo:**

```
/sea-init
→ analyzes codebase, reports gaps, offers a completion roadmap

/sea-diagnose security
→ flags 3 issues: open API routes, missing validation, .env in git

/sea-roadmap add "close the 3 security gaps"
→ adds a new phase

/sea-go
→ fixes all three, atomic commits, tests pass
```

**One-off task:**

```
/sea-quick bump typescript to ^5.4
→ commits the change, test suite runs, done
```

**Adding a milestone after the MVP ships:**

```
/sea-roadmap add "V2: add a FastAPI web UI on top of the existing CLI"
→ detects all phases are done, drafts 3 new phases, inserts a milestone
  boundary in roadmap.md

/sea-go
→ starts Phase N+1 of the new milestone
```

---

## Works best with claude-charter

[`claude-charter`](https://github.com/demwick/claude-charter) is a governance layer for Claude Code workspaces — it enforces coding standards, security policies, and decision records across every session.

When both are active, they layer cleanly:

- **claude-charter** sets the rules: what code should look like, what's off-limits, how decisions get recorded.
- **software-engineer-agents** drives the work: what to build next, in what order, with automatic quality gates.

The executor respects charter policies automatically — no extra configuration. Charter's `CLAUDE.md` and `.claude/knowledge/` files are visible to every subagent in the session.

```bash
# Load both together
claude --plugin-dir /path/to/software-engineer-agents \
       --plugin-dir /path/to/claude-charter
```

---

## Install

**From a local directory:**

```bash
claude --plugin-dir /path/to/software-engineer-agents
```

**From GitHub:**

```bash
git clone https://github.com/demwick/software-engineer-agents
claude --plugin-dir ./software-engineer-agents
```

**From a marketplace (post-V1):**

```bash
claude plugin install software-engineer-agents@<marketplace>
```

---

## Requirements

- **Claude Code** ≥ 2.1
- **bash** — macOS/Linux built-in; Windows: Git for Windows
- **jq** — `brew install jq` / `apt-get install jq` (hooks degrade gracefully if missing)
- **git** — the executor commits atomically; most of the value comes from this

No Node, Python, or Go runtime required for the plugin itself.

---

## Contributing

Clone, load locally, make changes, run `/reload-plugins` inside Claude Code to pick them up. Test with a throwaway project using the [`TESTING.md`](TESTING.md) checklist.

For architecture internals, directory layout, agent model breakdown, hook design, and how to debug hook scripts — see [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).

**Commit style:** `feat(agents): add …`, `fix(hooks): …`, `docs(readme): …`

---

## License

**GNU Affero General Public License v3.0 or later** — see [LICENSE](LICENSE).

AGPL keeps hosted derivatives open: if you run a modified version as a service, you must share your changes. For ordinary local use in Claude Code, it imposes no practical restrictions.
