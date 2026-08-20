---
name: 2026-07-07-context-failed
description: i18n-hardcoded no_diff sur Attachment::Context — classe technique sans texte français
metadata:
  type: kaizen
status: traité
date_synth: 2026-07-08
---

# i18n-hardcoded failed on attachment/context.rb (reason: no_diff)

## Ce qui s'est passé

Le scanner du backlog a flaggé `app/components/attachment/context.rb` comme contenant du texte français en dur. Le skill `/i18n-hardcoded` a été lancé (worktree `auto-i18n-hardcoded-batch-7a56b605`), 5 turns, 177s, $0.34.

## Bien passé

- Le skill a correctement identifié qu'il n'y a aucun texte français à extraire
- Le fichier est un value object technique pur (52 lignes, validation d'options, attributs de configuration)
- Le seul message est en anglais : `"Invalid view_as: #{@view_as}, must be :download or :link"`
- Aucune permission refusée, aucun fichier introuvable, aucune boucle/retry
- Le `pr-description.md` a été créé documentant l'absence de texte

## Mal passé

- **Faux positif scanner** : le fichier a été flaggé sur la base de son path (`app/components/`) sans vérification préalable de la présence de chaînes françaises
- **Coût gaspillé** : $0.34 + 177s de temps skill + un slot pipeline consommé pour un fichier qui n'a rien à extraire
- **Pas de diff** → le pipeline marque `no_diff`, ce qui déclenche un `Judge` inutile

## Appris

Le pattern se répète : c'est le 6e faux positif i18n de ce type. Le scanner ne distingue pas les fichiers purement techniques (value objects, concerns, wrappers Devise, pass-through) des fichiers qui ont du vrai texte français en dur.

Liens : [[2026-07-06-application-component-ok]], [[2026-07-01-blank-mailer-failed]], [[2026-07-01-mailer-monitoring-concern-failed]]

## Actions

1. **Scanner i18n** : ajouter une étape de pré-scan qui grep pour des patterns français (`[A-Za-zéèêàâùûôœç]` + mots français courants) avant de créer un backlog item. Si zéro match, skip direct.
2. **Pipeline** : pour `no_diff` sur `i18n-hardcoded`, ne pas envoyer au `Judge` — c'est un succès silencieux (le fichier est déjà i18n-compliant). Ajouter `VerdictName::AlreadyCompliant` ou skip directement.
3. **Coût** : $0.34 par faux positon × ~10 occurrences estimées = $3.40 gaspillé. Le pré-scan coûte ~$0.00 (un grep local).
