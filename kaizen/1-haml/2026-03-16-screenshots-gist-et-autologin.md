# Kaizen -- Screenshots gist et auto-login
Date: 2026-03-16 | Skill: haml-migration | Score: 5/10

## Ce qui s'est passé
- Migration de 2 composants : AutosaveNoticeComponent (simple, sans visuel) et AccountDropdownComponent (complexe, avec visuel)
- **Auto-login non fonctionnel** : le serveur était lancé depuis un autre répertoire, donc les modifications de `application_controller.rb` n'étaient pas prises en compte. Beaucoup de temps perdu à diagnostiquer (vérifier les logs, tester curl, inspecter la chaîne de before_action). Résolu quand l'utilisateur a relancé le serveur.
- **`gh gist create` ne supporte pas les fichiers binaires (PNG)** : le skill prescrit `gh gist create *.png` mais ça échoue avec "binary file not supported". Tentative data-URI dans un gist markdown → GitHub sanitise les data-URI. Solution finale : commit temporaire des screenshots, push, référence par raw URL avec SHA, puis suppression.
- **Premier composant (AutosaveNoticeComponent)** migré sans visuel car auto-login KO — composant très simple donc acceptable, mais l'utilisateur voulait tester le workflow visuel complet.
- **Screenshot fermé vs ouvert** : le dropdown DSFR se déploie en dehors du bounding box du `nav` element. Il a fallu utiliser `page.screenshot({ clip: ... })` avec les coordonnées combinées du bouton et du menu pour capturer l'ensemble.

## Ce qu'on a appris
- **`gh gist create` ne supporte pas les PNG** — et GitHub sanitise les data-URI dans le markdown des gists. Aucune des deux pistes "gist" ne fonctionne pour des images.
- **Énorme prio : trouver une solution pour inliner les captures d'écran directement dans les commentaires PR.** C'est le nerf de la guerre pour faciliter les reviews de migration. Sans images visibles dans la PR, la comparaison visuelle perd tout son intérêt.
- Le workaround commit temporaire + raw URL par SHA fonctionne mais c'est lourd (commit, push, suppression, re-push). Il faut une solution native.

## Action
- [ ] **Fix critique** : remplacer `gh gist create *.png` par l'approche commit temporaire + raw URL par SHA dans le skill → `.claude/skills/haml-migration/skill.md` (étape 6)
- [ ] Ajouter un prérequis dans le skill : vérifier que le serveur dev recharge bien le code modifié (faire un curl + grep dans les logs, ou toucher un fichier et vérifier le reload) → `.claude/skills/haml-migration/skill.md` (prérequis)
- [ ] Documenter la technique `page.screenshot({ clip: ... })` pour les composants dropdown/popover qui débordent de leur conteneur → `.claude/skills/haml-migration/skill.md` (étape 2)
- [ ] Ajouter permission Bash(`rm -rf /tmp/haml-migration`) dans les allowed-tools ou dans le skill (étape 0 bloquée par permission)
- [ ] Ajouter permission Bash(`base64 -i ...`) dans les allowed-tools (bloquée à l'étape 6)
