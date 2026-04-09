---
name: kaizen
description: "Capture session learnings (write) or synthesize kaizen (synth). Use when user says 'kaizen', 'retour', or after a work session."
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write(kaizen/*)
  - Edit(kaizen/*)
  - Edit(.claude/skills/*)
  - Write(.claude/skills/*)
  - Bash(find:*)
  - Bash(ls:*)
---

# Kaizen

**Deux modes :** `/kaizen write` et `/kaizen synth`

---

## Mode write — Post-it post-session

### Quand l'utiliser
Après une session de travail significative. Si tu n'as rien à dire, ne dis rien.

### Workflow

#### 1. Suggérer la catégorie
Basé sur le contexte de la session, proposer où ranger le kaizen :
- `kaizen/1-haml/` si .haml/.erb
- `kaizen/2-test-optimization/` si tests
- `kaizen/3-bugs/` si bugfix
- `kaizen/4-features/` si feature
- `kaizen/5-harden/` si sécurité/pentest/audit
- Le dev confirme ou corrige (2 secondes).

#### 2. Pré-remplir le Post-it
⚠️ **Toujours créer dans `~/dev/night-shift/`** — jamais dans le repo de travail courant.

Créer `~/dev/night-shift/kaizen/<catégorie>/YYYY-MM-DD-<titre>.md` avec le template (`kaizen/templates/task.md`).
Pré-remplir "Ce qui s'est passé" à partir de la session.

#### 3. Poser UNE question
"Qu'est-ce que tu as appris ?"

#### 4. Lister les permissions bloquantes
Parcourir la session et lister les permissions qui ont été demandées interactivement. Les ajouter comme action dans le Post-it :
- Ex: `- [ ] Ajouter permission Bash(bun lint:herb:*) dans allowed-tools du skill`

#### 5. Déposer, ne pas appliquer
Le kaizen est un **livrable passif** : déposer le fichier dans `~/dev/night-shift/kaizen/` et c'est tout.
**NE JAMAIS** proposer d'appliquer les corrections au skill depuis la session de travail — c'est le rôle du mode synth.

---

## Mode synth — Synthèse interactive

### Quand l'utiliser
Le matin, pour consommer les kaizen produits par les agents et améliorer les skills.

### Workflow

#### 1. Scanner les kaizen
Lister tous les fichiers dans `~/dev/night-shift/kaizen/*/`, triés par date (plus récents d'abord).
**Filtrer les kaizen avec `status: traité` dans le frontmatter** — ne pas les re-proposer.

```bash
find ~/dev/night-shift/kaizen -name "*.md" -not -name "README.md" | xargs ls -t
```

Présenter la liste à l'utilisateur : date, catégorie, titre.

#### 2. L'utilisateur choisit lesquels traiter

#### 3. Pour chaque kaizen sélectionné

1. Lire le kaizen
2. Identifier le skill concerné (depuis le frontmatter ou la catégorie)
3. Lire le skill actuel
4. Comparer : le kaizen contient-il des learnings pas encore dans le skill ?
5. Proposer des modifications :
   - Améliorations au skill (nouvelles règles, pièges à documenter)
   - Nouvelles techniques pour le catalogue associé (ex: `.claude/skills/test-optimization/patterns.md`)
   - Blocages récurrents à résoudre (permissions, setup)

#### 4. L'utilisateur valide chaque proposition

**Rien n'est écrit sans validation.** Proposer, attendre le go, puis appliquer.

#### 5. Marquer comme traité
Après validation user, ajouter dans le frontmatter du kaizen traité :
```yaml
status: traité
date_synth: YYYY-MM-DD
```

#### 6. Itérer
Passer au kaizen suivant ou terminer.
