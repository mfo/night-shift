# Techniques d'optimisation — System specs

**Complément à `patterns.md`** (techniques communes). À consulter en plus quand le fichier cible est dans `spec/system/`.

---

## Techniques par fichier (system specs)

| ID | Technique | Description | Signal de détection | Risque | Gain typique |
|---|---|---|---|---|---|
| S01 | sleep → assertions Capybara | Remplacer `sleep` par des assertions Capybara (`have_selector`, `have_content`, `have_current_path`). L'attente implicite de Capybara gère le timing. | `sleep` dans un fichier `spec/system/`. | Le `sleep` cachait peut-être un vrai problème de timing. | **Moyen** |
| S02 | réduire les navigations | Regrouper les assertions dans un même scénario au lieu de revisiter les mêmes pages dans des `it` séparés. Chaque `it` en system spec relance le browser setup + la navigation. **Variante "inline" (préférée)** : inliner les assertions d'un scénario dédié dans un workflow existant qui passe déjà par la même page. Élimine 1 login (~2-3s) + 1 création de données (~1s) par scénario supprimé, au prix de quelques assertions supplémentaires (~0s). Plus efficace que le merge de scénarios car on ne rajoute pas de visits. **Modèle de coût system spec** : coût réel d'un scénario = login (~2-3s) + création données (~1s) + visits. | Plusieurs `it` dans le même `describe` qui font `visit` sur la même page avec le même setup. Scénario dédié qui vérifie un détail visible dans un workflow plus large. | Perd la granularité des messages d'erreur — atténué par `aggregate_failures`. | **Fort** |
| S03 | pré-créer les factories + stub jobs | Pré-créer en DB les objets qu'un scénario produirait via l'UI (ex: créer des suggestions `completed` au lieu de visit + update par step). Stuber les jobs lourds (`perform_now`) pour éviter l'écrasement des données pré-créées. Élimine des visits et des exécutions de jobs. | Scénario qui fait N visits séquentiels pour construire un état intermédiaire (polling Turbo, wizard multi-steps). | Les données pré-créées peuvent diverger de ce que l'UI produit réellement (hash, timestamps, side effects). Vérifier la cohérence. | **Faible-Moyen** (~0.9s) |

<!-- Ajouter ici les nouvelles techniques system découvertes par les agents -->
