#!/usr/bin/env bash
# Verify detect-test.sh returns empty output for a repo with no recognised test runner.
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$REPO_ROOT/evals/lib/assert.sh"
source "$REPO_ROOT/evals/lib/fixtures.sh"

WORKDIR="$(fixture_repo empty)"
trap 'rm -rf "$WORKDIR"' EXIT

# Script exits 1 when no runner found; use || true to avoid crashing set -e.
actual="$(bash "$REPO_ROOT/scripts/detect-test.sh" "$WORKDIR" || true)"

assert_eq "" "$actual" "empty fixture should produce no output"
