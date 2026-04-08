# Kaizen -- Finalisation PR referentiel-tiptap-url
Date: 2026-03-31 | Skill: create-pr, feature-implementation | Score: 7/10

## Ce qui s'est passe
- Revue du plan d'implementation : 6.1-7.3 etaient deja faits mais le fichier plan les marquait encore "A FAIRE"
- Decision de reporter les maintenance tasks (8.1-8.2 backfill) dans une PR separee — PR deja chargee (19 commits, 33 fichiers, +1030 lignes)
- Tentative de creation de screenshots via spec Capybara dediee — bloquee par Vite build casse (`@lingui/vite-plugin` manquant)
- Creation de la PR sur GitHub via le skill create-pr

## Ce qui s'est bien passe
- Le mapping git log vs plan a ete rapide et clair pour le user
- La PR a ete creee proprement du premier coup avec le bon format (remote mfo, head mfo:branch, repo upstream)
- Le user a valide titre + description sans retouche

## Ce qui s'est mal passe
- Le fichier `referentiel-tiptap-url-plan.md` n'etait pas a jour (6.1-7.3 marques "A FAIRE" alors que deja commits) — source de confusion potentielle entre sessions
- Screenshots Capybara : le spec a ete ecrit mais n'a pas pu tourner (Vite build casse par dep manquante @lingui/vite-plugin). Le user a du intervenir manuellement (`bun install`) puis a abandonne les screenshots
- J'ai lance `rails runner` pour inspecter la base dev alors que le user voulait utiliser les system tests — mauvaise lecture de l'intention

## Ce qu'on a appris
- (a remplir par le dev)

## Permissions bloquantes (demandees interactivement)

| Permission | Pourquoi |
|---|---|
| `Bash(bundle exec rspec ...)` | Lancement des specs systeme screenshots |
| `Bash(bun install)` | Installation deps JS pour fix Vite build — refuse par le user qui l'a fait lui-meme |
| `Bash(rails runner ...)` | Inspection base dev — refuse, le user voulait rester dans les specs |

## Actions
- [ ] Mettre a jour le plan (`referentiel-tiptap-url-plan.md`) au fur et a mesure des commits pour eviter le decalage plan/realite -> skill feature-implementation
- [ ] Dans le skill create-pr, ajouter un rappel de verifier que Vite build fonctionne avant de tenter des screenshots systeme
- [ ] Quand le user demande des "captures", toujours clarifier : screenshots Capybara (dans les specs) vs screenshots manuels (navigateur dev) vs screenshots Playwright MCP — ne pas deviner
