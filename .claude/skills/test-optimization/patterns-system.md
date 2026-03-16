# Techniques d'optimisation — System specs

**Complément à `patterns.md`** (techniques communes). À consulter en plus quand le fichier cible est dans `spec/system/`.

---

## Techniques par fichier (system specs)

| ID | Technique | Description | Signal de détection | Risque | Gain typique |
|---|---|---|---|---|---|
| S01 | sleep → assertions Capybara | Remplacer `sleep` par des assertions Capybara (`have_selector`, `have_content`, `have_current_path`). L'attente implicite de Capybara gère le timing. | `sleep` dans un fichier `spec/system/`. | Le `sleep` cachait peut-être un vrai problème de timing. | **Moyen** |
| S02 | réduire les navigations | Regrouper les assertions dans un même scénario au lieu de revisiter les mêmes pages dans des `it` séparés. Chaque `it` en system spec relance le browser setup + la navigation. | Plusieurs `it` dans le même `describe` qui font `visit` sur la même page avec le même setup. | Perd la granularité des messages d'erreur — atténué par `aggregate_failures`. | **Fort** |

<!-- Ajouter ici les nouvelles techniques system découvertes par les agents -->
