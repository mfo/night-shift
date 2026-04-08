# Checklist Harden Fix

## Étape 1 : Gate d'entrée
- [ ] Fichier d'audit existe ?
  - Si **non** → mode fast-track : créer audit minimal inline avant de continuer
- [ ] `status: qualified` ?
- [ ] `chain_verified: true` ? (si false → re-vérification obligatoire étape 2b)
- [ ] `confidence` renseigné ? (si low → re-vérification obligatoire étape 2b)
- [ ] `affected_files` listés ?
- [ ] `test_vector` renseigné ?
- [ ] Root cause identifiée dans l'audit ?
- [ ] **Si `verdict: faux positif` → STOP**, ne pas fixer un faux positif
- [ ] **Si `verdict: accepter le risque` → confirmer** avec l'utilisateur
- [ ] **Si audit incomplet → STOP**, demander complétion via `/harden-audit`

## Étape 2 : Analyse code
- [ ] Fichiers impactés relus ?
- [ ] Root cause confirmée dans le code ?
- [ ] Points de correction identifiés (fichier:ligne exact) ?
- [ ] Impact sur autres features évalué ?

## Étape 2b : Re-vérification indépendante
- [ ] **Obligatoire si** : IDOR/BAC (A01), OU confidence ≠ high, OU chain_verified = false ?
- [ ] Chaîne tracée indépendamment (Route → Controller → before_action héritées → Service → Model → DB) ?
- [ ] Chaque maillon vérifié avec fichier:ligne ?
- [ ] Si protection trouvée → **STOP, challenger l'audit**, demander validation user ?

## Étape 3 : Plan de commits validé
- [ ] Plan présenté à l'utilisateur ?
- [ ] Utilisateur a validé AVANT de coder ?
- [ ] Pattern TDD respecté : RED (test prouve faille) → GREEN (fix + inversion) → HARDEN (optionnel) ?

## Étape 4 : Commit 1 — Test RED
- [ ] Type de spec choisi (request / model / system) ?
- [ ] Test écrit qui PROUVE la faille (assertion = comportement vulnérable) ?
- [ ] Test PASSE (la faille existe) ?
  ```bash
  bundle exec rspec <fichier_spec>
  ```
- [ ] Commit créé : `test(security): add spec proving [description]` ?

## Étape 5 : Commit 2 — Fix GREEN
- [ ] Fix minimal appliqué ?
- [ ] **Principe respecté : validation en entrée (modèle) > sanitization en sortie (view)** ?
- [ ] Assertion du test inversée (comportement vulnérable → bloqué) ?
- [ ] Test PASSE après inversion ?
  ```bash
  bundle exec rspec <fichier_spec>
  ```
- [ ] Non-régression vérifiée ?
  ```bash
  bundle exec rspec <specs liées>
  ```
- [ ] Commit créé : `fix(security): [description]` ?

## Étape 6 : Mise à jour audit + index
- [ ] Fichier audit mis à jour : `status: fixed`, `fixed_date`, `fix_pr` ?
- [ ] `audits/INDEX.md` mis à jour avec le nouveau statut ?

## Étape 7 : PR
- [ ] PR créée avec description pédagogique ?
- [ ] Titre court (< 70 chars) ?
- [ ] "La faille en 30 secondes" (repris de l'audit) ?
- [ ] STR (repris de l'audit) ?
- [ ] Preuve par les tests (commit 1 = RED, commit 2 = GREEN) ?
- [ ] Points d'attention pour la review ?

## Vérifications finales
- [ ] Suite tests complète passe ?
- [ ] Aucune régression ?
- [ ] Fichier audit status = `fixed` ?
- [ ] PR créée et linkée dans l'audit ?
