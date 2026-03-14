# Kaizen - Fix snowball emails de renouvellement de session (Phase Spec)

**Date :** 2026-03-13
**Tâche :** Spec technique — dédupliquer les emails de renouvellement dans le cron TrustedDeviceTokenRenewalJob
**Temps :** ~1h30
**Status :** ✅ SUCCÈS (spec v2 production-ready)

---

## 🎯 Objectif vs Résultat

**Objectif initial :**
- Créer une spec pour fixer l'effet snowball sur les emails de renouvellement de session

**Résultat obtenu :**
- ✅ Investigation approfondie cookie vs token DB (indépendance prouvée)
- ✅ Simplification P0+P1 → un seul changement (dédupliquer dans le cron)
- ✅ Spec v2 post-review PM, production-ready
- ✅ 9 findings PM analysés un par un avec user

**Gap :**
- Aucun — le scope a été réduit (P0+P1 fusionnés) ce qui est un gain

---

## ✅ Ce Qui a Bien Marché

### Techniques/Patterns Efficaces

1. **Investigation approfondie avant de spécifier**
   - **Pourquoi :** La question "est-ce que révoquer un token casse le multi-appareils ?" a été tranchée par l'analyse du code, pas par hypothèse
   - **Impact :** A prouvé que le cookie est self-contained → la révocation est safe → a simplifié toute l'architecture de la solution
   - **À réutiliser sur :** Tout bug où le comportement exact n'est pas certain

2. **Simplification progressive par les questions du user**
   - **Pourquoi :** Le user a challengé chaque complexité ajoutée :
     - "pas de revoked_at, c'est trop de taff" → suppression de la migration
     - "pourquoi ne pas just prendre le dernier ?" → plus besoin de destroy_all
     - "on peut créer de nouveaux tokens, c'est de l'historique" → P0 = P1
   - **Impact :** Spec finale = 2 fichiers impactés + 1 migration hygiène, au lieu de 6+ fichiers avec revoked_at
   - **À réutiliser sur :** Toujours proposer la solution la plus simple d'abord, laisser le user complexifier si besoin

3. **Review PM avec validation point par point**
   - **Pourquoi :** Au lieu d'intégrer tous les findings d'un coup, chaque point a été discuté avec le user
   - **Impact :** 3 faux positifs identifiés (token_valid_until, soft-delete, métriques), 4 vrais correctifs intégrés
   - **À réutiliser sur :** Toujours passer les findings PM un par un avec le user

4. **Correction d'approche en cours de route (find_each → Instructeur.find_each)**
   - **Pourquoi :** Le user a détecté le risque OOM du group_by en mémoire et a demandé une approche SQL
   - **Impact :** Solution finale avec mémoire constante, plus robuste que la v1
   - **À réutiliser sur :** Toujours préserver find_each quand il existe déjà, changer l'entité itérée plutôt que de passer en mémoire

### Autonomie

- **Charge mentale :** FAIBLE
  - User a guidé les décisions d'architecture (normal pour une spec)
  - Pas de blocage technique

- **Fire-and-forget :** ⚠️ Non, mais collaboration fluide
  - 4 questions d'architecture (Q2-Q4 légitimes, choix métier)
  - 9 points PM validés rapidement

- **Checkpoints :** ✅ Efficaces
  - Investigation cookie/token = checkpoint clé qui a débloqué la simplification
  - Review PM structurée en todo list = validation propre

---

## ⚠️ Ce Qui a Coincé

### Blocages Rencontrés

1. **Templates introuvables (mauvais chemin)**
   - **Problème :** Les templates feature-spec étaient dans `night-shift/pocs/4-features/`, pas dans `pocs/4-features/`
   - **Cause :** Le skill reference des chemins relatifs sans le préfixe `night-shift/`
   - **Solution appliquée :** Glob search pour trouver les fichiers
   - **Temps perdu :** 2 min
   - **Learning :** Les chemins dans les skills devraient être mis à jour ou le skill devrait chercher les templates

2. **Complexité initiale trop élevée (revoked_at)**
   - **Problème :** La spec initiale prévoyait un champ revoked_at, une migration, des changements au controller
   - **Cause :** Réflexe "solution complète" au lieu de "solution minimale"
   - **Solution appliquée :** User a simplifié en 3 étapes : pas de revoked_at → pas de destroy → P0=P1
   - **Temps perdu :** 10 min
   - **Learning :** Commencer par la solution la plus simple, pas la plus "architecturalement correcte"

### Questions Posées

