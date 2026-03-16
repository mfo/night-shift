# Catalogue des techniques d'optimisation de tests

**Évolutif** — enrichi au fur et à mesure des itérations kaizen.
**Projet cible** : demarches-simplifiees.fr (Rails 7.2, Ruby 3.4, PostgreSQL 17, RSpec, FactoryBot, Playwright)

**Contexte clé** : test-prof est installé, `let_it_be` est require dans `spec_helper.rb:25` mais **0 usage dans les specs**. La factory `:dossier` cascade sur `:procedure` (~15-25 INSERTs par dossier). Ratio create/build = 10:1. `build_stubbed` = 0 usage.

---

## Techniques par fichier (pour l'agent)

L'agent applique ces techniques fichier par fichier pendant l'optimisation.

| ID | Technique | Description | Signal de détection | Risque | Gain typique |
|---|---|---|---|---|---|
| T01 | create → build / build_stubbed | Remplacer `create(:dossier)` par `build(:dossier)` ou `build_stubbed(:dossier)` quand le test ne fait pas de query DB. **0 `build_stubbed` dans le projet actuellement.** | `create(:` dans un test qui ne fait ni query, ni reload, ni `find`. Model specs de validations, méthodes pures. | Faible si bien ciblé — le test casse immédiatement si la conversion est incorrecte. ⚠️ La factory `:dossier` force un `create(:procedure)` dans son transient. | **5-15%** |
| T02 | includes/preload | Corriger les N+1 queries dans le code applicatif détectés pendant les tests. | `SELECT` répétés dans les logs de test. Utiliser `Prosopite` ou `Bullet`. | Modifie le code de prod — nécessite review. | **Moyen** |
| T03 | stub API externe | Mocker les appels réseau (HTTP, SMTP, S3) avec WebMock/VCR. | `Net::HTTP`, `Faraday` appelés dans le code sous test. | Cassettes VCR périmées qui masquent des changements d'API. | **Fort** |
| T04 | réduire setup inutile | Supprimer les `create`/`let!` non nécessaires au test. | `let!(:foo)` dont le nom n'apparaît pas dans le bloc `it`. Fichiers avec 10+ `let!` (ex: `expired_dossiers_deletion_service_spec.rb` = 57 `let!`). | Un side-effect implicite existe parfois (callback qui crée un record nécessaire). | **Moyen** |
| T06 | supprimer tests dupliqués | Supprimer les tests qui vérifient le même comportement. | Deux `it` avec la même assertion ou le même `expect`. | Supprimer un test qui couvrait un edge case subtil. | **Moyen** |
| T08 | let_it_be / before_all | **Levier #1 sur ce projet.** Remplacer `let(:procedure) { create(:procedure) }` par `let_it_be(:procedure)` dans les describe qui ne mutent pas l'objet. Gem déjà require, 0 usage. Chaque `let_it_be(:dossier)` économise (N-1) créations × 15-25 INSERTs. | `let(:procedure) { create(:procedure` — des centaines d'occurrences. `let(:dossier) { create(:dossier` idem. | Si un test mute l'objet → pollution inter-tests. Utiliser `let_it_be(..., reload: true)` ou `refind: true`. | **15-40%** |
| T09 | aggregate_failures | Regrouper plusieurs assertions dans un seul `it` avec `aggregate_failures` — réduit le nombre de setups répétés. | Un `describe` avec 5+ `it` qui ont le même `before` et testent des attributs différents du même objet. | Le premier échec ne bloque pas les suivants (atténué par `aggregate_failures` qui les montre tous). | **Moyen** |
| T10 | let! → let (lazy) | Convertir les `let!` en `let` (lazy) quand le record n'est pas utilisé par tous les examples du group. **~850 `let!` dans le projet.** | `let!(:x)` non référencé dans certains `it`. Fichiers lourds : `dossier_filter_service_spec.rb` (76 `let!`). | Si un `let!` existe pour un side effect (création en DB pour un scope), le retirer casse le test. Vérifier au cas par cas. | **10-20%** |
| T11 | factory_default / create_default | Définir une procedure par défaut avec `create_default(:procedure)` pour éviter que chaque `create(:dossier)` recrée une procedure. Élimine la cascade. Nécessite `require 'test_prof/recipes/rspec/factory_default'` dans spec_helper. | Context avec 5+ dossiers pour la même procedure — chaque dossier recrée sa propre procedure. | Si deux examples ont besoin de procedures différentes dans le même context, ça casse. | **20-30%** |

| T12 | split fichier spec | Découper un fichier spec monolithique (1000+ lignes) en fichiers thématiques (scopes, state transitions, expiration, callbacks…). Réduit le setup par fichier et facilite le parallélisme CI. Dupliquer les `let` top-level nécessaires dans chaque fichier — **pas de shared_context ni shared_example** (indirection pour peu de valeur). | Fichier spec > 1000 lignes ou > 100 examples. `describe` indépendants avec des setups distincts. | Risque faible. Attention aux `let` définis au top-level et utilisés dans plusieurs describe — les dupliquer explicitement. | **10-20%** (via parallélisme + setup réduit) |

<!-- Ajouter ici les nouvelles techniques découvertes par les agents -->

---

> **Techniques globales (one-shot)** : voir `pocs/test-optimization/one-time-optimizations.md` — hors scope agent.
