#!/bin/bash
# Execute a Rails runner query against the dev database
#
# Usage:
#   find-procedure.sh "Procedure.joins(:types_de_champ_public).where(types_de_champ: { type_champ: 'communes' }).limit(5).pluck(:id, :libelle)"
#   find-procedure.sh "Dossier.where(procedure_id: 42).group(:state).count"
#   find-procedure.sh "GroupeInstructeur.where(procedure_id: 42).joins(:instructeurs).count"

set -euo pipefail

# Block dangerous Ruby side-effects and destructive AR methods
if echo "$1" | grep -qiE "system|exec|%x|File\.(write|delete|open)|IO\.|Kernel\.|Dir\.|destroy|destroy_all" ; then
  echo "error: query contains blocked keyword (side-effect or destructive method)" >&2
  exit 1
fi

REPO_PATH="${REPO_PATH:-$(cd "$(dirname "$0")/../../../../.." && pwd)}"

cd "$REPO_PATH" || { echo "error: cannot cd to $REPO_PATH"; exit 1; }

exec bundle exec rails runner "pp($1)"
