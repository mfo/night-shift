---
status: traité
date_synth: 2026-07-08
---

# Kaizen — i18n-hardcoded — mailer_monitoring_concern.rb — FAILED (no_diff)

**Date** : 2026-07-01
**Skill** : i18n-hardcoded
**Cible** : `app/mailers/concerns/mailer_monitoring_concern.rb`
**Outcome** : no_diff (5 tours, $0.26, 25.7s)

## Ce qui s'est passe

Le Runner a lance `claude -p` dans le worktree `auto-i18n-hardcoded-batch-afffd131`. Le skill a execute normalement :

1. Lu le fichier (23 lignes) — un concern SMTP avec `rescue_from`
2. Constate : zero string francaise, zero texte user-facing
3. Ecrit `pr-description.md` avec "Aucun texte hardcode trouve"

Les seules strings du fichier sont purement techniques : `"dispatch_error"` (statut interne EmailEvent) et `/unexpected recipients/` (regex anglaise). Pas meme de `I18n.t` — le fichier n'a aucun rapport avec l'i18n.

## Cause racine

**Faux positif du scanner de backlog**. Le fichier est un concern technique de monitoring SMTP (23 lignes). Il n'a jamais contenu de texte francais. Le scanner l'a inclus parce qu'il scanne tous les fichiers `app/mailers/**/*.rb` sans verifier la presence de strings francaises.

Meme cause racine que `dossier_mailer.rb` dans le meme batch, mais encore plus evident : 23 lignes, 100% technique, 0 texte humain.

## Bien passe

- Skill disponible, execution propre, analyse correcte.
- 0 permission denied, 0 erreur, 0 retry.
- L'agent a correctement identifie les strings comme techniques et non-extractibles.

## Mal passe

- **$0.26 pour constater "rien a faire" sur un fichier de 23 lignes** — le scanner aurait du l'eliminer avec un simple grep.
- C'est le **6e faux positif i18n du batch du 01/07** (apres administration_mailer, api_token_mailer, application_mailer, avis_mailer, dossier_mailer). Le probleme est systematique.

## Appris

1. **Les concerns de mailers ne contiennent jamais de texte user-facing** — ils gerent du plumbing technique (error handling, monitoring). Le scanner devrait exclure `app/mailers/concerns/` entierement.
2. **Cout cumule du batch** : 6 faux positifs × ~$0.30 = ~$1.80 depenses pour zero output. Le pre-filtre grep est rentabilise des le premier batch.

## Permissions bloquantes

Aucune — 0 permission denied.

## Actions

| # | Action | Priorite |
|---|--------|----------|
| 1 | **Exclure `concerns/` du scanner i18n** pour les mailers — ces fichiers sont toujours techniques | P1 |
| 2 | **Pre-filtre grep pour strings francaises** avant ajout au backlog (cf. kaizen dossier_mailer) | P1 |
| 3 | **Compteur de faux positifs par batch** dans les stats pour detecter les scanners defaillants | P2 |
