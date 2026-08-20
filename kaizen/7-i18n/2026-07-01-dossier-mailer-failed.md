# Kaizen — i18n-hardcoded — dossier_mailer.rb — FAILED (no_diff)

**Date** : 2026-07-01
**Skill** : i18n-hardcoded
**Cible** : `app/mailers/dossier_mailer.rb`
**Outcome** : no_diff (5 tours, $0.31, 38.6s)

## Ce qui s'est passe

Le Runner a lance `claude -p` dans le worktree `auto-i18n-hardcoded-batch-4d078358`. Contrairement aux autres mailers du meme batch (administration_mailer, api_token_mailer, etc.), **le skill etait bien disponible** et a execute correctement.

Claude a :
1. Verifie le port (3220) et auto-login (absent)
2. Lu `app/mailers/dossier_mailer.rb` (255 lignes)
3. Analyse le fichier — aucun texte francais hardcode trouve
4. Ecrit `pr-description.md` avec le constat `no_diff`

**Conclusion de l'agent** : le fichier est deja correctement internationalise. Tous les sujets utilisent `default_i18n_subject`, les interpolations construisent des noms (prenom/nom), et `'termine'` est un suffixe technique de cle YAML.

## Cause racine

**Faux positif du backlog** : le fichier `dossier_mailer.rb` n'avait pas de strings francaises hardcodees a extraire. Le scanner de backlog l'a inclus sans verifier que le fichier etait deja i18n-compliant.

Cependant, l'agent n'a examine **que le fichier .rb**, pas les vues associees (`app/views/dossier_mailer/*.html.haml` ou `.erb`) qui pourraient contenir du texte francais hardcode. Le skill cible un fichier specifique, pas l'ensemble mailer+vues.

## Bien passe

- Le skill etait disponible et a tourne normalement (contrairement aux 4 autres mailers du batch).
- L'analyse est correcte : le `.rb` est effectivement propre cote i18n.
- Cout raisonnable ($0.31, 38s) pour un constat "rien a faire".

## Mal passe

- **$0.31 depenses pour constater qu'il n'y a rien a faire** — le scanner aurait du filtrer ce fichier en amont.
- **Scope trop etroit** : le skill n'a pas regarde les vues du mailer, qui sont la source la plus probable de texte francais hardcode dans un mailer.

## Appris

1. **Les mailers Rails sont souvent deja i18n-compliant cote .rb** grace a `default_i18n_subject`. Le texte hardcode est dans les vues, pas dans le controller mailer.
2. **Le scanner de backlog i18n a besoin d'un pre-filtre** : un `grep` rapide pour les strings francaises (guillemets avec accents, mots courants) eviterait de lancer le skill sur des fichiers propres.
3. **Ce cas est fondamentalement different des 4 autres echecs du batch** : skill disponible + execution correcte vs. skill introuvable + 0 tour. Le `no_diff` masque deux situations tres differentes.

## Permissions bloquantes

Aucune — 0 permission denied.

## Actions

| # | Action | Priorite |
|---|status: traité
date_synth: 2026-07-08
--------|----------|
| 1 | **Pre-filtre backlog i18n** : grep les fichiers pour des strings francaises avant de les ajouter au backlog, eliminer les fichiers sans match | P1 |
| 2 | **Elargir le scope du skill** : quand la cible est un mailer `.rb`, analyser aussi les vues associees dans `app/views/<mailer_name>/` | P2 |
| 3 | **Distinguer les causes de `no_diff`** dans les stats : "rien a changer" ($0.31) vs "skill absent" ($0) sont deux problemes differents | P1 |
