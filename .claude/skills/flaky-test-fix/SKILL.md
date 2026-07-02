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
  - Bash(bash ~/dev/night-shift/.claude/skills/flaky-test-fix/verify-flaky.sh:*)
  - Bash(ls:*)
  - Bash(wc:*)
  - Agent
  - Skill(pr-description)
---

# Fix Flaky Test

You are fixing a flaky RSpec test. The test passes sometimes and fails sometimes with the same code. The root cause can be in the test (isolation, timing) or in the app code (race condition, async flow).

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

### 1b. Classify the root cause

Determine if the flakiness is:
- **Test-side** : shared state, missing cleanup, bad ordering → fix in spec only
- **App-side** : race condition in JS controller, async flow bug → fix in app code

For system specs involving Turbo Stream or Stimulus interactions:
1. Identify which Stimulus controller handles the form/interaction
2. Read the controller source (`app/javascript/controllers/<name>_controller.ts`)
3. Look for: abort patterns, concurrent fetches, morph timing assumptions

If the root cause is app-side, the fix belongs in the app code — adding waits in the test only masks the bug.

### 2. Reproduce if possible

Run the spec in isolation:
```bash
bundle exec rspec <spec_file> --order random
```

If the context contains failing CI seeds, replay them to confirm the flake:
```bash
bundle exec rspec <spec_file> --seed <seed_from_ci>
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

**Turbo Stream / Stimulus race conditions (system specs):**
- Distinguish server commit from DOM morph — `have_content('Saved')` proves the server
  committed, NOT that the morph landed. Wait for a DOM element specific to the new state
  (e.g., `have_field('Cadastres')` after switching to carte type)
- Serialize interactions: wait for each step to persist before the next change event
  (fill → wait DB persisted → check → wait DB persisted), don't overlap
- If the race is in the JS controller (e.g., aborting in-flight re-renders),
  fix the controller — adding waits in the test only masks the bug

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

Run the stress test script. **Target specific examples by line** to avoid running the entire file (critical for system specs) :

```bash
bash ~/dev/night-shift/.claude/skills/flaky-test-fix/verify-flaky.sh <spec_file>:<line>
```

The script adapts iterations (20 for system specs, 50 for unit) and captures seeds. It must exit 0 (STABLE). If it exits 1 (FLAKY), use the printed seed to replay and investigate further.

If multiple examples were fixed, run the script once per example.

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

| Cause | Scope | Fix | Tests concernes |
|-------|-------|-----|-----------------|
| <root cause 1> | test / app | <fix applied> | <test names> |
| <root cause 2> | test / app | <fix applied> | <test names> |

### Verification

`verify-flaky.sh` : <passed>/<runs> passes (system: 20 runs, unit: 50 runs).

Generated with [Claude Code](https://claude.com/claude-code)
```

## Contraintes

- Privilegier le fix dans le test. Mais si la root cause est une race condition app (controller JS, flux async), fixer le code app — ajouter des waits dans le test ne fait que masquer le vrai bug
- Ne PAS skip ou quarantine le test — le fixer
- Ne PAS ajouter de mecanisme `retry` — fixer la root cause
- Changements minimaux — ne toucher que le spec flaky et le code directement responsable de la race condition
