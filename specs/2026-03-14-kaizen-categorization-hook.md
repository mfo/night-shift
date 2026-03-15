# Spec — Kaizen simplifie : du systeme a l'acte

**Date :** 2026-03-14
**Auteurs :** Nadia (IA), Marc (Dev), Sophie (Plugin), Kenji (Lean)
**Invites :** Taiichi Ohno (TPS), Simon Willison (Datasette/CLI), DHH (Rails), Andrej Karpathy (Software 2.0)
**Status :** v2 — consensus post-challenge philosophique

---

## Le probleme qu'on resout

Le kaizen post-session est devenu trop frictionnel :
- Template 142 lignes -> le dev remplit des cases au lieu de reflechir
- Categorisation manuelle redondante -> le dev sait deja ou ranger
- Outillage qui s'empile (templates, hooks, heuristiques) -> on construit un systeme kaizen au lieu de faire du kaizen

**Ce qu'on ne resout PAS :** la qualite de la reflexion. Aucun outil ne remplace la pensee.

---

## Principe directeur

**Le kaizen tient sur un Post-it. L'outillage rend le Post-it plus facile a ecrire.**

> "Le meilleur kaizen est celui qu'on peut ecrire sur un Post-it." -- Ohno
> "Si vous devez rappeler aux gens de faire leur travail, c'est que le travail n'a pas de sens pour eux." -- Ohno

---

## Option zero — Le baseline

> Apres chaque session significative, creer un fichier `kaizen/<categorie>/YYYY-MM-DD-<titre>.md` avec 3-5 bullets. Pas de hook, pas de JSONL, pas d'heuristiques. Juste un dev qui ecrit ce qu'il a appris.

Tout element ci-dessous doit prouver sa valeur par rapport a cette option zero.

---

## Architecture v2

### 1. Template radical (~10 lignes)

```markdown
# Kaizen -- [titre]
Date: YYYY-MM-DD | Skill: [nom] | Score: ?/10

## Ce qui s'est passe
- ...

## Ce qu'on a appris
- ...

## Action
- [ ] [action] -> [fichier cible]
```

3 questions. Pas de sections prescriptives. Si le dev veut ecrire plus, libre a lui. Le minimum requis tient sur un Post-it.

**Justification vs option zero :** Le frontmatter minimal (date, skill, score) permet l'agregation weekly et la lecture par l'agent. Les 3 sections guident sans contraindre. Gain mesurable : le dev ne perd plus 5min a chercher quelle section remplir dans un template de 142 lignes.

### 2. Skill `/kaizen` — git log comme gemba

Le skill fait UNE chose : il aide le dev a ecrire son Post-it plus vite.

