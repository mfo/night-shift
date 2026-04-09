---
name: harden-audit
description: "Qualify and score a security vulnerability (DREAD). Use when user has a security report, CVE, or vulnerability to analyze."
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Edit
  - Bash(grep:*)
  - Bash(find:*)
  - Bash(git log:*)
  - Bash(git diff:*)
  - Bash(git blame:*)
  - Bash(curl:*)
  - Agent
---

# Harden Audit — Qualifier une faille de sécurité

Agent spécialisé dans le triage et la qualification de failles de sécurité.

**Mission :** Recevoir un rapport de faille, reproduire, évaluer la criticité réelle (DREAD), produire un parcours explicatif et un fichier d'audit structuré pour `/harden-fix`.

---

## Documents de référence

1. **`checklist.md`** — Checklist par étape, vérifications par type de faille
2. **`patterns.md`** — Patterns validés : faux positifs courants, vecteurs XSS, regex, parsers

---

## Inputs

Sources possibles : rapport `/harden-pentest`, rapport YesWeHack, audit externe, CVE/découverte interne.
Pour chaque source : description, URL/endpoint, payload/STR, criticité annoncée.

---

## Étape 1 : Comprendre le rapport

1. Lire le rapport complet
2. Identifier le type de faille (OWASP Top 10, CWE)
3. Identifier les fichiers/endpoints impactés

---

## Étape 2 : Reproduction locale

1. Identifier l'endpoint dans le code (routes, controllers)
2. Tracer le flow : point d'entrée → traitement → réponse
3. Reproduire le scénario selon le type de faille

**Output :** ✅ Reproduite → continuer | ❌ Non reproduite → documenter pourquoi

---

## Étape 2b : Tracer la chaîne complète (OBLIGATOIRE)

Vérifier que la faille est RÉELLE en suivant le flow complet.

### Chaîne d'appels à tracer :
```
Route → Controller action → before_action / middlewares → Service → Model → Database
```
Lister chaque maillon avec `fichier:ligne`.

### Vérifier CHAQUE maillon :
- Protection présente (scope user, authorize, policy, validation) ?
- Si protection trouvée → **faux positif**, documenter et STOP

### Vérifications par type :

**IDOR :** IDs prédictibles/énumérables ? Si non-énumérables ET non exposés → faux positif même sans scope user.

**XSS :** Hiérarchie de classes (sous-classes vulnérables ?), contexte de rendu (HTML body vs attribut vs JS), validation en entrée au modèle ?

**Injection SQL :** ORM paramètre automatiquement ? (`where(field: value)` = safe)

### Conclusion :
- **Aucune protection** → faille confirmée, continuer vers DREAD
- **Protection trouvée** → **FAUX POSITIF → COURT-CIRCUIT** : écrire audit avec `verdict: faux positif`, `status: false-positive`, **STOPPER ICI**
- **Protection partielle** (contournable) → faille 🟡, documenter

**Statuts négatifs valides :** `false-positive`, `not-reproducible`, `wont-fix`

### Documenter dans l'audit :
```markdown
### Chaîne d'appels
| Niveau | Fichier:ligne | Protection | Verdict |
|---|---|---|---|
| Route | config/routes.rb:42 | — | — |
| Controller | app/controllers/foo.rb:15 | ❌ Aucun scope | Vulnérable |
| Service | app/services/foo.rb:8 | ✅ current_user.scope | Protégé |
```

---

## Étape 3 : Qualification DREAD

| Axe | Question | Score 1-3 |
|---|---|---|
| **Damage** | Impact si exploitée ? | faible/moyen/critique |
| **Reproducibility** | Facilité de reproduction ? | conditionnel/config/déterministe |
| **Exploitability** | Compétences requises ? | outils spécialisés/web basiques/navigateur |
| **Affected users** | Utilisateurs impactés ? | un seul/sous-ensemble/tous |
| **Discoverability** | Facilité de découverte ? | code source/DevTools/interface |

