---
name: 2026-07-06-application-component-ok
description: i18n-hardcoded OK sur application_component.rb — 0 strings, 6 turns, $0.35, scanner faux positif
metadata:
  type: kaizen
status: traité
date_synth: 2026-07-08
---

# Kaizen: i18n-hardcoded — ApplicationComponent (OK)

## Ce qui s'est passé

Le skill `i18n-hardcoded` a été lancé en auto sur `app/components/application_component.rb` dans le worktree `auto-i18n-hardcoded-batch-3c2e6a4c`. Le fichier est une classe de base de 25 lignes (includes, delegates, helpers) — **zero** texte français en dur. Le skill a :

1. Lu le fichier (25 lignes)
2. Identifié qu'il n'y avait aucun string à extraire
3. Écrit `pr-description.md` avec "Aucun texte hardcode trouvé"
4. Commit avec message `i18n(application_component): no hardcoded strings found — empty base class`
5. Terminé en 6 turns, 155s, $0.35

## Bien passé

- **Détection correcte** : le skill n'a pas forcé une extraction inutile — il a reconnu un fichier vide de strings et a fait un no-op commit propre.
- **Cache chaud** : 161k tokens en cache read, 40k en cache creation → bonne réutilisation du contexte.
- **0 permissions refusées** : pas de friction avec le permission mode.
- **Terminaison clean** : `end_turn` sans erreur.

## Mal passé

- **Faux positif du scanner** : `ApplicationComponent` est une classe purement technique (current_user, current_instructeur, etc.) — zero texte français. Le scanner a coûté $0.35 pour rien. C'est le même pattern que les faux positifs mailer-concerns ([[2026-07-01-mailer-monitoring-concern-failed]], [[2026-07-01-priority-delivery-concern-failed]], [[2026-07-01-blank-mailer-failed]]).
- **Git commit flag ordering** : le premier commit a échoué avec `fatal: options '-m' and '-c' cannot be used together` — le skill a mis `-c` après `-m` au lieu de `git -c commit.gpgsign=false commit`. Turn perdue.

## Appris

1. **Scanner i18n** : les classes de base ViewComponent (sans `render`, sans markup, sans strings) sont des faux positifs systématiques. Ajouter un filtre : ignorer les fichiers < 30 lignes qui n'ont que des `include`/`delegate`/`def` sans littéraux string.
2. **No-op cost** : un no-op i18n coûte ~$0.35 en moyenne. En batch, ces faux positifs s'accumulent. Le scanner doit les filtrer AVANT d'envoyer au skill.
3. **Git -c flag** : la commande correcte est `git -c commit.gpgsign=false commit -m "..."` (le `-c` est une option de `git`, pas de `commit`). À patcher dans le skill SKILL.md si ce pattern est utilisé.

## Permissions bloquantes

Aucune — 0 denials.

## Actions

- [ ] **Scanner i18n-hardcoded** : ajouter un filtre dans `BacklogSources::I18nHardcoded` pour ignorer les fichiers < 30 lignes sans aucun string littéral français (regex: pas de `"[^"]*[aeiouéèêëàâîôûç]"`). Test : `ApplicationComponent`, `MailerMonitoringConcern`, `PriorityDeliveryConcern`.
- [ ] **Skill i18n-hardcoded** : corriger la commande git commit dans `SKILL.md` — utiliser `git -c commit.gpgsign=false commit -m "..."` au lieu de `git commit -m "..." -c commit.gpgsign=false`. Ou mieux : configurer `commit.gpgsign=false` dans `.gitconfig` du worktree.
- [ ] **Batch i18n** : ajouter un `cost_warn` dans le pipeline — si un item batch coûte > $0.25 sans produire de diff, le signaler dans le rapport batch pour améliorer le scanner.

## Score : 6/10

Succès fonctionnel (bon diagnostic, commit clean) mais impact négatif (faux positif, $0.35 gaspillé). Le vrai problème est en amont dans le scanner.
