#!/bin/bash
# Script d'installation du hook post-checkout dans un worktree
#
# Usage:
#   ./install.sh /path/to/worktree
#
# Exemple:
#   ./install.sh ~/dev/demarche.numerique.gouv.fr-poc-haml

set -e

if [ $# -eq 0 ]; then
  echo "Usage: $0 /path/to/worktree"
  echo ""
  echo "Exemple:"
  echo "  $0 ~/dev/demarche.numerique.gouv.fr-poc-haml"
  exit 1
fi

worktree_path="$1"

if [ ! -d "$worktree_path" ]; then
  echo "❌ Erreur: Le répertoire $worktree_path n'existe pas"
  exit 1
fi

if [ ! -d "$worktree_path/.git" ]; then
  echo "❌ Erreur: $worktree_path n'est pas un dépôt git"
  exit 1
fi

echo "==> Installation du hook post-checkout dans $worktree_path"

# Créer le répertoire .githooks
mkdir -p "$worktree_path/.githooks"

# Copier le hook
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$script_dir/post-checkout" "$worktree_path/.githooks/"

# Rendre exécutable
chmod +x "$worktree_path/.githooks/post-checkout"

# Configurer git pour utiliser .githooks
cd "$worktree_path"
git config core.hooksPath .githooks

echo "✓ Hook installé avec succès!"
echo ""
echo "Pour tester:"
echo "  cd $worktree_path"
echo "  git checkout -b test-hook"
echo ""
echo "Le hook créera automatiquement une DB unique pour ce worktree."
