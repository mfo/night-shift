# Catalogue des techniques d'optimisation de tests

**Évolutif** — enrichi au fur et à mesure des itérations kaizen.
**Projet cible** : demarches-simplifiees.fr (Rails 8.0, Ruby 3.4, PostgreSQL 17, RSpec, Oaken, FactoryBot, Playwright)

> ⚠️ **Ce fichier décrit l'état du repo — il pourrit.** Ne pas s'y fier seul : lire
> `AGENTS.md` §Testing Philosophy au début de chaque run (étape 0 du SKILL.md). En cas de
> divergence, `AGENTS.md` fait foi et ce catalogue doit être corrigé.

**Contexte clé (vérifié le 2026-08-17 sur `origin/main`)** : le projet est passé aux **seeds Oaken**.
Le monde entier (`db/seeds/` : users, procedures, dossiers, avis, entreprise, messagerie) est semé
**une fois par suite** via `oaken/rspec_setup` (`spec/support/oaken.rb`), et les accesseurs labellisés
sont disponibles dans **tous** les examples. Les fixtures ActiveRecord
(`spec/fixtures/{administrateurs,users,instructeurs}.yml`, `config.global_fixtures`) ont été
**supprimées** — `administrateurs(:default_admin)` n'existe plus.

Conséquence sur la stratégie d'optimisation : **le levier #1 n'est plus de mutualiser les `create`
(T08) mais de les supprimer (T13)**. La cascade factory `:dossier` → `:procedure` reste chère quand
elle subsiste, mais un record semé coûte **zéro** setup, pas « un setup partagé ».

---

## Techniques par fichier (pour l'agent)

L'agent applique ces techniques fichier par fichier pendant l'optimisation.

| ID | Technique | Description | Signal de détection | Risque | Gain typique |
|---|---|---|---|---|---|
| **T13** | **create → seed Oaken** | **Levier #1 depuis la migration Oaken. À tenter AVANT T08.** Remplacer un `create(:procedure)` / `create(:dossier)` / `create(:administrateur)` générique par l'accesseur semé équivalent (`procedures.individual`, `dossiers.en_construction`, `administrateurs.default`…). Le record existe déjà : coût de setup **nul**, pas seulement mutualisé. Si plusieurs specs ont besoin du même setup non-trivial absent des seeds, ajouter un fichier dans `db/seeds/cases/` et le charger par groupe avec `before_all { seed "cases/xxx" }`. | `create(:` sur un modèle qui a un accesseur semé (voir catalogue ci-dessous), **sans attribut spécifique** — le record est un simple figurant. À l'inverse : garder FactoryBot quand les attributs **sont le sujet du test**. | Le record semé est partagé : toute mutation doit rester dans la transaction de l'example (c'est le cas par défaut). ⚠️ Ne jamais utiliser un accesseur dont le modèle est vidé par `empty_seeds` dans le même groupe. | **30-70%** |
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

## Catalogue des accesseurs semés (T13)

Disponibles dans **tous** les examples, sans setup. Source : `db/seeds/`.
⚠️ Vérifier par `git show origin/main:db/seeds/<f>.rb` — les labels bougent.

| Accesseur | Contenu |
|---|---|
| `users.usager` / `.admin` / `.instructeur` / `.expert` / `.second_expert` / `.blank_admin` | Personas. Mot de passe partagé : `users.default_password` |
| `administrateurs.default` | Admin propriétaire de tout le monde semé |
| `administrateurs.blank` | Admin **garanti sans rien** — pour les specs sur l'état agrégé d'un admin (suppression, merge, unused, scoping de token) |
| `instructeurs.default` / `.admin` | `.admin` est l'instructeur du user admin |
| `experts.default` / `.second` — `experts_procedures.default` / `.second` | `.second` sert aux tests de confidentialité |
| `procedures.individual` | Démarche publiée `for_individual`, 6 types de champ courants, instructeur assigné |
| `procedures.close` / `.depubliee` / `.brouillon` / `.entreprise` | Autres états du cycle de vie |
| `dossiers.brouillon` / `.en_construction` / `.en_instruction` / `.accepte` / `.refuse` | Sur `procedures.individual`, antidatés d'1 jour |
| `avis.pending` / `.answered` / `.confidentiel` / `.with_file` | |
| `commentaires.from_instructeur` / `.from_usager` | |
| `services.default`, `zones.default` | |

**Seeds de scénario** (`db/seeds/cases/`), chargés par groupe avec `before_all { seed "cases/xxx" }` :

| Seed | Fournit |
|---|---|
| `cases/routage` | `procedures.routee` — publiée, 2 groupes instructeurs, **aucun instructeur assigné** |
| `cases/champs` | `procedures.tous_champs` |
| `cases/sva` | `procedures.<decision>` |

## Seed-safety (règles dures)

Le monde étant semé, un spec ne peut plus supposer une base vide :

- ❌ **Jamais d'assertion sur un compte global ou un scope non paramétré** — `Procedure.all`,
  `Dossier.count`, SQL brut sur une table entière. Scoper aux records du spec.
- ✅ Sinon, déclarer `empty_seeds Dossier, Procedure` **en tête de groupe, avant tout `let_it_be`**
  (helper dans `spec/support/oaken.rb`). Lister les dépendants avant les parents. Les accesseurs
  des modèles vidés deviennent inutilisables dans ce groupe.
- ✅ Specs sur l'état agrégé propre d'un admin → `administrateurs.blank`.
- ⚠️ Attention aux `let` qui **masquent** un accesseur semé (`let(:procedures)`, `let(:users)`) —
  tchak a dû faire une passe de renommage dédiée (`71c1de4695`).

> **Techniques globales (one-shot)** : voir `pocs/test-optimization/one-time-optimizations.md` — hors scope agent.


## Auto-discovered pitfalls

<!-- Managed by autolearn. Review via kaizen synth. -->

### AL-1 — Invocation du skill (2026-07-01, consolidé de 5 doublons le 2026-08-17)

`test-optimization` est un **agent type**, pas une commande slash.

- ✅ `Agent({ subagent_type: 'test-optimization', prompt: 'Optimize spec/path/to/file_spec.rb' })`
- ❌ `Skill({ skill: 'test-optimization' })` ou `/test-optimization` → « Unknown command »

L'orchestrateur de batch doit utiliser l'outil Agent avec `subagent_type`.

> **Note autolearn** : ce learning a été capturé 5 fois à l'identique (AL-1..AL-5, sur 12 min).
> Dédupliquer avant d'ajouter une entrée — vérifier qu'aucune entrée existante ne dit déjà la même chose.

### AL-6 — Le catalogue pourrit plus vite que les runs (2026-08-17)

Le socle de données de test a changé (fixtures AR → seeds Oaken) sans qu'aucun run n'échoue :
tests verts, PR mergées, checks OK. Le skill a continué à optimiser contre un modèle du monde
périmé pendant des semaines, et a proposé un fix vers une API supprimée.

**Règle** : au début de chaque run, lire `AGENTS.md` §Testing Philosophy (étape 0). Si le socle
décrit diverge de ce catalogue, **s'arrêter et signaler** au lieu d'optimiser à l'aveugle.
