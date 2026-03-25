#!/bin/bash
# Usage: create-gist.sh <nom>
# Phase 1 complète : crée le readme, le gist, configure git auth, clone
# Clone dans tmp/<nom>/ (pas tmp/gist/)
# Output (stdout) : GIST_URL=<url> GIST_ID=<id>
set -euo pipefail

nom="$1"

# Créer le readme placeholder
mkdir -p tmp
cat > tmp/gist-readme.md <<EOF
Screenshots — ${nom}
EOF

# Créer le gist
gist_url=$(gh gist create --public --desc "Screenshots — ${nom}" tmp/gist-readme.md)
gist_id=$(basename "$gist_url")

# Configurer git auth + cloner
gh auth setup-git
rm -rf "tmp/${nom}"
git clone "https://gist.github.com/${gist_id}.git" "tmp/${nom}"

echo "GIST_URL=${gist_url}"
echo "GIST_ID=${gist_id}"
