#!/usr/bin/env bash
# Verify detect-test.sh returns the go test command for a go-modules fixture.
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$REPO_ROOT/evals/lib/assert.sh"
source "$REPO_ROOT/evals/lib/fixtures.sh"

WORKDIR="$(fixture_repo go-modules)"
trap 'rm -rf "$WORKDIR"' EXIT

actual="$(bash "$REPO_ROOT/scripts/detect-test.sh" "$WORKDIR")"

assert_eq "go test ./..." "$actual" "go-modules fixture should produce 'go test ./...'"
