#!/bin/bash
set -euo pipefail

cd /Users/mfo/dev/demarches-simplifiees.fr

SPECS=(
  spec/controllers/api/v2/graphql_controller_n+1_spec.rb
  spec/perf/instructeur_dossier_controller_spec.rb
  spec/models/dossier_spec.rb
  spec/controllers/api/v2/graphql_controller_spec.rb
  spec/services/api_geo_service_spec.rb
  spec/controllers/administrateurs/groupe_instructeurs_controller_spec.rb
  spec/services/procedure_export_service_spec.rb
  spec/controllers/administrateurs/mail_templates_controller_spec.rb
  spec/perf/export_spec.rb
  spec/models/concerns/tags_substitution_concern_spec.rb
  spec/controllers/api/v2/graphql_controller_stored_queries_spec.rb
  spec/services/procedure_export_service_zip_spec.rb
  spec/services/procedure_export_service_tabular_spec.rb
  spec/tasks/maintenance/t20250820migrate_old_filter_format_task_spec.rb
  spec/jobs/process_stalled_declarative_dossier_job_spec.rb
  spec/graphql/dossier_spec.rb
  spec/controllers/instructeurs/dossiers_controller_spec.rb
  spec/components/editable_champ/repetition_component_spec.rb
  spec/jobs/cron/backfill_siret_degraded_mode_job_spec.rb
  spec/jobs/cron/crisp_delete_inactive_people_job_spec.rb
  spec/tasks/maintenance/populate_siret_value_json_task_spec.rb
  spec/models/types_de_champ/prefill_commune_type_de_champ_spec.rb
  spec/perf/heavy_dossier_spec.rb
  spec/jobs/auto_archive_procedure_dossiers_job_spec.rb
  spec/models/stat_spec.rb
  spec/controllers/instructeurs/procedures_controller_spec.rb
  spec/tasks/maintenance/t20250522_re_route_procedure_task_spec.rb
  spec/controllers/administrateurs/procedures_controller_spec.rb
  spec/jobs/migrations/normalize_communes_job_spec.rb
  spec/controllers/users/dossiers_controller_spec.rb
  spec/tasks/maintenance/fix_champs_commune_having_value_but_not_external_id_task_spec.rb
  spec/models/concerns/dossier_searchable_concern_spec.rb
  spec/models/champs/siret_champ_spec.rb
  spec/models/concerns/dossier_state_concern_spec.rb
  spec/controllers/experts/avis_controller_spec.rb
  spec/tasks/maintenance/populate_rnf_json_value_task_spec.rb
  spec/services/instructeur_procedures_counters_service_spec.rb
  spec/system/routing/rules_full_scenario_spec.rb
  spec/system/instructeurs/instruction_spec.rb
  spec/system/users/dropdown_spec.rb
  spec/system/administrateurs/procedure_cloning_spec.rb
  spec/system/administrateurs/api_referentiel_spec.rb
  spec/system/instructeurs/expert_spec.rb
  spec/system/users/brouillon_spec.rb
  spec/system/accessibilite/wcag_usager_spec.rb
  spec/system/api_particulier/api_particulier_spec.rb
  spec/system/instructeurs/procedure_export_template_zip_spec.rb
  spec/system/administrateurs/procedure_attestation_template_spec.rb
  spec/system/instructeurs/procedure_filters_spec.rb
  spec/system/administrateurs/procedure_publish_spec.rb
  spec/system/experts/expert_spec.rb
  spec/system/instructeurs/instructeur_creation_spec.rb
)

OUT=~/dev/night-shift/pocs/test-optimization/coverage-baselines.csv
echo "spec_file,coverage_pct,commit" > "$OUT"

TOTAL=${#SPECS[@]}
CURRENT=0

for spec in "${SPECS[@]}"; do
  CURRENT=$((CURRENT + 1))
  echo "[$CURRENT/$TOTAL] $spec"

  # Reset SimpleCov state to avoid accumulation between runs
  rm -f coverage/.resultset.json

  if ! COVERAGE=true bundle exec rspec "$spec" --format progress 2>/dev/null; then
    echo "    → FAILED (tests rouges), skip"
    COMMIT=$(git log -1 --format=%h -- "$spec")
    echo "$spec,FAILED,$COMMIT" >> "$OUT"
    continue
  fi

  COV=$(cat coverage/.resultset.json | ruby -rjson -e '
    data = JSON.parse(STDIN.read)
    # Only count files that were actually exercised (at least one line hit)
    touched = data.values.first["coverage"].select { |_path, info|
      info["lines"]&.any? { |l| l && l > 0 }
    }
    lines = touched.values.flat_map { |f| f["lines"] }.compact
    covered = lines.count { |l| l && l > 0 }
    total = lines.count { |l| !l.nil? }
    puts total > 0 ? ((covered.to_f / total * 100)).round(2) : "0.0"
  ')
  COMMIT=$(git log -1 --format=%h -- "$spec")
  echo "$spec,$COV,$COMMIT" >> "$OUT"
  echo "    → $COV% (commit: $COMMIT)"
done

echo ""
echo "=== Terminé === $TOTAL fichiers → $OUT"
