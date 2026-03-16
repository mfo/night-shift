# Inventaire des tests lents — CI du 2026-03-15

**Source :** [GitHub Actions run #23112930152](https://github.com/demarche-numerique/demarche.numerique.gouv.fr/actions/runs/23112930152)
**Seuil :** tous les tests apparaissant dans `--profile 10` de chaque job CI

---

## Tests unitaires

| # | Fichier spec | Ligne(s) | Temps CI | Nb slow | Coverage % | Commit | Statut | Avant (local) | Après | Gain |
|---|---|---|---|---|---|---|---|---|---|---|
| U01 | `spec/controllers/api/v2/graphql_controller_n+1_spec.rb` | :70, :52, :36 | 23.55s | 3 | | | | | |
| U02 | `spec/perf/instructeur_dossier_controller_spec.rb` | :48 | 6.90s | 1 | | | | | |
| U03 | `spec/models/dossier_spec.rb` | :2645, :1040, :1919, :1904, :1884 | 5.93s | 5 | 83.38% | ✅ T08 | 64.03s | 54.79s | -14.4% |
| U04 | `spec/controllers/api/v2/graphql_controller_spec.rb` | :490, :206 | 5.10s | 2 | | | | | |
| U05 | `spec/services/api_geo_service_spec.rb` | :57, :5 | 4.95s | 2 | | | | | |
| U06 | `spec/controllers/administrateurs/groupe_instructeurs_controller_spec.rb` | :1055 | 4.02s | 1 | | | | | |
| U07 | `spec/services/procedure_export_service_spec.rb` | :124 | 3.31s | 1 | | | | | |
| U08 | `spec/controllers/administrateurs/mail_templates_controller_spec.rb` | :19 | 3.19s | 1 | | | | | |
| U09 | `spec/perf/export_spec.rb` | :51 | 3.01s | 1 | | | | | |
| U10 | `spec/models/concerns/tags_substitution_concern_spec.rb` | :431, :425, :419, :446 | 2.06s | 4 | | | | | |
| U11 | `spec/controllers/api/v2/graphql_controller_stored_queries_spec.rb` | :129, :1258, :1031, :1098, :1219, :1158 | 2.01s | 6 | | | | | |
| U12 | `spec/services/procedure_export_service_zip_spec.rb` | :38 | 1.98s | 1 | | | | | |
| U13 | `spec/services/procedure_export_service_tabular_spec.rb` | :291, :297, :286, :256 | 1.86s | 4 | | | | | |
| U14 | `spec/tasks/maintenance/t20250820migrate_old_filter_format_task_spec.rb` | :40, :25 | 1.78s | 2 | | | | | |
| U15 | `spec/jobs/process_stalled_declarative_dossier_job_spec.rb` | :97, :59 | 1.66s | 2 | | | | | |
| U16 | `spec/graphql/dossier_spec.rb` | :203 | 1.64s | 1 | | | | | |
| U17 | `spec/controllers/instructeurs/dossiers_controller_spec.rb` | :492, :518, :1119 | 1.64s | 3 | | | | | |
| U18 | `spec/components/editable_champ/repetition_component_spec.rb` | :430, :319 | 1.62s | 2 | | | | | |
| U19 | `spec/jobs/cron/backfill_siret_degraded_mode_job_spec.rb` | :29 | 1.56s | 1 | | | | | |
| U20 | `spec/jobs/cron/crisp_delete_inactive_people_job_spec.rb` | :163 | 1.52s | 1 | | | | | |
| U21 | `spec/tasks/maintenance/populate_siret_value_json_task_spec.rb` | :17 | 1.50s | 1 | | | | | |
| U22 | `spec/models/types_de_champ/prefill_commune_type_de_champ_spec.rb` | :92, :87, :68 | 1.42s | 3 | | | | | |
| U23 | `spec/perf/heavy_dossier_spec.rb` | :58 | 1.42s | 1 | | | | | |
| U24 | `spec/jobs/auto_archive_procedure_dossiers_job_spec.rb` | :34 | 1.39s | 1 | | | | | |
| U25 | `spec/models/stat_spec.rb` | :6 | 1.35s | 1 | | | | | |
| U26 | `spec/controllers/instructeurs/procedures_controller_spec.rb` | :278 | 1.24s | 1 | | | | | |
| U27 | `spec/tasks/maintenance/t20250522_re_route_procedure_task_spec.rb` | :32 | 1.20s | 1 | | | | | |
| U28 | `spec/controllers/administrateurs/procedures_controller_spec.rb` | :38, :927 | 1.16s | 2 | | | | | |
| U29 | `spec/jobs/migrations/normalize_communes_job_spec.rb` | :12 | 1.16s | 1 | | | | | |
| U30 | `spec/controllers/users/dossiers_controller_spec.rb` | :499, :554, :2021, :579 | 1.12s | 4 | | | | | |
| U31 | `spec/tasks/maintenance/fix_champs_commune_having_value_but_not_external_id_task_spec.rb` | :46 | 1.11s | 1 | | | | | |
| U32 | `spec/models/concerns/dossier_searchable_concern_spec.rb` | :55 | 1.10s | 1 | | | | | |
| U33 | `spec/models/champs/siret_champ_spec.rb` | :138 | 1.07s | 1 | | | | | |
| U34 | `spec/models/concerns/dossier_state_concern_spec.rb` | :155, :200, :172 | 1.07s | 3 | | | | | |
| U35 | `spec/controllers/experts/avis_controller_spec.rb` | :566 | 1.06s | 1 | | | | | |
| U36 | `spec/tasks/maintenance/populate_rnf_json_value_task_spec.rb` | :83 | 1.02s | 1 | | | | | |
| U37 | `spec/services/instructeur_procedures_counters_service_spec.rb` | :139, :117 | 0.92s | 2 | | | | | |

## Tests système

| # | Fichier spec | Ligne(s) | Temps CI | Nb slow | Coverage % | Commit | Statut | Avant (local) | Après | Gain |
|---|---|---|---|---|---|---|---|---|---|---|
| S01 | `spec/system/routing/rules_full_scenario_spec.rb` | :49, :21 | 66.41s | 2 | | | | | |
| S02 | `spec/system/instructeurs/instruction_spec.rb` | :293, :161, :134, :99, :39, :187 | 21.78s | 6 | | | | | |
| S03 | `spec/system/users/dropdown_spec.rb` | :32, :25 | 14.86s | 2 | | | | | |
| S04 | `spec/system/administrateurs/procedure_cloning_spec.rb` | :36, :76 | 10.13s | 2 | | | | | |
| S05 | `spec/system/administrateurs/api_referentiel_spec.rb` | :75, :234, :486, :348 | 9.72s | 4 | | | | | |
| S06 | `spec/system/instructeurs/expert_spec.rb` | :65, :22, :102 | 8.93s | 3 | | | | | |
| S07 | `spec/system/users/brouillon_spec.rb` | :11, :251, :664, :121 | 8.17s | 4 | | | | | |
| S08 | `spec/system/accessibilite/wcag_usager_spec.rb` | :85, :101, :93, :75, :30, :38 | 6.95s | 6 | | | | | |
| S09 | `spec/system/api_particulier/api_particulier_spec.rb` | :58, :457, :264, :326, :401 | 5.85s | 5 | | | | | |
| S10 | `spec/system/instructeurs/procedure_export_template_zip_spec.rb` | :12 | 3.99s | 1 | | | | | |
| S11 | `spec/system/administrateurs/procedure_attestation_template_spec.rb` | :70 | 3.63s | 1 | | | | | |
| S12 | `spec/system/instructeurs/procedure_filters_spec.rb` | :105 | 3.58s | 1 | | | | | |
| S13 | `spec/system/administrateurs/procedure_publish_spec.rb` | :151 | 2.22s | 1 | | | | | |
| S14 | `spec/system/experts/expert_spec.rb` | :102 | 2.14s | 1 | | | | | |
| S15 | `spec/system/instructeurs/instructeur_creation_spec.rb` | :21 | 2.10s | 1 | | | | | |

---

## Résumé

| Catégorie | Fichiers | Tests lents | Temps CI cumulé |
|---|---|---|---|
| Unit tests | 37 | 68 | ~82s |
| System tests | 15 | 40 | ~174s |
| **Total** | **52** | **108** | **~256s** |
