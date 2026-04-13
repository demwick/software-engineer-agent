<!--
  software-engineer-agent
  Copyright (C) 2026 demwick
  Licensed under the GNU Affero General Public License v3.0 or later.
  See LICENSE in the repository root for the full license text.
-->

# Software Engineer Agent

> A Claude Code plugin that automates the core responsibilities of a software engineer.

`software-engineer-agent` is a Claude Code native plugin that takes on the day-to-day work of a software engineer. It doesn't just write code — it designs, plans, implements, tests, reviews, debugs, and documents, driven by a single command you run when you want the project to move forward.

## Software engineer responsibilities → plugin mapping

| SE responsibility | Plugin surface |
|-------------------|----------------|
| **System design & architecture** | `/sea-init` — analyze the project, pick the tech stack, split the MVP into phases |
| **Planning** | `planner` subagent — produces atomic, verifiable task plans with explicit dependencies |
| **Code development** | `executor` subagent — plan-driven implementation with atomic conventional commits |
| **Testing & QA** | `verifier` subagent + Stop hook — auto-runs the project's test runner, auto-retries on failure |
| **Code review** | Auto-QA loop — every turn the Stop hook checks plan alignment and test status, returns actionable failure reasons |
| **Debugging & problem solving** | `/sea-diagnose` — codebase health audit (tests, error handling, security) with prioritized actions |
| **Documentation** | Agent memory — each subagent curates its own `MEMORY.md` with patterns, decisions, known gotchas |
| **Continuous improvement** | Cross-session memory — learnings carry from every session to the next, automatically |

## Three modes

1. **From-scratch MVP** — *"I want to build a SaaS app"* → clarify the idea, scaffold a minimal project, split the MVP into 3–7 phases, run each through the plan → execute → auto-QA pipeline until the MVP is shipped.

2. **Finish an existing project** — *"I have a half-done repo"* → analyze the codebase, find the gaps (tests, security, error handling, docs), prioritize them, build a completion roadmap, close the gaps phase by phase.

3. **Single task** — *"Fix that button"* → straight to execute + commit. No planning overhead.

## Install

### From a local directory (development)

```bash
claude --plugin-dir /path/to/software-engineer-agent
```

Loads the plugin for the current session. Ideal while iterating on the plugin itself.

### From the GitHub repo

```bash
git clone https://github.com/demwick/software-engineer-agent
claude --plugin-dir ./software-engineer-agent
```

### From a marketplace (post-V1)

```bash
claude plugin install software-engineer-agent@<marketplace>
```

## Commands

All commands live under the `software-engineer-agent:` namespace. Type `/` in Claude Code to see them.

| Command | What it does | Side-effects? | Model-invocable? |
|---------|-------------|---------------|------------------|
| `/sea-init [idea]` | Bootstrap a new or existing project | Yes — creates `.sea/`, scaffolds, writes roadmap | **No** — user-invoked only |
| `/sea-go [phase]` | Advance one phase (plan → execute → auto-QA) | Yes — commits code, updates state | **No** |
| `/sea-quick <task>` | Small task + single atomic commit | Yes — commits code | **No** |
| `/sea-diagnose [focus]` | Health audit (tests / errors / security) | Writes `.sea/diagnose.json` | Yes |
| `/sea-status` | Show current state and progress | Read-only | Yes |
| `/sea-roadmap [verb]` | View or edit the phase list | Edits `.sea/roadmap.md` on verbs | Yes |

Commands with real side-effects (`init`, `go`, `quick`) are **user-invocable only** — Claude will not auto-trigger them. Read-only commands (`diagnose`, `status`, `roadmap`) can be called automatically when the context calls for them.

### Typical workflows

**Starting from nothing:**

```
/sea-init I want to build a recipe sharing app with Next.js and SQLite
→ a few clarifying questions, scaffold, then a 5-phase roadmap

/sea-go
→ Phase 1: data layer, shipped as 4 atomic commits, auto-QA runs tests, confirms pass

/sea-go
→ Phase 2: list UI, one commit breaks a test, Stop hook reports it,
   Claude auto-fixes and the hook re-verifies, passes, phase done
```

