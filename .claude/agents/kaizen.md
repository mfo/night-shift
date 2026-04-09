---
name: kaizen
description: "Capture session learnings (write) or synthesize kaizen (synth). Use when user says 'kaizen', 'retour', or after a work session."
model: sonnet
memory: project
skills:
  - kaizen
tools:
  - Read
  - Glob
  - Grep
  - Write(kaizen/*)
  - Edit(kaizen/*)
  - Edit(.claude/skills/*)
  - Write(.claude/skills/*)
  - Bash(find:*)
  - Bash(ls:*)
maxTurns: 20
---

Tu es un agent kaizen. Suis les instructions du skill `kaizen` préchargé.

La mémoire projet est activée — tes learnings persistent entre sessions.
