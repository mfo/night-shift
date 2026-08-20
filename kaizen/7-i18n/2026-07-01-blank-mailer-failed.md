---
status: traité
date_synth: 2026-07-08
---

# Kaizen — i18n-hardcoded — blank_mailer.rb — FAILED (no_diff)

**Date** : 2026-07-01
**Skill** : i18n-hardcoded
**Cible** : `app/mailers/blank_mailer.rb`
**Outcome** : no_diff (5 tours, 843 output tokens, 0.256 USD, 24.7s)

## Ce qui s'est passe

Le Runner a lance `claude -p` dans le worktree `auto-i18n-hardcoded-batch-afffd131`. Contrairement aux autres mailers du batch (administration, api_token, application, avis), **le skill a bien demarre et s'est execute correctement**.

Sequence :
1. Read `blank_mailer.rb` (14 lignes)
2. Check port (3220) et auto-login (absent)
3. Analyse : aucune string francaise hardcodee — `subject`, `title`, `body` sont tous passes en parametres dynamiques
4. Write `pr-description.md` avec "Aucun texte hardcode trouve"
5. Fin propre, `no_diff` correct

## Cause racine

**Faux positif du BacklogScanner** : le scanner `I18nHardcoded` a inclus `blank_mailer.rb` dans le backlog alors que ce fichier n'a aucune string hardcodee a extraire. Le mailer est un passe-plat — il recoit tous ses textes en parametres.

Ce n'est pas un echec du skill, c'est un echec de tri en amont.

## Bien passe

- Le skill a fonctionne correctement (contrairement aux 4 autres mailers du batch ou `/i18n-hardcoded` etait inconnu).
- Detection rapide (5 tours) et terminaison propre.
- Le diagnostic "rien a extraire" est correct.

## Mal passe

- **0.256 USD gaspilles** pour un fichier qui n'avait rien a extraire. Sur un batch de 50 fichiers, les faux positifs s'accumulent.
- Le BacklogScanner ne filtre pas les fichiers ou toutes les strings sont dynamiques (parametres, variables).
- Le `no_diff` ne distingue pas "rien a extraire" (faux positif scanner) de "extraction echouee" (vrai echec skill).

## Appris

1. **Le scanner a besoin d'un pre-filtre statique** : un `grep` pour verifier la presence de strings francaises literales avant d'ajouter au backlog. Un fichier sans guillemets contenant du francais = pas candidat.
2. **Deux causes distinctes de `no_diff` dans ce batch** : skill absent (4 mailers) vs fichier sans contenu a extraire (blank_mailer). Meme statut final, causes opposees.
3. **Le cout par faux positif est non negligeable** : 0.256 USD et 25s pour un fichier de 14 lignes sans rien a faire.

## Permissions bloquantes

Aucune (`permission_denials: []`).

## Actions

| # | Action | Priorite |
|---|--------|----------|
| 1 | **Pre-filtre dans `BacklogSources::I18nHardcoded`** : `grep` pour des patterns de strings francaises literales avant d'ajouter au backlog (accents, mots frequents) | P1 |
| 2 | **Distinguer `no_diff` de `nothing_to_do`** : ajouter un statut ou flag pour differencier "le skill n'a rien trouve" de "le skill a echoue sans diff" | P2 |
| 3 | **Exclure les mailers passe-plat** : `blank_mailer.rb` et similaires (ou tous les parametres sont dynamiques) ne sont pas candidats i18n | P2 |
