# Input Spec - Validation Visuelle HAML→ERB Migration

**Date :** 2026-03-11
**Type :** Feature - Amélioration workflow POC 1 (HAML→ERB)
**Complexité :** Moyenne (5-8 fichiers impactés)

---

## 🎯 Contexte & Problème

### Situation Actuelle

**Workflow HAML→ERB actuel (5 phases) :**
1. Sélection batch (15 fichiers max, tri par complexité)
2. Lecture fichiers HAML
3. Conversion ERB (5 patterns)
4. Validation locale (linter + grep patterns + tests)
5. Commit + push

**Problème identifié :**
- Review PR #12760 (Phase 3.1) : reviewer @colinux demande validation visuelle
- Citation : "Générer des screenshots des prévisualisations des composants"
- Alerte : "Formatteur herb a causé des régressions par le passé" (espaces HAML/ERB)
- **Pas de moyen de prouver équivalence visuelle HAML ↔ ERB**

### Impact Métier

**Sans validation visuelle :**
- ⚠️ Reviewer doit faire confiance aux tests unitaires uniquement
- ⚠️ Régressions visuelles invisibles (espaces, layout, styling)
- ⚠️ Review PR ralentie (doutes sur migration)
- ⚠️ Risque merge avec bugs visuels non détectés

**Avec validation visuelle :**
- ✅ Confiance reviewer immédiate (preuve visuelle HAML = ERB)
- ✅ Détection régressions espaces (formatteur herb)
- ✅ Review PR accélérée (screenshots comparatifs inline)
- ✅ Documentation visuelle pour futures migrations

### Déclencheur

- Review PR demande screenshots
- Composants critiques UI (formulaires, navigation, DSFR)
- Alerte formatteur herb modifie espaces

---

## 🎯 Objectif de la Feature

**Ajouter Phase 6 optionnelle au workflow HAML→ERB :**

**Phase 6 : Validation Visuelle (50-80min)**
- Générer screenshots comparatifs HAML vs ERB
- Vérifier préservation espaces (diff HTML généré)
- Publier dans PR GitHub avec commentaire formaté

**Critères de succès :**
1. Screenshots capturés dans contexte réel (tests system, pas previews isolés)
2. Comparaison HAML vs ERB côte à côte
3. Rapport espaces (diff HTML) si différences détectées
4. Commentaire PR publié automatiquement avec `gh pr comment`
5. Workflow réutilisable (toutes phases futures)

---

## 📋 Besoins Fonctionnels

### Use Case Principal

**Acteur :** Agent Claude (après migration HAML→ERB Phase N)
**Déclencheur :** Reviewer PR demande validation visuelle OU composants critiques

**Scénario nominal :**
1. Agent identifie tests system utilisant composants migrés (grep)
2. Agent capture screenshots ERB (contexte réel via tests system)
3. Agent compare HTML généré HAML vs ERB (diff espaces/whitespace)
4. Agent publie commentaire PR avec screenshots + rapport espaces
5. Reviewer valide visuellement HAML = ERB
6. Merge PR confiant

**Scénario alternatif (MCP Playwright indisponible) :**
- Fallback : `page.screenshot()` dans tests RSpec
- Fallback : Playwright CLI direct (npx)

### Inputs

**Requis :**
- Liste composants migrés (depuis commit migration)
- Numéro PR GitHub
- Commit hash migration

**Optionnels :**
- Tests system spécifiques à exécuter
- Format screenshots (PNG, WebP)
- Budget temps (quick 30min / thorough 80min)

### Outputs

**Livrables :**
1. Screenshots ERB (`screenshots/erb/*.png`)
2. Screenshots HAML (`screenshots/haml/*.png`) - optionnel
3. Rapport diff HTML (`diff-haml-erb.txt`)
4. Commentaire PR GitHub publié

**Format commentaire PR :**
```markdown
## 📸 Validation Visuelle - Phase X.Y

### Résumé
- Composants testés : 15/15
- Régressions visuelles : 0
- Différences espaces : 0
- Tests passés : ✅

### Comparaison HAML vs ERB
[Tableaux screenshots côte à côte]

### Vérification Espaces
[Diff HTML si différences]
```

---

## ⚙️ Besoins Techniques

### Composants Impactés

**Nouveau fichier :**
- `.claude/prompts/haml-visual-validation.md` (prompt Phase 6)

