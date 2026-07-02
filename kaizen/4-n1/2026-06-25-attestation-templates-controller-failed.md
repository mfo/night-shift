---
name: attestation-templates-controller-failed
description: n1-query-fix échec sur attestation_templates_controller.rb — context overflow deepseek-v4-flash, pas de Prosopite dans le repo cible
metadata:
  type: kaizen
---

# n1-query-fix failed: attestation_templates_controller.rb

## Ce qui s'est passé

Session autolearn lancée sur `app/controllers/administrateurs/attestation_templates_controller.rb` dans un worktree (`auto-n1-query-fix-c-a-attestation_templates-f09cff`). Modèle deepseek-v4-flash (100k context). A duré 51 turns, coût $2.44, sans commit ni fix.

## Bien passé

- Aucun permission denied (0) — le skill a pu lire et analyser librement.
- 18 reads + 26 bash + 5 edits + 1 write = effort d'analyse substantiel.
- L'analyse statique a été poussée : lecture du controller, des modèles, des validators, tentative de comprendre le pattern N+1.

## Mal passé

1. **Prosopite patch incompatible** (Step 0). Le patch pour ajouter prosopite au Gemfile a échoué :
   - `patch failed: Gemfile.lock:328` — format du lock diffère de l'attendu
   - `patch failed: config/environments/test.rb:35` — idem
   - La recherche de `prosopite` dans le Gemfile est restée vide → pas installé dans le repo cible
2. **Context window overflow** (deepseek-v4-flash, 100k limit). Prompt atteint 100469 tokens → API Error 400. Le même pattern que dossier_spec_failed.md.
3. **51 turns sans aboutir** : le skill a tourné longtemps sur l'analyse sans jamais passer en exécution de fix ou commit. Le cout $2.44 est perdu.

## Appris

- `deepseek-v4-flash` a un context window de **100k**, pas 200k (le champ `contextWindow: 200000` dans le log est un artefact modelUsage, pas la limite réelle). La limite réelle est 100k → les sessions autolearn doivent être plus courtes.
- Le skill `n1-query-fix` suppose que Prosopite est installable via un patch standard — ce n'est pas garanti dans n'importe quel repo (Gemfile.lock variable).
- La boucle d'analyse sans limite de turns/tokens est dangereuse : 51 turns c'est trop pour un modèle à petit context.

## Permissions bloquantes

Aucune. Le modèle avait accès à tout (acceptEdits). Le blocage est technique : limite contextuelle.

## Actions

- [ ] **Limiter les turns autolearn** pour deepseek-v4-flash : ajouter un `max_turns` ou `max_cost` dans le Pipeline / Runner pour couper avant overflow.
- [ ] **Détecter le context window réel** du modèle dans le Runner et ajuster le budget de la session en conséquence.
- [ ] **Rendre Step 0 resilient** : si le patch Prosopite échoue, installer prosopite via `bundle add prosopite` plutôt que `patch`. Si `bundle add` échoue aussi, skip Step 0 et faire l'analyse statique uniquement.
- [ ] **Éviter le modèle deepseek-v4-flash** pour les sessions longues (N1 query fix, test optimization) — utiliser un modèle avec 200k+ context ou forcer `fast_mode: false` pour avoir Opus.
- [ ] Voir [[2026-06-17-dossier-spec-failed]] — même cause racine (context overflow deepseek). Une solution commune aux deux skills est nécessaire.
