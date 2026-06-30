---
name: flaky-test-fix
description: "Fix flaky RSpec tests identified by CI failure analysis. Backlog seeded by FlakyCiScanner (merge queue + retry signals)."
allowed-tools:
  - Read
  - Glob
  - Grep
  - Edit(app/*)
  - Edit(spec/*)
  - Edit(config/*)
  - Write(spec/*)
  - Write(pr-description.md)
  - Bash(git status)
  - Bash(git add:*)
  - Bash(git commit:*)
  - Bash(git diff:*)
  - Bash(git log:*)
  - Bash(git blame:*)
  - Bash(grep:*)
  - Bash(find:*)
  - Bash(bundle exec rspec:*)
  - Bash(bundle exec rubocop:*)
  - Bash(ls:*)
  - Bash(wc:*)
  - Agent
  - Skill(pr-description)
---

# Fix Flaky Test

You are fixing a flaky RSpec test. The test passes sometimes and fails sometimes with the same code — this is not a logic bug but a test isolation or timing issue.

## Input

The backlog item is a spec file path (e.g., `spec/system/admin_spec.rb`).
The context JSON contains flaky evidence:

- `merge_queue_count` — failures in merge queue branches (strongest flaky signal: no code change involved)
- `retry_count` — failures that passed on retry
- `branches` — which branches saw the failure
- `jobs` — which CI jobs failed

## Process

### 1. Understand the flaky test

Read the spec file. Identify which examples are likely flaky based on:
- Shared mutable state (instance variables, class variables, global state)
- Database state leaking between examples (missing cleanup, `let!` ordering)
- Time-dependent logic (`Time.now`, `Date.today`, timezone sensitivity)
- Async/race conditions (Capybara waits, JS rendering, background jobs)
- External service dependencies (API calls, file system, network)
- Random ordering sensitivity (`before(:all)` vs `before(:each)`)

### 2. Reproduce if possible

Run the spec in isolation:
```bash
bundle exec rspec <spec_file> --order random --seed <random>
```

Run it multiple times to try triggering the flakiness:
```bash
for i in $(seq 1 5); do bundle exec rspec <spec_file> --order random 2>&1 | tail -1; done
```

### 3. Fix the root cause

Common fixes by category:

**Database state leaks:**
- Replace `before(:all)` with `before(:each)`
- Add `DatabaseCleaner` strategy adjustments
- Use `create` instead of `create_list` when order matters

**Timing/async issues:**
- Replace `sleep` with proper Capybara matchers (`have_content`, `have_selector`)
- Use `using_wait_time(N)` for slow operations
- Wait for specific conditions instead of arbitrary delays

**Time-dependent:**
- Wrap in `travel_to` / `freeze_time` blocks
- Use relative time comparisons instead of absolute

**Shared state:**
- Move shared setup into `let` blocks (lazy) or `before(:each)` (eager)
- Reset class-level caches in `after(:each)`

**Random ordering:**
- Remove hidden dependencies between examples
- Ensure each example is self-contained

### 4. Verify the fix

Run the spec multiple times to confirm stability:
```bash
for i in $(seq 1 10); do bundle exec rspec <spec_file> --order random 2>&1 | tail -1; done
```

All 10 runs must pass.

### 5. Deliver

- Commit with `--no-gpg-sign`
- Write `pr-description.md` via the pr-description skill
- PR title: `fix(flaky): stabilize <spec_file>`

## Constraints

- Do NOT change test behavior — only fix isolation/timing issues
- Do NOT skip or quarantine the test — fix it
- Do NOT add `retry` mechanisms — fix the root cause
- Keep changes minimal — only touch the flaky spec and directly related helpers