**Score /15 :**
- **14-15** : Critique → fix immédiat (24h)
- **11-13** : Important → fix sprint courant
- **8-10** : Modéré → backlog priorisé
- **5-7** : Faible → accepter le risque (réévaluer dans 6 mois)

### Ancres de scoring

| Axe | 1 — Faible | 2 — Moyen | 3 — Critique |
|---|---|---|---|
| **Damage** | Données publiques | Données d'UN utilisateur | Données sensibles multi-comptes |
| **Reproducibility** | Timing/race condition | Config spécifique | Déterministe |
| **Exploitability** | Outils spécialisés + connaissance interne | curl/DevTools | Navigateur, aucune compétence |
| **Affected users** | Un utilisateur, contexte spécifique | Sous-ensemble (un rôle) | Tous les utilisateurs |
| **Discoverability** | Code source/fuzzing | Inspection API/réseau | Visible dans l'interface |

**Facteur atténuant XSS :** `target="_blank" rel="noopener"` → JS dans nouvel onglet vide, pas de vol session → **Damage -1**. Sans `target="_blank"` → accès DOM complet → pas d'atténuation.

---

## Étape 4 : Parcours explicatif pour l'équipe

Document clair pour les devs (pas experts sécu) :
1. **Contexte** (2-3 phrases) — source, endpoint concerné
2. **Faille expliquée** — analogie non-technique + flow vulnérable + type OWASP/CWE
3. **Démonstration** — STR numérotés, résultat observé vs attendu
4. **Impact réel** — données exposées, scénario d'exploitation, utilisateurs impactés
5. **Score et recommandation** — DREAD justifié, verdict

---

## Étape 5 : Générer le fichier d'audit

Créer `audits/YYYY-MM-DD-[slug]-audit.md` avec frontmatter selon `contract.md`.

**Sections :** Contexte, Classification (OWASP/CWE/DREAD justifié par axe), Faille expliquée (analogie + flow), STR, Impact réel, Analyse technique (fichiers impactés + root cause + reproduction), Recommandation (verdict).

Voir `contract.md` pour les règles de `confidence` et `category`.

---

## Étape 6 : Mettre à jour l'index des audits

Mettre à jour `audits/INDEX.md` : Date, Slug, Status, DREAD, Category, Verdict.

---

## Référentiel OWASP

| ID | Catégorie | Exemples |
|---|---|---|
| A01 | Broken Access Control | IDOR, privilege escalation, force browsing |
| A02 | Cryptographic Failures | Données sensibles en clair, algo faible |
| A03 | Injection | SQL injection, XSS, command injection |
| A04 | Insecure Design | Logique métier exploitable |
| A05 | Security Misconfiguration | Headers manquants, debug en prod, CORS |
| A06 | Vulnerable Components | Gems/packages avec CVE connues |
| A07 | Auth Failures | Session fixation, brute force, MFA bypass |
| A08 | Data Integrity Failures | Deserialization, CI/CD compromise |
| A09 | Logging Failures | Pas de log des accès sensibles |
| A10 | SSRF | Server-Side Request Forgery |

---

## Mode batch (appelé depuis un orchestrateur)

Quand harden-audit est lancé en masse via des agents parallèles :
- L'orchestrateur embarque les instructions complètes dans le prompt agent (les subagents n'ont pas accès au Skill tool)
- Chaque agent écrit directement son fichier `audits/YYYY-MM-DD-[slug]-audit.md` (Write est dans les allowed-tools)
- Limiter à **15-20 agents simultanés** pour éviter le rate limiting
- L'orchestrateur met à jour `audits/INDEX.md` après consolidation

---

## Livrable

1. **Fichier d'audit** : `audits/YYYY-MM-DD-[slug]-audit.md` (consommable par `/harden-fix`)
2. **Parcours explicatif** dans la conversation
3. **Verdict clair** : fix immédiat / sprint courant / backlog / accepter le risque

→ Découvrir des failles : `/harden-pentest`
→ Corriger : `/harden-fix audits/YYYY-MM-DD-[slug]-audit.md`
