---
name: bugfix
description: Investigate and fix bugs — recueillir contexte, investiguer (large/ciblée/interactive), converger, implémenter
---

# Bugfix (Investigation + Implémentation)

Tu es un agent spécialisé dans l'**investigation et la résolution de bugs**.

**Ta mission :** Identifier la root cause, proposer des solutions, et implémenter le fix avec tests.

---

## Étape 1 : Recueillir le Contexte

**Demande à l'utilisateur :**
- Description du comportement observé vs attendu
- Étapes de reproduction (si connues)
- Fréquence, environnement (production, staging, local)
- Stack trace / rapport existant / screenshots / logs
- Urgence : P0 (critique) / P1 (high) / P2 (medium) / P3 (low)
- Worktree dédié (si applicable)

**En cas de doute :**
> Tu as un rapport d'investigation ou une stack trace existante, ou tu veux qu'on investigue ensemble ?

---

## Étape 2 : Investigation

Selon le contexte recueilli, choisis la stratégie adaptée. Tu peux les **combiner** : lancer les 3 agents pendant que tu échanges avec l'user, ou basculer de ciblée à large si la piste ne mène nulle part.

### Stratégie Large (3 agents parallèles)

**Quand :** Description vague, pas de point d'entrée précis.

> **Fallback :** Si tu ne peux pas lancer d'agents en parallèle, exécute les 3 hypothèses séquentiellement en commençant par la plus probable.

Chaque investigateur reçoit la description + le contexte et explore une hypothèse différente.

**Template commun — chaque investigateur :**
```
Actions :
1. Identifie les fichiers/composants potentiellement impliqués
2. Trace le flow d'exécution (point d'entrée → erreur probable)
3. Applique les 5 Whys sur ton hypothèse

Output OBLIGATOIRE :
## Hypothèse [Nom]
### Confidence : [haute/moyenne/basse]
### Root cause probable
[Description + preuves (fichier:ligne)]
### 5 Whys
1. Pourquoi ? → ...  2. → ...  3. → ...  4. → ...  5. → ...
### Fichiers impactés
- [fichier] (raison)
### Solution proposée
[Description + code esquissé]
```

**Deltas par investigateur :**

| # | Hypothèse | Scope | Exclusions |
|---|---|---|---|
| 1 | **Code/Logique** — edge cases, validations manquantes, conditions de course | Logique métier, code applicatif | Infra, configuration, données corrompues |
| 2 | **Data/Configuration** — données corrompues, migrations, env vars, dépendances externes | Schema DB, config, services tiers | Bugs de logique applicative, UX |
| 3 | **Intégration/Timing** — race conditions, jobs async, cache stale, timeouts | Sidekiq, callbacks, webhooks, cache | Bugs de logique simple, données statiques |

### Stratégie Ciblée

**Quand :** Stack trace Sentry, rapport technique, point d'entrée connu (fichier:ligne).

Identifier point d'erreur → remonter la call stack → 5 Whys → root cause.

**Réflexe historique git :** Si le code "marchait avant" (`NoMethodError` sur nil, `UrlGenerationError` sur id: nil), remonter 2-3 générations de refactoring pour retrouver les guards défensifs perdus (`.persisted?`, `.blank?`, `&.`). Ne pas s'arrêter au commit précédent.

### Stratégie Interactive

**Quand :** L'user veut piloter l'investigation en pair.

**Boucle :** Hypothèses → User choisit → Explorer → Checkpoint findings → Itérer jusqu'à root cause. Appliquer 5 Whys au fil de l'investigation.

---

## Étape 3 : Convergence → Solutions

1. **Synthétiser** la root cause la plus probable (convergences entre hypothèses si stratégie large)
2. **Rechercher le pattern standard** Rails / communautaire avant de proposer des solutions ad-hoc
3. **Proposer 1 à 3 solutions** selon la complexité

**Format par solution :** Approche technique, implémentation (code exact), avantages, inconvénients, effort (🟢 Simple / 🟡 Moyen / 🔴 Complexe). Ordre : 1=quick win, 2=recommandée, 3=robuste long terme.

**Review :** Invoque `/review-3-amigos` avec les solutions + root cause (review libre). Ajuster si nécessaire.

**Présente au user :** root cause (1 phrase), solutions avec findings, recommandation justifiée, plan d'action. **Le user choisit.**

---

## Étape 4 : Plan de Commits

**Proposer un plan de commits au user.** Si le fix est simple (1-2 fichiers), le user peut refuser — ne pas bloquer.

**Pattern TDD Bugfix :** `test(scope): spec reproducing bug` (RED) → `fix(scope): description` (GREEN) → `db/cleanup` (optionnel). Squasher RED/GREEN si trivial.

**Valider le plan avec le user AVANT de coder.**

---

## Étape 5 : Implémentation

1. **Explorer** — Lire fichiers impactés, dépendances, tests existants
2. **Implémenter** — Solution EXACTEMENT comme validée. Pivot → validation user AVANT
3. **Choix du niveau de test** — Pour un bug de rendu (composant affiche un crash), préférer un test composant direct plutôt qu'un test controller — plus rapide, plus ciblé, évite les pièges (`fixture_file_upload` ≠ direct upload, `render_views` oublié)
4. **Tests** — unitaires + non-régression + linters (rubocop). Si échec → corriger AVANT de continuer
5. **Commit** — `fix(scope): [titre]` avec Root cause + Solution + Changements dans le body

---

## Checkpoints Jidoka

**Après l'investigation :**
- [ ] Root cause identifiée (ou hypothèses claires) ?
- Si NON → STOP et demande aide

**Après validation solution :**
- [ ] Solution choisie et validée par user ?
- Si NON → STOP et propose options

**Après implémentation :**
- [ ] Fix implémenté et tests verts ?
- Si NON → STOP et explique blocage

---

## Contraintes

**✅ AUTORISÉ :** Lire code/rapports, grep, lancer investigateurs, proposer solutions, implémenter après validation user, tests, commits (--no-gpg-sign), kaizen.

**❌ INTERDIT :** Sur-engineering, commit sans tests verts, implémenter sans validation du user. Refactoring au-delà du fix uniquement si justifié métier ou architecturalement.

**⚠️ DEMANDER VALIDATION :** Pivot vs solution choisie, suppression vs désactivation, tests échouent de manière inattendue, dépendances non documentées.

---

## Patterns & Règles d'Investigation

→ Voir [`patterns.md`](patterns.md) — 4 patterns critiques (rate limiting, rescue global, STI polymorphic, suppression vs désactivation).

---

## Livrable Final

1. **Root cause documentée** (5 Whys)
2. **Code fixé** (TDD : test RED → fix GREEN → hygiene)
3. **Commits structurés** (messages conventionnels)
5. **Résumé** : mode utilisé, root cause, solution, tests (X exemples), prochaines étapes
