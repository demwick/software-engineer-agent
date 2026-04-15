# Phase 2 Plan: input validation

## Context
Sample plan demonstrating per-task scope bounds for eval fixtures.
Extends the trivial greet fixture with an API validation layer.

## Complexity
medium

## Pipeline
- medium → executor + verifier

## Tasks

### Task 1: add validation to greet endpoint
- **What:** validate non-empty name parameter in greet function
- **Files:** src/greet.py (modified)
- **Steps:**
  1. add guard clause for empty string
  2. raise ValueError with message
- **Verification:** `python -c "from greet import greet; greet('')"` → raises ValueError
- **Commit:** `feat(greet): add input validation`
- **Allowed paths:** src/greet.py, tests/test_greet.py
- **Forbidden paths:** src/auth/**, src/database/**

### Task 2: add test for validation
- **What:** write test covering the empty-name error path
- **Files:** tests/test_greet.py (new)
- **Steps:**
  1. write pytest test asserting ValueError on empty string
- **Verification:** `pytest tests/test_greet.py -v` → 1 passed
- **Commit:** `test(greet): add validation test`
- **Allowed paths:** tests/test_greet.py
- **Forbidden paths:** src/**, config/**

### Task 3: update README
- **What:** document the new validation behaviour
- **Files:** README.md (modified)
- **Steps:**
  1. add one paragraph under Usage
- **Verification:** `grep -c 'ValueError' README.md` → 1
- **Commit:** `docs(readme): document greet validation`
- **Allowed paths:** README.md
- **Forbidden paths:** src/**, tests/**