- **Nombre total :** 4 questions d'architecture + 9 points PM
- **Légitimes (décisions métier) :** 4/4
- **Évitables :** 0

---

## 🔄 Améliorations à Apporter

### Pour le prompt feature-spec

- [ ] **Corriger chemins templates :** `pocs/4-features/` → `night-shift/pocs/4-features/`
- [ ] **Ajouter principe :** "Toujours proposer la solution minimale d'abord, complexifier uniquement si le user le demande"
- [ ] **Ajouter pattern :** "Investigation code avant spec — prouver les hypothèses par le code, pas par intuition"

### Pour le workflow général

- [ ] **Review PM point par point :** Ne pas intégrer tous les findings d'un coup, valider chaque point avec le user via todo list
- [ ] **Préserver find_each :** Si le code existant utilise find_each, ne pas le remplacer par group_by en mémoire — changer l'entité itérée plutôt

---

## 📊 Métriques

### Temps

- **Temps prévu :** 4-8h (template)
- **Temps réel :** ~1h30
- **Écart :** -2h30 (scope réduit = gain de temps)
- **Répartition :**
  - Lecture templates + code existant : 15 min
  - Investigation cookie/token : 20 min
  - Questions architecture user : 15 min
  - Rédaction spec v1 : 15 min
  - Review PM + validation points : 20 min
  - Corrections spec v2 : 10 min

### Qualité

- **Spec complète :** ✅ 15 sections
- **Review findings :** 9 problèmes analysés (4 intégrés, 3 faux positifs, 2 rejetés)
- **Mergeable :** ✅ Production-ready

### Autonomie

- **Agent-friendly score :** 8/10
  - Investigation autonome efficace (cookie/token)
  - Rédaction spec autonome
  - Review PM autonome
  - -2 points car : décisions architecture nécessitent user (attendu)

---

## 💡 Learnings Clés

### Ce que j'ai appris sur CE projet

1. **Le cookie trusted_device est self-contained** — `trusted_device?` ne lit que le cookie, jamais la DB. C'est une architecture critique à connaître pour tout futur travail sur l'auth instructeur.

2. **Le cron TrustedDeviceTokenRenewalJob crée des tokens** — chaque email de renewal crée un nouveau token, ce qui est la source de l'amplification. Pattern à surveiller sur d'autres crons.

3. **L'user privilégie la simplicité radicale** — "pas de revoked_at, c'est trop de taff", "pourquoi ne pas juste prendre le dernier ?". La solution la plus simple qui résout le problème est toujours préférée.

### Ce que j'ai appris sur l'IA & ce type de tâche

1. **Specs simples = très agent-friendly (8/10)**
   - Contrairement à l'itération 1 (5h30, 7/10), un problème bien borné avec une solution simple = spec rapide et fluide
   - La clé est la phase d'investigation qui réduit le scope

2. **L'investigation code > les hypothèses**
   - Tracer le code pour prouver l'indépendance cookie/token a été le point de bascule
   - Sans ça, on aurait eu une spec avec revoked_at, migration, changements controller — 3x plus complexe

3. **Les faux positifs PM sont fréquents sur les specs simples**
   - 3/9 findings étaient des faux positifs (token_valid_until, soft-delete, NOT NULL)
   - Plus la spec est simple, plus les findings PM risquent d'être du bruit
   - Validation point par point avec user = filtre efficace

### Hypothèses Validées

- ✅ **Investigation avant spec** réduit la complexité de la solution
- ✅ **Review PM point par point** > intégration en bloc (filtre les faux positifs)
- ✅ **Solution minimale d'abord** = meilleur résultat (user simplifie toujours)
- ✅ **find_each à préserver** quand il existe (risque OOM sinon)

---

## 🚀 Prochaines Actions

### Pour la prochaine tâche similaire

1. **Investiguer le code AVANT de spécifier** — prouver les hypothèses
2. **Proposer la solution minimale** — laisser le user complexifier
3. **Valider les findings PM un par un** — ne pas intégrer en bloc

### Pour améliorer le process

1. **Corriger les chemins dans le skill feature-spec** — `night-shift/pocs/4-features/`
2. **Ajouter "investigation code" comme étape 0** du workflow spec — avant l'analyse problème

---

**Learning principal :** L'investigation code en amont (20 min) a économisé des heures de complexité inutile. La preuve que le cookie est self-contained a transformé un problème "effort M" (revoked_at, migration, multi-appareils) en "effort S" (dédupliquer le cron).
