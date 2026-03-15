# Spec — Kaizen Automatisé

**Date :** 2026-03-14
**Auteurs :** Nadia (IA), Marc (Dev), Sophie (Plugin), Kenji (Lean)
**Status :** Consensus validé

---

## Principe directeur

**Automatiser la collecte, pas la réflexion.**

Le kaizen n'est pas un formulaire à remplir — c'est un moment de prise de recul. L'automatisation doit éliminer le muda (scaffolding, métriques, boilerplate) et protéger la réflexion humaine (learnings, diagnostic, décisions).

---

## Architecture — Déploiement incrémental en 5 étapes

### Étape 0 — Simplifier les templates (prérequis)

Réduire le template task.md de 142 lignes à ~40 lignes. Deux zones : auto (métriques) et humain (réflexion).

Seuil adaptatif : si score >= 8/10 et aucun blocage, kaizen minimal "RAS" (frontmatter seul).

Validation : tester manuellement sur 3 sessions avant étape 1.

### Étape 1 — Convention dans les skills (v0, zéro infra)

Créer un skill `/kaizen` réutilisable :
- Crée le fichier `kaizen/<catégorie>/iteration-N/YYYY-MM-DD-<nom>.md`
- Pré-remplit frontmatter et métriques (git log, test results)
- Pose des questions guidées basées sur les faits de la session
- L'humain complète le score, valide/édite, remplit les actions
- Si une action concerne le skill source, propose un diff concret (boucle fermée)

Ajouter "Kaizen" comme dernière étape dans la checklist de chaque skill.

Validation : sur 10 sessions, le dev fait le kaizen 8+ fois.

### Étape 2 — Collecte passive par hooks (v1, si étape 1 validée)

Hook `PostToolUse` (type: command) intercepte `git commit` et résultats de tests → log dans `tmp/kaizen-signals.jsonl`.

Coût : zéro token (shell script pur).

### Étape 3 — Questions guidées enrichies (si étapes 1-2 validées)

Le skill `/kaizen` utilise les signaux collectés pour poser des questions plus précises.

Règle : l'agent rapporte des FAITS et pose des QUESTIONS. Il ne tire pas de conclusions.

### Étape 4 — Hook Stop conditionnel (futur)

Hook `Stop` (type: agent) qui détecte la fin de tâche et rappelle de faire le kaizen.

Déployer seulement si taux de kaizen réalisés < 80%.

---

## Ce qu'on automatise vs ce qu'on protège

| Automatisé (muda éliminé) | Protégé (réflexion humaine) |
|---|---|
| Création fichier, nommage, date | Score agent-friendly |
| Métriques : commits, tests, fichiers | Diagnostic "ce qui a coincé" (cause) |
| Frontmatter YAML | Learnings clés |
| Pré-remplissage faits observables | Décisions d'amélioration du skill |
| Agrégation weekly (tableau, stats) | Insights stratégiques du weekly |
| Scaffolding des sections | Validation des diffs proposés |

---

## PDCA

**Plan :** Simplifier template + skill `/kaizen` dans haml-migration

**Do :** Tester sur 5 sessions HAML

**Check :**
1. Temps kaizen : 10-15min → cible 3-5min
2. Canari réflexion : l'humain remplit-il les sections réflexion ?
3. Score agent-friendly : stable ou en hausse ?

**Anti-métrique :** volume de kaizen produit (plus ≠ mieux).

**Act :**
- Temps baisse ET réflexion maintenue → étape 2
- Réflexion vide → ajuster template/questions
- Temps ne baisse pas → le muda est ailleurs

---

## Boucle fermée

```
Session skill → Kaizen (faits + questions) → Dev décide actions
     ↑                                              ↓
     └──── Skill amélioré (diff appliqué) ←─────────┘
```

Le weekly reste le moment de synthèse et de réflexion stratégique (hansei).
