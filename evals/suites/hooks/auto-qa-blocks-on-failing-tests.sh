#!/usr/bin/env bash
# Verify auto-qa emits {decision:"block"} when tests fail.
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$REPO_ROOT/evals/lib/assert.sh"
source "$REPO_ROOT/evals/lib/fixtures.sh"

WORKDIR="$(fixture_repo node-basic)"
fixture_state "$WORKDIR" executing
trap 'rm -rf "$WORKDIR"' EXIT

# Rewrite package.json so "npm test" exits 1.
cat > "$WORKDIR/package.json" <<'JSON'
{
  "name": "node-basic-fixture",
  "version": "0.0.0",
  "private": true,
  "scripts": {
    "test": "exit 1"
  }
}
JSON

# Create the .needs-verify marker (attempt 0) so the hook runs.
echo "0" > "$WORKDIR/.sea/.needs-verify"

output="$(cd "$WORKDIR" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$REPO_ROOT/hooks/auto-qa" <<< '{"stop_hook_active":false}')"

assert_jq "$output" '.decision' '== "block"' \
    "auto-qa should block when tests fail"
