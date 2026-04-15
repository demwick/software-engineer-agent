# Phase 1 Plan: trivial example

## Context
Sample trivial plan for eval fixtures.

## Complexity
trivial

## Pipeline
- trivial → executor

## Requirements

### R1: greet
Function returns a greeting string.

- **R1.1** function exists named `greet`
- **R1.2** returns "hello world"

## Tasks

### Task 1: implement greet
- **What:** add greet function
- **Covers:** R1.1, R1.2
- **Files:** src/greet.py (new)
- **Steps:**
  1. write function
- **Verification:** `python -c "from greet import greet; assert greet()=='hello world'"`
- **Commit:** `feat(greet): add greet function`

## Coverage Matrix

| Criterion | Task(s) | Check |
|---|---|---|
| R1.1 | T1 | task-coverage |
| R1.2 | T1 | task-coverage |