**Finishing an existing repo:**

```
/sea-init
→ analyzes codebase, reports gaps, asks if you want a completion roadmap

/sea-diagnose security
→ flags 3 security issues: open API routes, missing validation, .env in git

/sea-roadmap add "close the 3 security gaps from diagnose"
→ adds a new phase to the roadmap

/sea-go
→ runs the new phase, fixes the three issues, atomic commits, auto-QA passes
```

**One-off task:**

```
/sea-quick bump typescript to ^5.4
→ executor runs, commits, auto-QA runs the test suite, done
```

## Architecture

The plugin is a thin layer over Claude Code's native primitives. No external runtime, no MCP servers, no configuration.

**Skills** (`skills/*/SKILL.md`) are prompts Claude runs. Each skill is a thin dispatcher: read state, pick the right subagent, persist the result. No orchestration loops inside skills.

**Subagents** (`agents/*.md`) do the heavy work in isolated contexts:

| Agent | Model | Tools | Memory |
|-------|-------|-------|--------|
| `researcher` | Haiku | Read, Glob, Grep, Bash, WebFetch, WebSearch | project |
| `planner` | Sonnet | Read, Glob, Grep, Bash, WebFetch (no Write) | project |
| `executor` | Sonnet | Full tools | project |
| `verifier` | Haiku | Read, Glob, Grep, Bash | project |

Each agent has `memory: project` in its frontmatter — Claude Code's platform manages a per-agent `MEMORY.md` at `.claude/agent-memory/<agent>/`, auto-loaded every invocation. No hand-rolled session persistence. No custom memory-manager agent. No shell scripts for memory.

**Hooks** (`hooks/hooks.json`) are the automation glue:

- **`SessionStart`** — reads `.sea/state.json` and `.sea/roadmap.md`, injects a short state summary into Claude's context via `additionalContext`. Every session starts with project awareness.
- **`Stop` (auto-QA)** — when `.sea/.needs-verify` is present (set by `/sea-go` or `/sea-quick` after the executor finishes), the hook auto-detects the test runner, runs it, and either lets Claude stop (pass) or returns a `block` decision with the failure details (fail). Claude auto-retries the fix up to 2 times before giving up.
- **`PostToolUse` (state-tracker)** — refreshes `last_edit` in `state.json` every time Claude modifies a file in a project that's already initialized.

**State** lives in two separate layers:

- `<project>/.sea/` — project runtime state (roadmap, phase plans, current state, transient markers)
- `.claude/agent-memory/<agent>/MEMORY.md` — per-agent cross-session learnings (platform-managed)

See [`docs/STATE.md`](docs/STATE.md) for the full file layout and schemas. See [`examples/state/`](examples/state/) for populated sample files.

## Directory layout

```
software-engineer-agent/
├── .claude-plugin/plugin.json     # manifest
├── CLAUDE.md                      # context for developing the plugin itself
├── DESIGN.md                      # architectural decisions and rationale
├── README.md                      # this file
├── LICENSE                        # AGPL-3.0-or-later
├── TESTING.md                     # live-testing checklist
├── agents/
│   ├── researcher.md              # Haiku, read-only, memory: project
│   ├── planner.md                 # Sonnet, read-only, memory: project
│   ├── executor.md                # Sonnet, full tools, memory: project
│   └── verifier.md                # Haiku, read-only + Bash, memory: project
├── skills/
│   ├── init/SKILL.md              # disable-model-invocation
│   ├── go/SKILL.md                # disable-model-invocation
│   ├── quick/SKILL.md             # disable-model-invocation
│   ├── diagnose/SKILL.md          # auto-invocable
│   ├── status/SKILL.md            # auto-invocable
│   └── roadmap/SKILL.md           # auto-invocable
├── hooks/
│   ├── hooks.json                 # SessionStart + Stop + PostToolUse registration
│   ├── run-hook.cmd               # polyglot cross-platform wrapper
│   ├── session-start              # context injection (extensionless)
│   ├── auto-qa                    # Stop hook, runs tests (extensionless)
│   └── state-tracker              # PostToolUse hook (extensionless)
├── scripts/
│   └── detect-test.sh             # auto-detects test runner
├── docs/
│   └── STATE.md                   # .sea/ reference
└── examples/state/                # populated sample state for reference
```

