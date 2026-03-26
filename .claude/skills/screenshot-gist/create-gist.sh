#!/bin/bash
# Usage: create-gist.sh <nom>
# Phase 1 complète : crée le readme, le gist, configure git auth, clone
# Clone dans tmp/<nom>/ (pas tmp/gist/)
# Output (stdout) : GIST_URL=<url> GIST_ID=<id>
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: create-gist.sh <nom>" >&2
  exit 1
fi

nom="$1"

# Guard path traversal
if [[ "$nom" == */* || "$nom" == *..* ]]; then
  echo "Erreur: le nom ne doit pas contenir '/' ni '..'" >&2
  exit 1
fi

# Créer le readme placeholder
mkdir -p tmp
cat > tmp/gist-readme.md <<EOF
Screenshots — ${nom}
EOF

# Créer le gist
gist_url=$(gh gist create --public --desc "Screenshots — ${nom}" tmp/gist-readme.md)
gist_id=$(basename "$gist_url")

# Afficher AVANT le clone (résilience réseau)
echo "GIST_URL=${gist_url}"
echo "GIST_ID=${gist_id}"

# Nettoyer le readme temporaire
rm -f tmp/gist-readme.md

# Configurer git auth + cloner
gh auth setup-git
rm -rf "tmp/${nom}"
git clone "https://gist.github.com/${gist_id}.git" "tmp/${nom}"
