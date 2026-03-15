# Kaizen -- Screenshots dans tmp/ gitignored
Date: 2026-03-15 | Skill: haml-migration | Score: 6/10

## Ce qui s'est passé
- Migration de `administrateurs/procedures/transfert.html.haml` → ERB
- Screenshots HAML/ERB stockés dans `tmp/screenshots/` (gitignored)
- Impossible de committer les screenshots comme preuve de non-régression
- Le plan de commits intermédiaires avec screenshots ne fonctionnait pas

## Ce qu'on a appris
- `tmp/` est gitignored → les screenshots doivent aller dans `docs/migrations/screenshots/`

## Action
- [x] Changer le chemin des screenshots `tmp/screenshots/` → `docs/migrations/screenshots/` -> `.claude/skills/haml-migration/SKILL.md`
