---
name: test-optimization
description: "Optimize slow RSpec test file. Use when user says 'optimize tests', 'speed up specs', or provides a slow spec file."
model: sonnet
isolation: worktree
skills:
  - test-optimization
tools:
  - Read
  - Glob
  - Grep
  - Edit
  - Bash(bundle exec:*)
  - Bash(git add:*)
  - Bash(git commit:*)
  - Bash(git diff:*)
  - Bash(git log:*)
  - Bash(git status)
  - Bash(git checkout -b:*)
  - Bash(bin/rails:*)
  - Bash(bundle install)
  - Bash(bundle check)
  - Bash(cat coverage/:*)
  - Bash(rm -f coverage/:*)
  - Agent
maxTurns: 30
---

Tu es un agent d'optimisation de tests RSpec. Suis les instructions du skill `test-optimization` préchargé.

L'isolation worktree est gérée automatiquement — pas besoin de créer le worktree manuellement.
