---
name: screenshot-gist
description: Créer un gist GitHub pour stocker des screenshots (PNG) et les pousser via git clone/push HTTPS
allowed-tools: Bash(echo:*), Bash(gh gist create:*), Bash(gh auth setup-git:*), Bash(git -C /tmp/screenshot-gist:*), Bash(git clone:*), Bash(stat:*), Bash(ls:*)
---

# Screenshot → Gist

**Contexte :** `gh gist create` ne supporte PAS les fichiers binaires (PNG). Ce skill contourne la limitation en créant le gist avec un placeholder texte, puis en clonant via HTTPS pour y stocker les screenshots directement.

**Input :**
- `$ARGUMENTS` : nom du gist (utilisé comme sous-dossier dans `/tmp/screenshot-gist/`)

**Output :** gist ID + répertoire local `/tmp/screenshot-gist/<nom>/` prêt à recevoir des fichiers PNG.

---

## Phase 1 : Créer le gist + cloner

```bash
echo "Screenshots — <nom>" > /tmp/screenshot-gist-readme.md
```
```bash
gh gist create --public --desc "Screenshots — <nom>" /tmp/screenshot-gist-readme.md
```
Récupérer le gist ID depuis l'URL en sortie (dernière partie du path).
```bash
gh auth setup-git
```
```bash
git clone https://gist.github.com/<gist-id>.git /tmp/screenshot-gist/<nom>
```

Le skill appelant dépose ses screenshots (PNG, etc.) dans `/tmp/screenshot-gist/<nom>/`.

---

## Phase 2 : Pousser les screenshots

Appelé par le skill parent quand les screenshots sont prêts :

```bash
git -C /tmp/screenshot-gist/<nom> add .
```
```bash
git -C /tmp/screenshot-gist/<nom> -c commit.gpgsign=false commit -m "Add screenshots"
```
```bash
git -C /tmp/screenshot-gist/<nom> push
```

---

## URLs des images

Pour référencer les images dans une PR ou un commentaire :
```
https://gist.githubusercontent.com/<user>/<gist-id>/raw/<filename>
```

Le gist public est visible à :
```
https://gist.github.com/<user>/<gist-id>
```
