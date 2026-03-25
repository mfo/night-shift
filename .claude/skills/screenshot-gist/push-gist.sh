#!/bin/bash
# Usage: push-gist.sh <nom> <user> <gist-id> [fichier1.png fichier2.png ...]
# Phase 3+4 : add fichiers spécifiques, commit, push, affiche URLs markdown
# Travaille dans tmp/<nom>/ (le clone du gist)
set -euo pipefail

nom="$1"
user="$2"
gist_id="$3"
shift 3

# Add uniquement les fichiers passés en arguments
for f in "$@"; do
  git -C "tmp/${nom}" add "$(basename "$f")"
done

git -C "tmp/${nom}" commit --no-gpg-sign -m "Add screenshots"
git -C "tmp/${nom}" push

# Afficher les URLs raw en markdown
for f in "$@"; do
  filename=$(basename "$f")
  echo "![${filename}](https://gist.githubusercontent.com/${user}/${gist_id}/raw/${filename})"
done
