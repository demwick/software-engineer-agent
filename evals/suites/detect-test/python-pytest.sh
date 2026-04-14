#!/usr/bin/env bash
# Verify detect-test.sh returns the pytest command for a python-pytest fixture.
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$REPO_ROOT/evals/lib/assert.sh"
source "$REPO_ROOT/evals/lib/fixtures.sh"

WORKDIR="$(fixture_repo python-pytest)"
trap 'rm -rf "$WORKDIR"' EXIT

actual="$(bash "$REPO_ROOT/scripts/detect-test.sh" "$WORKDIR")"

assert_eq "pytest" "$actual" "python-pytest fixture should produce 'pytest'"
