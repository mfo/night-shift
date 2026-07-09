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
- `job_urls` — direct links to the failed CI jobs (include in PR description)

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

### 3b. Reproduce the flaky (commit RED when possible)

Before applying the fix, try to **reproduce the failure deterministically** in a dedicated commit.
This proves the root cause and gives reviewers confidence the fix is not a placebo.

Common reproduction techniques:
- **PG sequence collision**: `ActiveRecord::Base.connection.execute("SELECT setval('<table>_id_seq', 1, false)")` in a `let` or `before` block to force low auto-generated IDs that collide with explicit test data
- **CI seed replay**: `bundle exec rspec <file> --seed <seed_from_ci_log>`
- **Time travel**: `travel_to` to a boundary time (midnight, DST transition, end of month)
- **Ordering**: run the full suite or a subset that triggers the ordering dependency

**Decision criteria** — attempt reproduction when:
- The root cause hypothesis is clear (you know exactly what condition triggers the failure)
- The reproduction can be expressed as a small, self-contained change (1-3 lines)
- Cost is low: a `let` override, a `before` hook, or a CLI flag — not a complex test harness

**Skip reproduction** when the flake is inherently non-deterministic (true race condition in async JS, network timing) or the reproduction setup would be more complex than the fix itself.

If reproduction succeeds:
1. Commit the reproduction change with message: `test(<Component>): reproduce flaky via <technique>` and a note that the commit is intentionally RED
2. Then apply the fix in a separate commit (the reviewer sees RED → GREEN)

### 4. Verify the fix

Run the stress test script. **Target specific examples by line** to avoid running the entire file (critical for system specs) :

```bash
bash ~/dev/night-shift/.claude/skills/flaky-test-fix/verify-flaky.sh <spec_file>:<line>
```

The script adapts iterations (20 for system specs, 50 for unit) and captures seeds. It must exit 0 (STABLE). If it exits 1 (FLAKY), use the printed seed to replay and investigate further.

If multiple examples were fixed, run the script once per example.

### 5. Deliver

Commit with `--no-gpg-sign`, then write `pr-description.md`.

**Parser la sortie de `verify-flaky.sh`** pour chaque test fixe : extraire le nombre de runs et le resultat (STABLE/FLAKY). Ces donnees alimentent la section "Preuve de stabilite" de la PR.

```markdown
---
title: "Tech: stabiliser les tests flaky de <spec_file>"
---

# Probleme

Le fichier `<spec_file>` echoue de maniere intermittente en CI.

### Evidence CI

| Signal | Count | Signification |
|--------|-------|---------------|
| Merge queue | <merge_queue_count> echecs | Pas de changement de code → preuve forte de flakiness |
| Retries | <retry_count> passes au retry | Le test est instable |

Branches concernees : `<branch1>`, `<branch2>`
Jobs : [`<job1>`](<job_url_1>), [`<job2>`](<job_url_2>)

Tests concernes :
- `<test_name_1>`
- `<test_name_2>`

# Solution

Skill [`/flaky-test-fix`](https://github.com/mfo/night-shift/blob/main/.claude/skills/flaky-test-fix/SKILL.md)

### Causes identifiees et fixes

| Cause | Scope | Fix | Pourquoi ca resout |
|-------|-------|-----|--------------------|
| <root cause 1> | test / app | <fix applied> | <explication en 1 ligne> |
| <root cause 2> | test / app | <fix applied> | <explication en 1 ligne> |

### Preuve de stabilite

| Test | Runs | Resultat | Type |
|------|------|----------|------|
| `<test_name_1>` | 20/20 | ✅ STABLE | system |
| `<test_name_2>` | 50/50 | ✅ STABLE | unit |

Script : [`verify-flaky.sh`](https://github.com/mfo/night-shift/blob/main/.claude/skills/flaky-test-fix/verify-flaky.sh) (20 runs system, 50 runs unit, random seed a chaque run)

Generated with [Claude Code](https://claude.com/claude-code)
```

## Contraintes

- **Ne JAMAIS modifier du code métier (app/) pour un problème de données de test.** Si la flakiness vient d'une collision d'IDs, d'un ordering de factory, ou d'un état de test mal isolé, le fix appartient à 100% au test. Le test litmus : "est-ce que ce changement app aurait du sens si aucun test n'était flaky ?" — si non, c'est un fix test.
- Modifier du code app UNIQUEMENT pour une vraie race condition app (controller JS, flux async, morph timing) — ajouter des waits dans le test ne fait que masquer le vrai bug
- Ne PAS skip ou quarantine le test — le fixer
- Ne PAS ajouter de mecanisme `retry` — fixer la root cause
- Changements minimaux — ne toucher que le spec flaky et le code directement responsable de la race condition
