# Skills Index
<!-- Last updated: 2026-04-09 -->

## Skills (`.claude/skills/`)

| Name | Type | Description | Depends on | Files |
|---|---|---|---|---|
| bugfix | workflow | Investigate and fix bugs | review-3-amigos | SKILL.md, patterns.md |
| create-pr | workflow | Create GitHub PR | — | SKILL.md |
| dev-auto-login | utility | Setup dev auto-login | — | SKILL.md |
| feature-spec | pipeline | Architecture spec (Phase 0) | review-3-amigos | SKILL.md, checklist.md, template.md, pitfalls/*.md |
| feature-plan | pipeline | Commit plan (Phase 1) | review-3-amigos | SKILL.md, checklist.md, template.md |
| feature-implementation | pipeline | Execute plan (Phase 2) | — | SKILL.md, checklist.md, patterns.md |
| feature-review | pipeline | Post-impl review (Phase 3) | review-3-amigos | SKILL.md, checklist.md, template.md |
| haml-migration | workflow | HAML→ERB migration | dev-auto-login, rails-routes, screenshot-gist | SKILL.md |
| harden-audit | pipeline | Qualify vulnerability (DREAD) | — | SKILL.md, checklist.md, contract.md, patterns.md |
| harden-fix | pipeline | Fix vulnerability (TDD) | screenshot-gist | SKILL.md, checklist.md |
| harden-pentest | pipeline | White-box pentest | — | SKILL.md, checklist.md, patterns.md |
| kaizen | meta | Capture & apply learnings | — | SKILL.md |
| rails-routes | utility | Routes reference file | — | SKILL.md |
| review-3-amigos | internal | 3 Amigos review (PM+UX+Dev) | — | SKILL.md |
| screenshot-gist | internal | Screenshot→GitHub gist | — | SKILL.md |
| test-optimization | workflow | Optimize slow specs | — | SKILL.md, patterns.md, patterns-system.md, quickstart.md, template.md |
| til | workflow | Post TIL on PR | — | SKILL.md |

## Agents (`.claude/agents/`)

Wrappers agents pour les skills qui bénéficient de champs natifs (model, isolation, background, memory).

| Name | Skill source | Champ natif | Model |
|---|---|---|---|
| test-optimization | test-optimization | `isolation: worktree` | sonnet |
| harden-pentest | harden-pentest | `background: true` | sonnet |
| review-3-amigos | review-3-amigos | — | haiku |
| rails-routes | rails-routes | — | haiku |
| screenshot-gist | screenshot-gist | — | haiku |
| kaizen | kaizen | `memory: project` | sonnet |

**Invocation :** `/skill-name` (inline) ou `@agent-name` (isolé avec champs natifs).

## Pipelines

- **Feature** : feature-spec → feature-plan → feature-implementation → feature-review → create-pr
- **Security** : harden-pentest → harden-audit → harden-fix → create-pr
- **HAML** : rails-routes + dev-auto-login → haml-migration → create-pr
