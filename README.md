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
| **Code review** | Auto-QA loop — every turn the Stop hook checks plan alignment and test status, returns actionable failure reasons. For deeper review, compose with `addyosmani/agent-skills:code-review`. |
| **Debugging & problem solving** | `/sea-diagnose` — codebase health audit (tests, error handling, security) with prioritized actions. For live-bug triage, compose with `obra/superpowers:debugging` or `addyosmani/agent-skills:debugging`. |
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
| `/sea-roadmap [verb]` | View or edit the phase list (including milestone appends via `add`) | Edits `.sea/roadmap.md` on verbs | Yes |

Commands with real side-effects (`init`, `go`, `quick`) are **user-invocable only** — Claude will not auto-trigger them. Read-only commands (`diagnose`, `status`, `roadmap`) can be called automatically when the context calls for them.

> **v2.0.0 scope cut.** The command surface dropped from eleven to six. If you used `/sea-ship`, `/sea-review`, `/sea-debug`, `/sea-milestone`, or `/sea-undo` in v1.x, see the [Migration from v1.x](#migration-from-v1x) section below for the composition replacements.

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

## Migration from v1.x

v2.0.0 deleted five commands whose methodology is better served by
composition with existing plugins (or by plain git). The table below
maps each deleted command to its replacement:

| v1.x command | v2.0.0 replacement |
|---|---|
| `/sea-ship` | `addyosmani/agent-skills:shipping` (install via `/plugin marketplace add addyosmani/agent-skills`) |
| `/sea-review` | `addyosmani/agent-skills:code-review` |
| `/sea-debug` | `obra/superpowers:debugging` *or* `addyosmani/agent-skills:debugging` |
| `/sea-milestone` | `/sea-roadmap add "<description>"` — same functionality, different command |
| `/sea-undo` | `git revert <commit>` — no wrapper, just use git directly |

The `reviewer` and `debugger` agents are also removed in v2.0.0 —
they had no callers after the commands were deleted (Phase 4 of
the refactor deletes the files themselves).

State schema: if you have a v1.x project with a `.sea/` directory,
v2.0.0 will migrate it automatically on first `/sea-go` or `/sea-init`
invocation. The migration is one-way; the `pre-scope-cut` git tag is
the floor if you need to roll back the plugin itself. See
`docs/migration/v1-to-v2.md` (ships with v2.0.0) for the full
migration checklist.

## Architecture

The plugin is a thin layer over Claude Code's native primitives. No external runtime, no MCP servers, no configuration.

**Skills** (`skills/*/SKILL.md`) are prompts Claude runs. Each skill is a thin dispatcher: read state, pick the right subagent, persist the result. No orchestration loops inside skills.

**Subagents** (`agents/*.md`) do the heavy work in isolated contexts:

| Agent | Model | Tools | Memory | Called from |
|-------|-------|-------|--------|-------------|
| `researcher` | Haiku | Read, Glob, Grep, Bash, WebFetch, WebSearch | project | `/sea-init`, `/sea-diagnose` |
| `planner` | Sonnet | Read, Glob, Grep, Bash, WebFetch (no Write) | project | `/sea-init`, `/sea-go` |
| `executor` | Sonnet | Read, Write, Edit, Glob, Grep, Bash, WebFetch | project | `/sea-go`, `/sea-quick` |
| `verifier` | Haiku | Read, Glob, Grep, Bash | project | `Stop` hook (auto-qa), `/sea-go` |

v2.0.0 removed two v1.0.0 agents — `reviewer` (Sonnet) and `debugger` (Haiku) — along with the commands that called them. Code review and systematic debugging are now delegated to composition with `addyosmani/agent-skills` and `obra/superpowers`. See [Migration from v1.x](#migration-from-v1x).

All four agents share `agents/_common.md`, an operating constitution (surface assumptions, manage confusion, push back with evidence, enforce simplicity, stop-the-line, commit discipline) that overrides any task-specific instruction it conflicts with.

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
│   ├── _common.md                 # operating constitution shared by all agents
│   ├── researcher.md              # Haiku, read-only, memory: project
│   ├── planner.md                 # Sonnet, read-only, memory: project
│   ├── executor.md                # Sonnet, full tools, memory: project
│   └── verifier.md                # Haiku, read-only + Bash, memory: project
├── skills/
│   ├── sea-init/SKILL.md          # disable-model-invocation
│   ├── sea-go/SKILL.md            # disable-model-invocation
│   ├── sea-quick/SKILL.md         # disable-model-invocation
│   ├── sea-diagnose/SKILL.md      # auto-invocable
│   ├── sea-status/SKILL.md        # auto-invocable
│   └── sea-roadmap/SKILL.md       # auto-invocable
├── hooks/
│   ├── hooks.json                 # SessionStart + Stop + PostToolUse registration
│   ├── run-hook.cmd               # polyglot cross-platform wrapper
│   ├── session-start              # context injection (extensionless)
│   ├── auto-qa                    # Stop hook, runs tests (extensionless)
│   └── state-tracker              # PostToolUse hook (extensionless)
├── scripts/
│   ├── detect-test.sh             # auto-detects the project's test runner
│   ├── detect-quality.sh          # detects lint / typecheck / build / audit commands
│   ├── check-host-compat.sh       # host Python / tool compat post-check for auto-qa
│   ├── state-update.sh            # safe jq-based `.sea/state.json` writer
│   └── archive-state.sh           # moves `.sea/` aside for a clean reset
├── docs/
│   ├── STATE.md                   # .sea/ reference
│   └── specs/                     # refactor specs and companion journals
├── evals/                         # deterministic CI eval suites (run via evals/run.sh)
├── tests/run-tests.sh             # unit test entry point for scripts and hooks
└── examples/state/                # populated sample state for reference
```

## Requirements

- **Claude Code** ≥ 2.1 (plugin system, subagent `memory` field, and agent-based hooks are all from this era)
- **bash** — ships with macOS and Linux; on Windows, Git for Windows bash
- **jq** — used by hook scripts for safe JSON I/O. Install: `brew install jq` / `apt-get install jq`. If missing, hooks degrade to no-ops rather than crashing.
- **git** — the executor commits atomically and `/sea-status` reads `git log`. Technically optional but you lose most of the value without it.

No Node, Python, or Go runtime required for the plugin itself — only whatever your target project needs.

## Related plugins (compose, don't compete)

SEA is an **orchestration layer** — state, roadmap, atomic commits, auto-QA loop. It's deliberately thin on methodology because three other excellent plugins already cover that space. Install them side-by-side and the planner + executor will auto-hand-off to them when the phase calls for it.

### The three-layer picture

```
┌────────────────────────────────────────────────────────────────┐
│  software-engineer-agent  (you are here)                       │
│  ORCHESTRATION: state machine, phases, auto-QA, review, ship   │
│  "what to do next, in what order, atomically committed"        │
└────────────────────────────────────────────────────────────────┘
                              │ hands off to
                              ▼
┌────────────────────────────────────────────────────────────────┐
│  addyosmani/agent-skills  (~15k ⭐)                             │
│  METHODOLOGY: TDD, code review, security, perf, debugging,    │
│  shipping, frontend, API design, ADRs, CI/CD (20 skills)       │
│  "how to do this particular kind of engineering work well"     │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│  obra/superpowers                                              │
│  DISCIPLINE: brainstorming, writing-plans, TDD, debugging      │
│  "structured thought processes before touching code"           │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│  anthropics/skills  (~117k ⭐)                                  │
│  CAPABILITIES: PDF/DOCX/PPTX/XLSX, MCP builder, webapp testing │
│  "here's how to handle this specific domain/format"            │
└────────────────────────────────────────────────────────────────┘
```

### Installation

```bash
# Core orchestration
claude --plugin-dir /path/to/software-engineer-agent

# Methodology library (recommended pairing)
/plugin marketplace add addyosmani/agent-skills
/plugin install agent-skills@addy-agent-skills

# Structured thinking (optional)
/plugin install superpowers@obra

# Domain capabilities (install only what you need)
/plugin marketplace add anthropics/skills
/plugin install example-skills@anthropic-agent-skills
```

### How composition works

When you run `/sea-go` on a phase tagged "security hardening":

1. SEA's `planner` agent writes the plan and appends a hand-off note:
   > *Hand-off: this phase benefits from `agent-skills:security-and-hardening` if installed.*
2. SEA's `executor` agent picks up the plan and starts coding.
3. If `agent-skills` is installed, the security skill auto-triggers when the executor mentions auth / secrets / validation, layering its checklist on top of the execution.
4. SEA's auto-QA Stop hook fires, tests pass, phase marked done.
5. After the phase completes, `/sea-go` notes the availability of `agent-skills:code-review` (if installed) in its summary so the user can opt in to a deeper review pass.

None of this requires configuration. The plugins compose via standard skill triggering — SEA orchestrates, the others contribute methodology. Namespaces are separate (`/sea-*` vs `/agent-skills:*` vs `/superpowers:*`), so there are no command conflicts. v2.0.0 deliberately stopped shipping SEA-owned review/debug/ship commands — the specialized plugins do those jobs better.

### Why SEA and not one of the others?

They each fill a different slot:

- **Superpowers** is methodology-first — rigid pipeline, strong skill triggering. Great for discipline, but no project analysis, no complexity routing, no cross-phase state, no roadmap. SEA adds the project-manager layer.
- **GSD** has 20+ commands and a per-workspace config file. SEA ships **six** commands (v2.0.0 scope cut), zero configuration, and leans on Haiku wherever judgment isn't critical.
- **Aperant** is a desktop app with a Kanban UI. SEA stays inside Claude Code — no platform install, no separate UI.
- **addyosmani/agent-skills** is pure methodology — doesn't know what phase you're in, doesn't track state, doesn't commit atomically. SEA orchestrates; agent-skills teaches the orchestra how to play.

The differentiator SEA alone ships: **project health audit → priority actions → phased roadmap → atomic implementation → auto-QA loop**, all driven by a single `/sea-go` command with zero configuration. Code review, debugging, and pre-merge gate work are deliberately delegated to composition with the specialized plugins above.

## Acknowledgments

SEA is built from scratch — every line of code, prompt, and script in this repository is original work. No files were copied from other projects. However, several patterns were studied while designing SEA, and it's intellectually honest to note where ideas came from:

- **[addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)** — the 5-axis code review framework, the stop-the-line debugging discipline, the Prove-It bug-fix pattern (failing test commit first, then fix), and the pre-ship multi-category checklist concept shaped v1.0.0's reviewer/debugger/pre-ship commands and `executor.md`'s Prove-It rule. v2.0.0 removed the SEA-owned review/debug/ship commands in favor of composition with this plugin. The `agents/_common.md` operating-behaviors constitution (surface assumptions, manage confusion, push back, enforce simplicity, stop-the-line) is modeled on their `using-agent-skills` meta-skill.
- **[anthropics/skills](https://github.com/anthropics/skills)** — the progressive disclosure architecture (SKILL.md + `references/` split), the "pushy description" guidance (Claude tends to under-trigger skills), and the [agentskills.io](https://agentskills.io) spec compliance rules (frontmatter fields, name format, 500-line recommendation) shaped SEA's SKILL.md structure, description rewriting, and CI validation.
- **[obra/superpowers](https://github.com/obra/superpowers)** — the subagent-driven development pattern and the per-agent `MEMORY.md` convention predate SEA and inform how SEA uses Claude Code's native subagent `memory: project` field.

None of these plugins are dependencies. SEA composes with them at the user's option via standard skill triggering (see "Related plugins" above). Industry-standard concepts like TDD, conventional commits, atomic git commits, and code review aren't attributed here — those predate all of us.

If you notice a pattern in SEA that's missing attribution above, open an issue — intellectual credit is worth the round trip.

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