## Requirements

- **Claude Code** ≥ 2.1 (plugin system, subagent `memory` field, and agent-based hooks are all from this era)
- **bash** — ships with macOS and Linux; on Windows, Git for Windows bash
- **jq** — used by hook scripts for safe JSON I/O. Install: `brew install jq` / `apt-get install jq`. If missing, hooks degrade to no-ops rather than crashing.
- **git** — the executor commits atomically and `/sea-status` reads `git log`. Technically optional but you lose most of the value without it.

No Node, Python, or Go runtime required for the plugin itself — only whatever your target project needs.

## Superpowers compatibility

`software-engineer-agent` runs side-by-side with [Superpowers](https://github.com/obra/superpowers). Different namespaces (`/software-engineer-agent:*` vs `/superpowers:*`), no conflicts. When Superpowers is installed, the planner agent can suggest `superpowers:writing-plans` for especially large phases — but it doesn't require it.

## Competitive positioning

Why another plugin when Superpowers, GSD, and Aperant exist?

- **Superpowers** is a methodology library — rigid pipeline, great discipline, strong skill triggering. It has no project analysis, no complexity routing, and memory is light. `software-engineer-agent` is closer to a project manager: complexity-aware pipeline, memory per agent, active steering to the next action.
- **GSD** has 20+ commands and a per-workspace config file. `software-engineer-agent` ships 6 commands, zero configuration, and leans on Haiku wherever it can to keep token costs honest.
- **Aperant** is a desktop app with a Kanban UI and parallel workers. `software-engineer-agent` stays inside Claude Code — no separate UI, no platform install.

The differentiator nothing else ships: **health audit → priority actions → roadmap → auto-QA loop**, all driven by a single `/sea-go` command.

## Contributing

1. Clone the repo: `git clone https://github.com/demwick/software-engineer-agent`
2. Load locally: `claude --plugin-dir /path/to/software-engineer-agent`
3. Make changes to skills, agents, or hooks
4. Run `/reload-plugins` inside Claude Code to pick them up without restarting
5. Test against a throwaway project (a fresh directory is easiest — use the `TESTING.md` checklist)

When debugging hooks:

```bash
claude --debug-file /tmp/sea.log --plugin-dir /path/to/software-engineer-agent
# in another terminal:
tail -f /tmp/sea.log
```

The debug log shows every hook that fired with its exit code, stdout, and stderr.

See `DESIGN.md` for the architectural rationale before proposing big changes. The plugin deliberately leans on platform built-ins (subagent `memory` field, Stop hook decisions, SessionStart context injection) rather than reinventing them in shell scripts or skill prompts.

**Commit style:** conventional commits — `feat(agents): add ...`, `fix(hooks): ...`, `docs(readme): ...`, `chore(deps): ...`.

Every source file carries an AGPL-3.0 header comment. JSON manifests (`plugin.json`, `hooks.json`) don't support comments, so by reference the repo-root `LICENSE` file covers them.

## License

**GNU Affero General Public License v3.0 or later** — see [LICENSE](LICENSE).

Why AGPL? The plugin is intended to be used directly in Claude Code, where it runs on the user's machine. But it's also the kind of tooling that could be wrapped into a hosted service. AGPL keeps hosted derivatives open: if you run a modified version as a service, you must share your changes. For ordinary local use in Claude Code, AGPL imposes no practical restrictions — clone it, modify it, use it, share improvements.
