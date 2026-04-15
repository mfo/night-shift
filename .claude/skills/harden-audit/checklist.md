# Checklist Harden Audit

## Étape 0 : Qualification métier
- [ ] **Mode interactif** : questions posées AU USER (pas auto-répondues) ?
  - Comportement voulu ? Données sensibles dans ce contexte ? Attaquant réaliste ?
  - User a répondu AVANT de continuer ?
  - Si user hésite → proposé bascule en mode batch (faits + indéterminé) ?
- [ ] **Mode batch** : faits écrits vs dimensions indéterminées séparées ?
  - Namespace, before_action, champs exposés = faits
  - Sensibilité données, intention design = indéterminé si pas dans le code
  - **Règle mécanique : section "Indéterminé" non vide → `confidence: low` obligatoire** (pas de medium/high)

## Étape 1 : Compréhension du rapport
- [ ] Rapport lu entièrement (source, description, STR, criticité) ?
- [ ] Type OWASP identifié (A01-A10) ?
- [ ] CWE identifié (si applicable) ?
- [ ] Fichiers/endpoints impactés identifiés dans le code ?

## Étape 2 : Reproduction locale
- [ ] Endpoint identifié dans routes + controller ?
- [ ] Scénario reproduit localement (curl / browser / console) ?
- [ ] Si non reproductible → documenté pourquoi ?

## Étape 2b : Chaîne complète (CRITIQUE — anti faux-positifs)
- [ ] Chaîne tracée : Route → Controller → before_action → Service → Model → DB ?
- [ ] Chaque maillon listé avec fichier:ligne ?
- [ ] Protection d'**autorisation** (pas juste authentification) vérifiée à chaque niveau ?
  - `authenticate_user!` = authentification (qui es-tu ?) ≠ autorisation (as-tu le droit ?)
  - Scope user, policy, authorize = autorisation
- [ ] **Si protection d'autorisation trouvée en aval → FAUX POSITIF**, documenter et ne pas continuer vers DREAD

### Vérifications spécifiques par type
**Si IDOR :**
- [ ] IDs prédictibles/énumérables ? (auto-increment = oui, UUID = non)
- [ ] IDs exposés publiquement (URL, API response) ?
- [ ] Si non-énumérables ET non exposés → faux positif

**Si XSS :**
- [ ] Hiérarchie de classes : sous-classes/sœurs impactées ?
- [ ] Contexte de rendu identifié (HTML body / attribut / JS / CSS) ?
- [ ] Validation en entrée (modèle) déjà présente ?
- [ ] html_safe, raw(), innerHTML, insertAdjacentHTML repérés ?

**Si Regex :**
- [ ] Alternations groupées `(?:...)` ?
- [ ] Ancres `^` `$` présentes ?

**Si Parsers (email, URL) :**
- [ ] Sortie peut contenir HTML/JS ?

## Court-circuit faux positif
- [ ] Si protection trouvée à l'étape 2b → `verdict: faux positif`, `status: false-positive`, STOP ?
- [ ] Si non reproductible → `status: not-reproducible`, STOP ?
- [ ] Ne PAS passer à l'étape 3 si faux positif confirmé ?

## Étape 3 : Scoring DREAD
- [ ] **Faille confirmée** à l'étape 2b (sinon STOP — pas de scoring sur un FP) ?
- [ ] **Baseline d'exposition vérifié** : quelles données sont DÉJÀ exposées by design sur la même surface (même controller, même page, autre action) ? Le delta réel = nouvelle exposition - exposition existante.
- [ ] Damage: score 1-3 avec justification + ancre de référence ?
- [ ] Reproducibility: score 1-3 avec justification + ancre de référence ?
- [ ] Exploitability: score 1-3 avec justification + ancre de référence ?
- [ ] Affected users: score 1-3 avec justification + ancre de référence ?
- [ ] Discoverability: score 1-3 avec justification + ancre de référence ?
- [ ] Total /15 calculé (rappel : minimum réel = 5) ?
- [ ] Seuils corrects : 14-15 critique, 11-13 important, 8-10 modéré, 5-7 faible ?
- [ ] Verdict clair (fix immédiat / sprint courant / backlog / accepter le risque) ?
- [ ] Category assignée : `security` (pipeline normal) ou `hardening` (batch trimestriel) ?

## Étape 4 : Parcours explicatif
- [ ] Analogie non-technique écrite ?
- [ ] Flow vulnérable schématisé ?
- [ ] STR numérotés (résultat observé vs attendu) ?
- [ ] Impact réel documenté (données, scénario, utilisateurs) ?

## Étape 5 : Fichier d'audit
- [ ] Créé dans `audits/YYYY-MM-DD-[slug]-audit.md` ?
- [ ] Frontmatter complet :
  - title, source, date, owasp, cwe ?
  - dread_score, verdict, status ?
  - **category** (security / hardening) ?
  - **confidence** (high / medium / low) calculée selon règle ?
  - **chain_verified** (true / false) ?
  - **test_vector** renseigné ?
  - **affected_files** listés ?
- [ ] Chaque maillon du tableau "Chaîne d'appels" a un `fichier:ligne` réel (pas de placeholder) ?
- [ ] Section "Fichiers impactés" avec lignes ?
- [ ] Root cause explicite ?
- [ ] Prêt pour `/harden-fix` ?

## Étape 6 : Index des audits
- [ ] `audits/INDEX.md` mis à jour (ou créé) avec la nouvelle entrée ?