**Modifications :**
- `pocs/1-haml/setup.md` (ajouter Phase 6 optionnelle)
- `ROADMAP.md` (documenter Phase 6 disponible)

**Dépendances :**
- MCP Playwright (ou Playwright CLI)
- `gh` CLI (publication PR)
- Tests system existants (RSpec + Capybara)

### Technologies

**Outils de capture :**
- Option 1 : MCP Playwright (préféré)
- Option 2 : `page.screenshot()` dans tests RSpec
- Option 3 : Playwright CLI (npx)

**Outils de diff :**
- `diff -u` (espaces HTML)
- Visual diff si disponible

**Outils de publication :**
- `gh pr comment` (GitHub CLI)
- Upload images inline (GitHub accepte drag & drop)

---

## 🔧 Contraintes & Trade-offs

### Contraintes Techniques

**DOIT :**
- Capturer screenshots dans contexte réel (tests system), pas previews isolés
- Comparer HAML vs ERB (checkout commits avant/après)
- Publier automatiquement dans PR GitHub
- Workflow réutilisable (toutes phases futures)

**NE DOIT PAS :**
- Casser workflow principal (Phase 6 = optionnelle)
- Nécessiter setup complexe (doit fonctionner out-of-the-box)
- Ralentir migrations (50min max acceptable)

### Trade-offs à Décider

**Question 1 : Screenshots HAML + ERB ou ERB seulement ?**
- Option A : HAML + ERB (comparaison visuelle côte à côte) → 80min
- Option B : ERB seulement (+ diff HTML textuel) → 50min
- **User décide :** Quel budget temps acceptable ?

**Question 2 : MCP Playwright obligatoire ou fallback ?**
- Option A : MCP Playwright requis (meilleure expérience) → setup nécessaire
- Option B : Fallback Playwright CLI ou RSpec screenshot → fonctionne toujours
- **User décide :** Forcer installation MCP ou accepter fallback ?

**Question 3 : Phase 6 intégrée ou prompt séparé ?**
- Option A : Phase 6 dans `pocs/1-haml/setup.md` (workflow unifié)
- Option B : Prompt séparé `.claude/prompts/haml-visual-validation.md` (optionnel)
- **User décide :** Intégrer ou séparer ?

**Question 4 : Automatiser pour toutes phases ou à la demande ?**
- Option A : Automatique pour composants critiques (formulaires, DSFR)
- Option B : À la demande (reviewer PR déclenche)
- **User décide :** Automatiser ou manuel ?

---

## 🎯 Priorités

**Simplicité :**
- Workflow doit fonctionner sans setup MCP Playwright (fallback)
- Prompt clair, étapes séquentielles

**Robustesse :**
- Détecte différences espaces (alerte formatteur herb)
- Gère cas où tests system manquants (proposer alternatives)

**Maintenabilité :**
- Code réutilisable (fonction `capture_screenshots(components)`)
- Documentation claire dans setup.md

---

## 📊 Estimation

**Temps implémentation :** 3-5h
- Création prompt : 1h
- Tests sur Phase 3.1 : 1h
- Ajustements : 1h
- Documentation kaizen : 1-2h

**Temps utilisation (Phase 6) :** 50-80min
- Investigation tests system : 15min
- Capture screenshots ERB : 20-30min
- Diff HTML HAML vs ERB : 15-20min
- Publication PR : 10min

---

## 🔗 Références

**Documents sources :**
- `pocs/1-haml/PLAN-screenshots-pr.md` (plan détaillé 553 lignes)
- PR #12760 - Commentaire @colinux demandant screenshots

**Workflow existant :**
- `pocs/1-haml/setup.md` (Phases 1-5 actuelles)
- `.claude/prompts/haml-migration.md` (Prompt v3.1)

**Patterns à réutiliser :**
- Tests system avec Capybara (`driven_by :selenium_chrome`)
- `gh pr comment` pour publication PR
- Checkout commits HAML/ERB pour comparaison

---

## ✅ Checklist User

**Avant de lancer spec :**
- [ ] Budget temps acceptable pour Phase 6 ? (50min minimum)
- [ ] MCP Playwright disponible ou OK pour fallback ?
- [ ] Phase 6 optionnelle ou automatique ?
- [ ] Screenshots HAML+ERB ou ERB seulement ?

**Questions pour l'agent spec :**
- Quelle approche privilégier (Option A/B/C) ?
- Breaking changes acceptables ?
- Scope limité à POC 1 ou générique (réutilisable POC 4 features) ?
