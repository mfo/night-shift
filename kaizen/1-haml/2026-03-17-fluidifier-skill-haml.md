# Kaizen — Fluidifier le skill haml-migration
Date: 2026-03-17 | Skill: haml-migration | Score: 5/10

## Ce qui s'est passé

### Freins permissions Bash
- `rm -rf /tmp/haml-migration` → permission refusée. Puis `rm -r` aussi refusé. Puis `mkdir -p` seul accepté. 3 allers-retours pour un simple reset de dossier temp.
- Le skill demande des commandes chaînées (`rm -rf … && mkdir -p`) mais le mode permission les bloque.

### Gist : directories non supportées
- Le skill demande de créer `haml/` et `erb/` dans le gist cloné, mais GitHub Gist ne supporte pas les répertoires → `remote rejected` au push. Fallback vers des fichiers à plat (`haml-xxx.png`, `erb-xxx.png`) = perte de temps.

### Gist : clone SSH échoue
- `git clone git@gist.github.com:…` → `Host key verification failed` dans le contexte Claude Code. Fallback HTTPS nécessaire.

### Gist : GPG sign au rebase
- `git pull --rebase` sur le gist → `gpg failed to sign the data` car le rebase crée un commit et GPG timeout. Il faut `-c commit.gpgsign=false` sur toutes les opérations git du gist.

### Screenshot Playwright : mauvais élément capturé
- `browser_take_screenshot` avec ref sur la `region` du dropdown capturait le header de la page (pas le bon élément). Nécessité de passer par `browser_run_code` avec un sélecteur CSS `.dropdown-export` ou `[id^="tabpanel-standard"]`.

### PR dupliquée
- Le skill dit "créer une PR" sans vérifier qu'une PR existe déjà sur la branche. Une PR #12795 a été créée alors que #12760 existait déjà.

### Remote origin vs mfo
- `git push origin` a échoué car origin = demarche-numerique (pas le fork). Le skill ne gère pas le cas multi-remote.

## Ce qu'on a appris
-

## Action
- [ ] Skill: remplacer `haml/` et `erb/` par des fichiers plats (`haml-*.png`, `erb-*.png`) dans les instructions gist → `.claude/skills/haml-migration/prompt.md`
- [ ] Skill: utiliser HTTPS (pas SSH) pour le clone gist → `.claude/skills/haml-migration/prompt.md`
- [ ] Skill: ajouter `-c commit.gpgsign=false` à toutes les commandes git du gist → `.claude/skills/haml-migration/prompt.md`
- [ ] Skill: vérifier si une PR existe (`gh pr list --head <branch>`) AVANT d'en créer une → `.claude/skills/haml-migration/prompt.md`
- [ ] Skill: détecter le bon remote (fork utilisateur vs origin) pour le push → `.claude/skills/haml-migration/prompt.md`
- [ ] Skill: utiliser `browser_run_code` avec sélecteur CSS pour les screenshots de composants dans un dropdown (pas `browser_take_screenshot` avec ref) → `.claude/skills/haml-migration/prompt.md`
- [ ] Skill: simplifier le nettoyage `/tmp/haml-migration` — une seule commande `mkdir -p` suffit si le dossier est réutilisable → `.claude/skills/haml-migration/prompt.md`
