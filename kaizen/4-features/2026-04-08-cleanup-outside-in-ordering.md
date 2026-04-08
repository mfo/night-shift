# Kaizen -- Ordre outside-in pour les plans de cleanup
Date: 2026-04-08 | Skill: feature-plan | Score: ?/10

## Ce qui s'est passe
- Creation du plan d'implementation pour supprimer le code legacy referentiel (branches `use_tiptap?`)
- Plan initial proposait l'ordre classique DB → model → service → controller → view (inside-out)
- Premier reflexe : changer la factory d'abord → aurait casse toutes les specs
- User a propose d'inverser : vue → controller → service → model (outside-in)

## Ce qui s'est bien passe
- L'outside-in limite le blast radius de chaque commit : chaque couche externe n'impacte que sa propre spec
- Quand on arrive au model (le plus risque), tous les callers sont deja nettoyes → blast radius reduit aux model specs
- Factory evolue en 2 temps : additive d'abord (commit 1), cleanup en dernier (commit 9)

## Ce qui s'est mal passe
- Le plan initial (inside-out) aurait casse des specs de controller/service en changeant le model
- La factory-first naive aurait cascade partout
- Dependance cachee detectee : le hidden_field `use_tiptap` dans la vue alimente les validations conditionnelles du model → ne peut etre retire qu'au commit model

## Ce qu'on a appris
- Pour un cleanup (suppression code mort), l'ordre outside-in (vue → controller → service → model) est plus sur que inside-out
- La factory doit etre additive d'abord (ajouter attrs sans casser le default), cleanup en dernier
- Les dependances cross-couches (ex: hidden field → validation model) doivent etre identifiees au planning pour savoir ce qu'on peut retirer quand

## Permissions bloquantes (demandees interactivement)

| Permission | Pourquoi |
|---|---|
| Aucune | Session de planning, pas d'execution |

## Actions
- [ ] Ajouter un pattern "Cleanup Outside-In" dans le feature-plan skill ou patterns.md -> `.claude/skills/feature-plan/checklist.md`
- [ ] Documenter la strategie factory additive → cleanup pour les migrations de colonnes -> `.claude/skills/feature-plan/template.md`
- [ ] Considerer une categorie kaizen `5-cleanup/` si ce pattern revient
