#!/bin/bash
# Pousse le lefthook.yml de night-shift dans TOUS les worktrees d'un repo.
#
# install.sh ne traite qu'une cible et le post-checkout ne s'exécute qu'à la
# création d'un worktree : sans ce script, une modification de la config ne
# touche jamais les worktrees déjà en place.
#
# Usage:
#   ./sync-lefthook.sh [/chemin/du/repo] [--dry-run]
#
# Sans argument, cible ~/dev/demarches-simplifiees.fr.
#
# Copie seulement : lefthook relit sa config à chaque exécution, et les hooks
# git sont partagés entre worktrees. Pas de `lefthook install` à relancer.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_file="$script_dir/../../lefthook.yml"

repo="${HOME}/dev/demarches-simplifiees.fr"
dry_run=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=true ;;
    *) repo="$arg" ;;
  esac
done

if [ ! -f "$source_file" ]; then
  echo "❌ Source introuvable : $source_file"
  exit 1
fi

if [ ! -d "$repo" ]; then
  echo "❌ Repo introuvable : $repo"
  exit 1
fi

source_sum=$(shasum "$source_file" | cut -d' ' -f1)
updated=0
skipped=0

while IFS= read -r worktree; do
  # Les worktrees d'agents sont éphémères et souvent prunables.
  case "$worktree" in
    */.claude/worktrees/*) continue ;;
  esac

  target="$worktree/lefthook.yml"

  if [ -f "$target" ] && [ "$(shasum "$target" | cut -d' ' -f1)" = "$source_sum" ]; then
    skipped=$((skipped + 1))
    continue
  fi

  if [ "$dry_run" = true ]; then
    echo "   à mettre à jour : $worktree"
  else
    cp "$source_file" "$target"
    echo "   ✓ $worktree"
  fi
  updated=$((updated + 1))
done < <(git -C "$repo" worktree list --porcelain | awk '/^worktree /{print $2}')

echo ""
if [ "$dry_run" = true ]; then
  echo "🔍 dry-run : $updated à mettre à jour, $skipped déjà à jour"
else
  echo "✓ $updated worktrees mis à jour, $skipped déjà à jour"
fi
