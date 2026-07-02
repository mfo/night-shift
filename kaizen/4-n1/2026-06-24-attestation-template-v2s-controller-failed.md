---
name: 2026-06-24-attestation-template-v2s-controller-failed
description: n1-query-fix autolearn failure on AttestationTemplateV2sController — no_diff after 43 turns
metadata:
  type: kaizen
  category: n1-query-fix
  iteration: 1
---

# N1-Query-Fix Failed: AttestationTemplateV2sController

## Ce qui s'est passé

Le skill `n1-query-fix` a été lancé en mode autolearn sur `app/controllers/administrateurs/attestation_template_v2s_controller.rb` (score 13, 3 patterns N+1). La session a duré 40 minutes (43 turns, 1.5M tokens cache read, 6.7K output) et s'est terminée sans commit — verdict `no_diff`.

## Bien passé

- **Setup Prosopite** : malgré l'échec du patch (Gemfile.lock/test.rb décalés), le skill a ajouté manuellement `prosopite` + `pg_query`, configuré l'initializer, spec_helper, et test.rb. `bundle install` OK.
- **Tests pass** : les 33 specs du controller passent.
- **Analyse statique** : lecture du controller, des vues (show, edit, form, sticky_header, fixed_footer), du `preload_revisions`, et début de lecture de `ProcedureRevisionPreloader`.

## Mal passé

1. **Patch Prosopite obsolète** : `prosopite-setup.patch` ne s'applique plus sur le code actuel — les lignes de Gemfile.lock et test.rb ont divergé. Le contournement manuel a fonctionné mais a coûté des turns.
2. **Prosopite n'a rien détecté** : aucun N+1 dans le log. Les fixtures de test ont un seul record par association, donc Prosopite ne peut pas détecter de N+1 (besoin de 2+ records).
3. **Boucle d'analyse sans fin** : après 0 N+1 détecté, le skill a basé en analyse statique du code (controller → views → models → preloader) sans jamais arriver à une phase de fix. 43 turns pour lire et réfléchir sans appliquer de changement.
4. **Session coupée** : le dernier message est un `thinking` tronqué en plein milieu d'une commande `Read`. Le modèle a probablement saturé son contexte (deepseek-v4-flash, 200K window, 1.5M tokens de cache). Le `stop_reason: end_turn` avec `terminal: completed` suggère que Claude s'est arrêté sans erreur explicite, mais le `thinking` coupé indique une interruption.

## Appris

- **Prosopite a besoin de 2+ records par association** : le scanner ne détecte pas les N+1 quand les fixtures ont un seul record. Le skill doit enrichir les fixtures avec plusieurs records AVANT de lancer Prosopite.
- **Patch partagé fragile** : le prosopite-setup.patch est un diff stocké dans night-shift appliqué sur le worktree. Il dérive vite si le Gemfile.lock ou test.rb du projet cible change. Alternative : générer le setup dynamiquement dans le prompt plutôt qu'avec un patch.
- **43 turns sans fix = gaspillage** : si Prosopite ne détecte rien au premier run, le skill devrait soit enrichir les fixtures, soit s'arrêter et signaler "pas de N+1 reproductible". L'analyse statique seule n'a pas produit de fix.

## Actions

1. **Fixer le patch Prosopite** : mettre à jour `prosopite-setup.patch` pour qu'il s'applique sur le Gemfile.lock et test.rb actuels. Ou mieux, remplacer le patch par des instructions de setup inline dans le prompt du skill (plus robuste face aux divergences).
2. **Enrichir les fixtures avant Prosopite** : dans le skill, avant de lancer `rspec`, ajouter une étape qui crée 2+ records par association dans la fixture via `create_list`. Exemple : `create_list(:attestation_template, 3, :v2)` dans le test.
3. **Détecter et sortir de la boucle d'analyse** : si Prosopite ne détecte rien après 2 runs (avec fixtures enrichies), le skill doit écrire `Aucun N+1 reproductible détecté` et exit proprement — pas de analyse statique longue.
4. **Timeout / context guard** : le skill devrait surveiller sa progression — si après 15 turns aucun fix n'est appliqué, forcer un exit avec raison "analysis_exhausted" plutôt que de saturer le contexte.
5. **Vérifier le preloader** : `ProcedureRevisionPreloader` semble déjà précharger les révisions et leurs associations. Le N+1 peut être déjà résolu par ce preloader — le skill doit le vérifier tôt et ne pas fixer ce qui l'est déjà.
