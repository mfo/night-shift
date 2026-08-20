---
status: traité
date_synth: 2026-07-08
---

# Kaizen — i18n-hardcoded — devise_user_mailer.rb — FAILED (no_diff)

**Date** : 2026-07-01
**Skill** : i18n-hardcoded
**Cible** : `app/mailers/devise_user_mailer.rb`
**Outcome** : no_diff (6 tours, $0.265, 23.5s)

## Ce qui s'est passe

Le Runner a lance `claude -p` dans le worktree `auto-i18n-hardcoded-batch-afffd131`. Le skill etait disponible et a execute correctement.

Claude a :
1. Lu `app/mailers/devise_user_mailer.rb` (41 lignes)
2. Verifie le port (3220) et auto-login (absent)
3. Cherche le preview mailer (existe)
4. Conclu : aucun texte francais hardcode — le fichier utilise deja `I18n.with_locale(record.locale)`, des constantes (`APPLICATION_NAME`, `CONTACT_EMAIL`, `NO_REPLY_EMAIL`), et `super` pour deleguer a Devise
5. Ecrit `pr-description.md` avec le constat no_diff

## Cause racine

**Faux positif du scanner** : le fichier `devise_user_mailer.rb` (41 lignes) est un wrapper Devise minimaliste. Il ne contient aucune string francaise — tout est delegue a Devise via `super` et les constantes globales. Le scanner l'a inclus sans verifier le contenu.

## Bien passe

- Skill disponible, execution propre (contrairement aux 4 echecs "Unknown command" du meme batch).
- Diagnostic rapide et correct : 6 tours, $0.265, 23.5s — le plus efficace des mailers du batch.
- 0 permission denied.

## Mal passe

- **$0.265 pour constater qu'il n'y a rien a faire** — meme probleme que `dossier_mailer.rb` et `blank_mailer.rb`.
- Le fichier fait 41 lignes dont zero string francaise : un grep aurait suffi.

## Appris

1. **Les mailers Devise sont encore plus minimaux que les mailers applicatifs** — ils delegent tout a Devise via `super`. Candidats ideaux pour un pre-filtre.
2. **Pattern recurrent dans ce batch** : sur les 7 mailers testes, aucun n'avait de texte a extraire. Le scanner i18n est trop laxiste pour les mailers `.rb`.

## Permissions bloquantes

Aucune — 0 permission denied.

## Actions

| # | Action | Priorite |
|---|--------|----------|
| 1 | **Pre-filtre backlog i18n** : grep les fichiers `.rb` pour des strings francaises (guillemets + accents/mots courants) avant de les ajouter au backlog | P1 |
| 2 | **Exclure les wrappers Devise** : les mailers heritant de `Devise::Mailer` sont quasi-systematiquement propres — les exclure du scan ou scorer tres bas | P2 |
