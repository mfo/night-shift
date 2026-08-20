---
name: 2026-07-07-demande-item-component-failed
description: i18n-hardcoded no_diff sur DemandeItemComponent — ViewComponent pass-through sans texte français
metadata:
  type: kaizen
status: traité
date_synth: 2026-07-08
---

# i18n-hardcoded failed on attachment/demande_item_component.rb (reason: no_diff)

## Ce qui s'est passé

Le scanner du backlog a flaggé `app/components/attachment/demande_item_component.rb` comme contenant du texte français en dur. Le skill `/i18n-hardcoded` a été lancé (worktree `auto-i18n-hardcoded-batch-521c696c`), 6 turns, 166s, $0.37.

## Bien passé

- Le skill a correctement identifié qu'il n'y a aucun texte français à extraire
- Le fichier Ruby est une classe pass-through (10 lignes : `attr_reader`, `initialize`, rien d'autre)
- Le template ERB (5 lignes) ne contient que du HTML structurel et des `render` d'autres composants — zéro chaîne affichée
- Aucune permission refusée, aucun fichier introuvable, aucune boucle/retry
- Le `pr-description.md` a été créé documentant l'absence de texte

## Mal passé

- **Faux positif scanner** : le fichier a été flaggé sur la base de son path (`app/components/`) sans vérification préalable de la présence de chaînes françaises
- **Coût gaspillé** : $0.37 + 166s de temps skill + un slot pipeline consommé pour un fichier qui n'a rien à extraire
- **Pas de diff** → le pipeline marque `no_diff`, ce qui déclenche un `Judge` inutile

## Appris

7e faux positif i18n de ce type. Le scanner ne distingue pas les ViewComponents purement structurels (qui délèguent le rendu à d'autres composants) des fichiers avec du vrai texte français en dur. La classe Ruby est un cas extrême : zéro ligne de texte, juste une classe d'initialisation.

Liens : [[2026-07-07-context-failed]], [[2026-07-06-application-component-ok]], [[2026-07-01-blank-mailer-failed]], [[2026-07-01-mailer-monitoring-concern-failed]]

## Actions

1. **Scanner i18n** : ajouter une étape de pré-scan qui grep pour des patterns français (`[A-Za-zéèêàâùûôœç]` + mots français courants) avant de créer un backlog item. Si zéro match, skip direct.
2. **Pipeline** : pour `no_diff` sur `i18n-hardcoded`, ne pas envoyer au `Judge` — c'est un succès silencieux (le fichier est déjà i18n-compliant). Ajouter `VerdictName::AlreadyCompliant` ou skip directement.
3. **Coût** : $0.37 par faux positif × ~10 occurrences estimées = $3.70 gaspillé. Le pré-scan coûte ~$0.00 (un grep local).
