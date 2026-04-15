#!/usr/bin/env bash
# Asserts prompt-quality patterns are installed in agent files.
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

# Rule 7 present in _common.md
grep -q 'Evidence-Bearing Exit Reports' agents/_common.md \
  || fail "_common.md missing Rule 7 (Evidence-Bearing Exit Reports)"

# Each write-critical agent has Step 0 comprehension check
for agent in researcher planner executor; do
  grep -q 'Demonstrate Comprehension' "agents/${agent}.md" \
    || fail "${agent}.md missing Step 0 (Demonstrate Comprehension)"
  grep -q 'UNDERSTOOD:' "agents/${agent}.md" \
    || fail "${agent}.md missing UNDERSTOOD: output format"
done

# verifier.md intentionally skipped — no Step 0 by design
if grep -q 'Demonstrate Comprehension' agents/verifier.md 2>/dev/null; then
  fail "verifier.md should NOT have Step 0 — it is intentionally excluded"
fi

# Planner schema includes scope bounds
grep -q 'Allowed paths\|allowed_paths' agents/planner.md \
  || fail "planner.md missing allowed_paths / Allowed paths in plan schema"
grep -q 'Forbidden paths\|forbidden_paths' agents/planner.md \
  || fail "planner.md missing forbidden_paths / Forbidden paths in plan schema"

# Executor has pre-commit scope check
grep -q 'Pre-commit Scope Check\|Pre-commit scope check' agents/executor.md \
  || fail "executor.md missing pre-commit scope check"
grep -q 'scope violation' agents/executor.md \
  || fail "executor.md missing scope-violation STATUS format"

echo "prompt-quality.sh: all checks passed"