**Fonctionnement :**
- Lit `git log --oneline` + `git diff --stat` pour comprendre la session
- Suggere une categorie basee sur les paths modifies (le LLM du skill comprend le contexte — pas besoin d'heuristiques shell separees)
- Le dev confirme ou corrige la categorie (2 secondes)
- Pre-remplit le template 10 lignes avec ce que le skill a compris
- Pose 1 question ouverte : "Qu'est-ce que tu as appris ?"
- Propose des diffs au skill source si une action est identifiee
- Cree le fichier `kaizen/<categorie>/YYYY-MM-DD-<titre>.md`

**Pas de hook. Pas de JSONL. Pas d'heuristiques shell.**

`git log` EST le gemba numerique. Le dev (ou le skill) tape `git log` et VOIT son travail. Pas besoin d'un intermediaire JSONL pour capturer ce que git sait deja.

**Justification vs option zero :** Le dev ecrirait les memes bullets, mais passerait 3-5min de plus a relire git log et structurer son fichier. Le skill fait ce travail mecanique. La reflexion reste humaine.

### 3. Weekly simplifie

Le weekly agrege les fichiers kaizen existants. Il detecte :
- Categories sans kaizen recent
- Actions non-cochees (improvements proposees mais pas appliquees)
- Skills qui stagnent (meme score sur 3+ sessions)

---

## Ce qu'on supprime de v1

| Supprime | Raison (challenge source) |
|---|---|
| Hook PostToolUse + JSONL | Distance au gemba. git log est la source de verite (Ohno, Marc/DHH, Nadia) |
| Heuristiques de categorisation shell | Inventaire rigide. Le LLM du skill comprend deja le contexte (Nadia/Karpathy) |
| Seuil adaptatif "RAS" | Automatise l'absence de reflexion (Ohno) |
| Hook Stop rappel | Surcontrole. Si le dev ne fait pas kaizen, le probleme est la valeur, pas le rappel (Ohno) |
| Sequencage V0-V4 | Stage-gate, pas lean. On fait V0 et on adapte (DHH, Marc) |
| Template improvement 182 lignes | Anti-kaizen. Si ca tient pas sur un Post-it, c'est trop complexe (Ohno) |
| Detection `unmatched_extensions` | YAGNI (Marc) |

---

## Ce qu'on ne fait PAS

| Refuse | Raison |
|---|---|
| Hook de collecte | git log suffit -- pas d'intermediaire |
| Heuristiques shell | Le LLM categorise mieux et sans maintenance |
| Dashboard | Le weekly suffit |
| Rappels automatiques | Surcontrole |
| Roadmap multi-versions | Faire V0, mesurer, adapter |
| Seuil adaptatif | La decision "rien a dire" appartient au dev |
| Classification IA externe | Le LLM du skill EST deja la -- pas d'appel supplementaire |

---

## PDCA

**Probleme :** Le kaizen post-session est trop frictionnel (template lourd, categorisation manuelle, outillage qui s'empile).

**Plan :** Deployer template 10 lignes + skill `/kaizen` simplifie (git log only) sur la categorie haml-migration (la plus active).

**Do :** 5 sessions haml-migration avec le nouveau systeme. Critere d'echec explicite : si le dev passe plus de temps a se battre avec l'outil qu'a reflechir, on arrete.

**Check :**
1. Le dev fait-il son kaizen spontanement ? (sans rappel = le kaizen a de la valeur)
2. Les actions proposees sont-elles effectivement appliquees dans les skills ? (resultat, pas processus)
3. Le score agent-friendly par skill progresse-t-il entre iterations ? (but final du kaizen)
4. Ratio insights actionnables par session : stable ou en hausse vs option zero ?

**Act :** Apres 5 sessions, decision binaire :
- Le skill apporte plus que l'option zero -> on continue, on etend
- Le skill n'apporte pas plus -> on revient a l'option zero et on analyse pourquoi

---

## Metriques

**On mesure le resultat du kaizen, pas le kaizen lui-meme.**

| Metrique | Ce qu'elle mesure | Pourquoi |
|---|---|---|
| Kaizen spontane | Le dev fait-il kaizen sans rappel ? | Si non, le kaizen n'a pas assez de valeur |
| Actions appliquees / proposees | Les improvements sont-elles integrees ? | Mesure le resultat |
| Score agent-friendly par skill | Les skills s'ameliorent-ils ? | But final du kaizen |

**Metriques supprimees :**
- Temps kaizen : reduire le temps n'est pas un objectif
- Taux de categorisation : le LLM categorise, le dev confirme -- pas de metrique necessaire
- "Canari reflexion" vague : remplace par "ratio insights actionnables"

---

## Synthese philosophique

### Ce que les invites nous ont appris

**Taiichi Ohno** nous a rappele que le kaizen n'est pas un systeme -- c'est un acte. L'acte de s'arreter, observer, et ameliorer. Tout ce qui s'interpose entre le praticien et cet acte est suspect. Le gemba numerique c'est `git log`, pas un JSONL.

**DHH** nous a force a definir l'option zero : 3-5 bullets dans un fichier. Tout ajout doit prouver sa valeur par rapport a ca. Le meilleur systeme kaizen est celui qu'on n'a pas besoin de construire.

**Simon Willison** a valide le choix technique JSONL/shell -- mais le debat a rendu le JSONL lui-meme caduc. La meilleure optimisation d'un processus inutile, c'est de le supprimer.

**Andrej Karpathy** (via Nadia) a montre que les heuristiques shell sont de l'inventaire rigide. Le LLM du skill comprend deja le contexte -- pas besoin d'un moteur de regles separe.

### Le consensus

La spec v1 construisait un **systeme kaizen** (hooks, JSONL, heuristiques, roadmap V0-V4). La v2 revient a **l'acte kaizen** :

1. **Template Post-it** (~10 lignes, 3 questions)
2. **git log comme gemba** (pas d'intermediaire)
3. **Skill simplifie** (pre-remplit le Post-it, le dev reflechit)
4. **PDCA sur le probleme** (friction), pas sur l'outil
5. **Option zero comme test** -- si le skill n'apporte pas plus que "ouvre un fichier et ecris", on arrete
6. **Zero infrastructure** -- pas de hook, pas de JSONL, pas de roadmap
7. **Mesurer le resultat** -- skills ameliores, pas temps reduit
