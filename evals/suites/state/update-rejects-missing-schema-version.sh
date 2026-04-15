#!/usr/bin/env bash
# Verify that state-update.sh exits non-zero when required fields are missing.
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$REPO_ROOT/evals/lib/assert.sh"
source "$REPO_ROOT/evals/lib/fixtures.sh"

WORKDIR="$(fixture_repo empty)"
fixture_state "$WORKDIR" corrupted
trap 'rm -rf "$WORKDIR"' EXIT

exit_code=0
bash "$REPO_ROOT/scripts/state-update.sh" \
    --project-dir "$WORKDIR" last_commit=deadbeef 2>/dev/null || exit_code=$?

if [[ "$exit_code" -eq 0 ]]; then
    printf 'FAIL: expected non-zero exit for missing schema_version, got 0\n' >&2
    exit 1
fi
