#!/usr/bin/env bash
# Verify auto-qa exits 0 without a block decision when tests pass.
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$REPO_ROOT/evals/lib/assert.sh"
source "$REPO_ROOT/evals/lib/fixtures.sh"

WORKDIR="$(fixture_repo node-basic)"
fixture_state "$WORKDIR" executing
trap 'rm -rf "$WORKDIR"' EXIT

# node-basic has "test": "echo ok" — tests pass.
# Create the .needs-verify marker so the hook runs.
echo "0" > "$WORKDIR/.sea/.needs-verify"

output="$(cd "$WORKDIR" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$REPO_ROOT/hooks/auto-qa" <<< '{"stop_hook_active":false}')"
exit_code=$?

# On success the hook exits 0 with no output (marker is removed).
assert_eq "0" "$exit_code" "auto-qa should exit 0 when tests pass"

# No block decision should appear in output.
if printf '%s' "$output" | jq -e '.decision == "block"' >/dev/null 2>&1; then
    printf 'FAIL: auto-qa emitted block despite passing tests\n  output: %s\n' "$output" >&2
    exit 1
fi

# Marker should be cleaned up.
if [[ -f "$WORKDIR/.sea/.needs-verify" ]]; then
    printf 'FAIL: .needs-verify marker was not removed after passing tests\n' >&2
    exit 1
fi
