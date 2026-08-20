---
name: 2026-07-07-attachment-row-component-failed
description: i18n-hardcoded no_diff sur Attachment::AttachmentRowComponent — déjà i18n-compliant, $0.47, 11 turns
metadata:
  type: kaizen
status: traité
date_synth: 2026-07-08
---

# i18n-hardcoded: Attachment::AttachmentRowComponent — no_diff

## Ce qui s'est passé

Le scanner a proposé `app/components/attachment/attachment_row_component.rb` pour le skill i18n-hardcoded. Le skill a été lancé, a analysé le fichier Ruby, le template ERB sidecar et les fichiers YAML FR/EN, et a conclu qu'aucun texte français hardcodé n'était présent. Toutes les chaînes étaient déjà extraites via `t()` et les fichiers YAML sidecar étaient complets.

Session : 11 turns, $0.466, terminé normalement (end_turn, completed).

## Ce qui a bien marché

- Le skill a correctement analysé le fichier (aucune boucle, aucun retry)
- Permission mode acceptEdits → 0 permissions refusées
- Le skill a bien écrit `pr-description.md` avec le résumé "aucun texte hardcode trouvé"

## Ce qui a mal marché

- **Faux positif scanner** : le fichier était déjà i18n-compliant, aucune extraction nécessaire
- **Coût gaspillé** : $0.466 pour un résultat nul (11 turns, 41k creation tokens)
- **Pas de diff** → pipeline marque `no_diff` → item marqué comme échec sans valeur ajoutée

## Ce qu'on a appris

Même pattern que les 7 autres kaizen i18n-hardcoded no_diff : le scanner est trop laxiste et propose des fichiers qui n'ont aucune string française hardcodée. `Attachment::AttachmentRowComponent` utilise le lazy lookup `t(".errors.virus_infected")` et `t(".errors.corrupted_file")` — le composant a été écrit correctement dès le départ.

## Permissions bloquantes

Aucune. Le mode acceptEdits n'a pas bloqué d'appels.

## Actions

- **Scanner plus strict** : le pré-scan grep proposé dans `2026-07-07-context-failed.md` s'applique ici aussi. Filtrer les fichiers qui ont des appels `t()` ou des sidecars YAML avant de les soumettre au skill. Cela couvrirait ce cas et les ~7 autres no_diff précédents.
- **Seuil de rentabilité** : à $0.466 par faux positif, le scanner doit avoir un taux d'erreur <20% pour que le pipeline reste rentable. Actuellement il est >80% sur les composants ViewComponent déjà traduits.
