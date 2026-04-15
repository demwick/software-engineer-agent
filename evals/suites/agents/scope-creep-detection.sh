#!/usr/bin/env bash
# Structural simulation: verifies scope-violation detection logic.
# Tests the check logic, not an LLM run.
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

# Helper: glob match using case
glob_match() {
  local file="$1" pattern="$2"
  case "$file" in
    $pattern) return 0;;
    *) return 1;;
  esac
}

# Helper: check a file against allowed_paths list
check_allowed() {
  local file="$1"
  shift
  local patterns=("$@")
  for p in "${patterns[@]}"; do
    glob_match "$file" "$p" && return 0
  done
  return 1
}

# Helper: check a file against forbidden_paths list (returns 0 if safe, 1 if forbidden)
check_forbidden() {
  local file="$1"
  shift
  local patterns=("$@")
  for p in "${patterns[@]}"; do
    glob_match "$file" "$p" && return 1
  done
  return 0
}

# --- Test 1: in-scope file passes ---
allowed=("src/greet.py" "tests/test_greet.py")
forbidden=("src/auth/*" "src/database/*")

check_allowed "src/greet.py" "${allowed[@]}" \
  || fail "Test 1: src/greet.py should be in allowed_paths"
check_forbidden "src/greet.py" "${forbidden[@]}" \
  || fail "Test 1: src/greet.py should not match forbidden_paths"

# --- Test 2: forbidden file is detected ---
check_forbidden "src/auth/session.py" "${forbidden[@]}" \
  && fail "Test 2: src/auth/session.py should be detected as forbidden"

# --- Test 3: out-of-scope file (not in allowed) is detected ---
check_allowed "src/config/settings.py" "${allowed[@]}" \
  && fail "Test 3: src/config/settings.py should NOT be in allowed_paths"

# --- Test 4: fixture plan has scope fields ---
fixture="$REPO_ROOT/evals/fixtures/plans/sample-plan-with-scope.md"
[[ -f "$fixture" ]] || fail "Test 4: fixture plan missing at $fixture"
grep -q 'Allowed paths' "$fixture" \
  || fail "Test 4: fixture plan missing Allowed paths"
grep -q 'Forbidden paths' "$fixture" \
  || fail "Test 4: fixture plan missing Forbidden paths"

echo "scope-creep-detection.sh: all checks passed"
