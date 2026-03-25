# Kaizen — Screenshots paresseux et tag.attributes

Date: 2026-03-17 | Skill: haml-migration | Score: 5/10

## Ce qui s'est passé
- Migration de 5 composants simples (1-3 lignes HAML)
- Les screenshots ont été mal gérés au départ : le premier run a skipé presque toutes les captures avec des excuses ("trop complexe", "turbo_stream only", "inline trivial")
- L'utilisateur a dû demander explicitement de refaire les captures proprement
- En refaisant : SimpleFormatComponent capturé sur page réelle, AutosaveNoticeComponent capturé via preview ViewComponent créé à la volée, ColumnTableHeaderComponent capturé sur page instructeur réelle
- Bug découvert sur ColumnTableHeaderComponent : `tag.attributes(**hash)` → `tag.attributes(hash)` (positionnel, pas kwargs)
- Le patch auto-login avait un conflit avec `CommencerController#sign_in` → fix avec `warden.set_user`

## Ce qu'on a appris
-

## Action
- [ ] Ajouter dans le skill : `tag.attributes` prend un hash **positionnel** (`tag.attributes(hash)`), PAS des kwargs (`tag.attributes(**hash)`) → `.claude/skills/haml-migration/SKILL.md`
- [ ] Ajouter dans le skill : quand auto_sign_in_dev_user, utiliser `warden.set_user(user, scope: :user)` au lieu de `sign_in(user, scope: :user)` pour éviter les conflits avec les controllers qui redéfinissent `sign_in` → `.claude/skills/haml-migration/SKILL.md`
- [ ] Renforcer dans le skill : ne JAMAIS skipper les captures par flemme. Être agressif : preview ViewComponent si pas de page réelle, essayer au moins 3 approches avant de déclarer un skip → `.claude/skills/haml-migration/SKILL.md`
- [ ] Ajouter dans le skill : la route instructeur est `/procedures/:id` (pas `/instructeur/procedures/:id`) → `.claude/skills/haml-migration/SKILL.md`
