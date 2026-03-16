# Kaizen — Extraction i18n oubliée lors de la migration
Date: 2026-03-15 | Skill: haml-migration | Score: 5/10

## Ce qui s'est passé
- Migration ExportDropdownComponent (HAML → ERB) : 4 commits corrects (screenshot HAML, migration, screenshot ERB, cleanup)
- Screenshots visuellement identiques, linter ✅, tests ✅
- MAIS : tous les textes français en dur dans le HAML ont été recopiés tels quels dans l'ERB sans extraction i18n
- Le skill haml-migration étape 3a dit explicitement : "Ne PAS laisser de texte français en dur dans les templates ERB" et demande d'extraire vers les fichiers i18n
- ~12 textes non extraits : "Standard", "A partir d'un modèle", "Fichier xlsx", "Annuler", "Demander l'export", etc.

## Ce qu'on a appris
- Le skill a la règle mais elle est noyée dans un paragraphe de l'étape 3a — Claude l'a ignorée. Il faut une checklist explicite avec une étape de validation automatisable (grep) pour que ce ne soit pas juste une consigne textuelle facile à rater.

## Action
- [ ] Renforcer la règle i18n dans le skill haml-migration étape 3a : ajouter un check explicite "lister tous les textes en dur dans le HAML source AVANT de convertir" -> `.claude/skills/haml-migration/prompt.md`
- [ ] Ajouter une étape de validation post-conversion : `grep -P '[a-zéèêëàâäùûüôöîïç]{3,}' fichier.html.erb` pour détecter les textes français restants -> `.claude/skills/haml-migration/prompt.md`
