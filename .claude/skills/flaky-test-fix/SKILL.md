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

- `test_names` — names of the flaky `it`/`scenario` blocks (stable across commits, use these to locate the tests)
- `lines` — line numbers where failures were observed (may drift between commits, prefer `test_names`)
- `merge_queue_count` — failures in merge queue branches (strongest flaky signal: no code change involved)
- `retry_count` — failures that passed on retry
- `branches` — which branches saw the failure
- `jobs` — which CI jobs failed

## Process

### 1. Understand the flaky test

Use `test_names` from the context to locate the specific flaky examples in the spec file. If `test_names` is empty, fall back to `lines` to find them.

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

Commit with `--no-gpg-sign`, then write `pr-description.md` :

```markdown
---
title: "Tech: stabiliser les tests flaky de <spec_file>"
---

# Probleme

Le fichier `<spec_file>` echoue de maniere intermittente en CI (<merge_queue_count> echecs merge queue, <retry_count> retries).

Tests concernes :
- `<test_name_1>`
- `<test_name_2>`

# Solution

Skill [`/flaky-test-fix`](https://github.com/mfo/night-shift/blob/main/.claude/skills/flaky-test-fix/SKILL.md)

### Causes identifiees et fixes

| Cause | Fix | Tests concernes |
|-------|-----|-----------------|
| <root cause 1> | <fix applied> | <test names> |
| <root cause 2> | <fix applied> | <test names> |

### Verification

Spec lance 10x en ordre aleatoire — 10/10 passes.

Generated with [Claude Code](https://claude.com/claude-code)
```

## Constraints

- Do NOT change test behavior — only fix isolation/timing issues
- Do NOT skip or quarantine the test — fix it
- Do NOT add `retry` mechanisms — fix the root cause
- Keep changes minimal — only touch the flaky spec and directly related helpers
