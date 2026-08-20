---
name: i18n-hardcoded-user-mailer-failed
description: i18n-hardcoded no_diff on user_mailer.rb — file already fully i18n-compliant via default_i18n_subject, YAML fr.yml/en.yml already complete
metadata:
  type: kaizen
  category: i18n
  iteration: 1
status: traité
date_synth: 2026-07-08
---

# Kaizen — i18n-hardcoded: user_mailer.rb no_diff

## Ce qui s'est passé

Le pipeline a lancé le skill `/i18n-hardcoded` sur `app/mailers/user_mailer.rb` dans un worktree batch (`auto-i18n-hardcoded-batch-5714d6f8`).

## Ce qui s'est bien passé

- Le skill a été invoqué correctement (pas de "Unknown command")
- Le fichier a été lu, les caractères français ont été cherchés (grep → exit code 1 = aucun match)
- Les fichiers YAML `config/locales/views/user_mailer/fr.yml` (27 lignes) et `en.yml` (27 lignes) existent déjà et sont complets — 12 mail actions traduites
- Aucune permission refusée (`permission_denials: []`)
- Le skill a suivi le protocole "aucun texte trouvé" en créant `pr-description.md`
- Temps de réponse correct : 217s pour 8 turns, $0.39

## Ce qui s'est mal passé

- **Résultat : `no_diff`** — aucun changement n'a été produit, classé comme échec par le pipeline
- **Coût gaspillé : $0.39** pour une session qui ne pouvait rien produire
- **Faux positif scanner** : le scanner a sélectionné `user_mailer.rb` alors que le fichier est déjà 100% i18n-compliant

## Ce qu'on a appris

1. **Pattern détecté** : tous les mailers qui utilisent `default_i18n_subject` sont des faux positifs. C'est le 11ème kaizen de cette catégorie (voir [[2026-07-01-dossier-mailer-failed]], [[2026-07-01-blank-mailer-failed]], [[2026-07-01-mailer-monitoring-concern-failed]], [[2026-07-01-priority-delivery-concern-failed]], [[2026-07-01-devise-user-mailer-failed]], [[2026-07-07-context-failed]], et les précédents).
2. Le scanner dans `lib/nightshift/backlog_sources/i18n_hardcoded.rb` ne vérifie **pas** si le fichier contient effectivement des strings françaises — il ne fait qu'un scan par extension/nom.
3. Un mailer Rails "propre" utilise `default_i18n_subject` + YAML — c'est le pattern