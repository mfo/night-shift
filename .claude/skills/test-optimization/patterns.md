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

**Où en est vraiment le repo** (relevé le 2026-09-09 sur `origin/main`, 1010 fichiers spec) :

| | |
|---|---|
| `create(:` | **6484** dans 777 fichiers |
| `let!(` | **1912** |
| `let_it_be` | **103** dans 16 fichiers |
| fichiers touchant un accesseur semé | **251** |
| `before_all { seed "cases/…" }` | **5** |
| `empty_seeds` | **23** |
| `build_stubbed` | **2** |
| `create_default` | **0** (et le require `factory_default` est absent) |

Autrement dit : le socle Oaken est en place depuis un an, **la consommation ne l'est pas**. C'est là
qu'est le gisement, pas dans les micro-techniques.

---

## Techniques par fichier (pour l'agent)

L'agent applique ces techniques fichier par fichier pendant l'optimisation.

### Arbitrer T13 (seed) vs T08 (`let_it_be`) — à lire avant le tableau

Les deux techniques déplacent le même curseur, **la portée d'amortissement du setup** :

```
create dans un let  ->  1 fois par example
let_it_be           ->  1 fois par groupe (describe)
accesseur semé      ->  1 fois par suite   (déjà payé : coût nul)
```

Elles ne sont pas interchangeables pour autant, et « laquelle est la plus rapide »
n'est **pas** le bon critère. Le critère est celui d'`AGENTS.md` §Testing Philosophy,
et c'est lui qui fait foi :

> *Reach for a seeded record first; only fall back to a factory when the spec needs
> attributes the seeds don't provide. […] Keep FactoryBot for records whose attributes
> are the point of the test.*

D'où l'arbre de décision :

```
Les attributs de ce record sont-ils l'objet du test (the point of the test) ?
├─ NON — c'est un record générique (generic record)
│     -> accesseur semé (T13). Coût nul. C'est le défaut du projet.
│     -> si le setup générique manque aux seeds : db/seeds/cases/ (voir plus bas)
└─ OUI
   ├─ stable sur tout le groupe   -> let_it_be (T08), FactoryBot conservé
   └─ muté / différent par example -> laisser le `create` en place, ne rien faire
```

**Deuxième dimension, à ne pas confondre avec la première : le rayon d'explosion.**
Elle ne dit pas quelle technique est correcte, elle dit ce qui peut partir en PR autonome.

| | Portée du changement | Si c'est faux |
|---|---|---|
| `let_it_be` | le fichier spec | un fichier rouge |
| consommer un accesseur semé | le fichier spec, **plus** la seed-safety (cf. plus bas) | un fichier rouge, ou des assertions faussées silencieusement |
| **ajouter/modifier `db/seeds/`** | **toute la suite** | potentiellement des centaines de fichiers |

Conséquence pratique : un lot « T08 » se relit fichier par fichier ; un lot qui touche
`db/seeds/` est un changement partagé qui se discute avant d'être écrit. **Ne jamais
ajouter un `cases/` de sa propre initiative dans un run autonome** — le remonter dans
le rapport et laisser un humain trancher. On cherche du générique réutilisable, pas un
seed par spec.

| ID | Technique | Description | Signal de détection | Risque | Gain typique |
|---|---|---|---|---|---|
| **T13** | **create → seed Oaken** | **Levier #1 depuis la migration Oaken. À tenter AVANT T08** (cf. arbre de décision ci-dessus). Remplacer un `create(:procedure)` / `create(:dossier)` / `create(:administrateur)` générique par l'accesseur semé équivalent (`procedures.individual`, `dossiers.en_construction`, `administrateurs.default`…). Le record existe déjà : coût de setup **nul**, pas seulement mutualisé. Si plusieurs specs ont besoin du même setup non-trivial absent des seeds, ajouter un fichier dans `db/seeds/cases/` et le charger par groupe avec `before_all { seed "cases/xxx" }`. | `create(:` sur un modèle qui a un accesseur semé (voir catalogue ci-dessous), **sans attribut spécifique** — c'est un *generic record* au sens d'`AGENTS.md`. À l'inverse : garder FactoryBot pour les *records whose attributes are the point of the test*. Cf. l'arbre de décision ci-dessus. | Le record semé est partagé : toute mutation doit rester dans la transaction de l'example (c'est le cas par défaut). ⚠️ Ne jamais utiliser un accesseur dont le modèle est vidé par `empty_seeds` dans le même groupe. | **30-70%** |
| T01 | create → build / build_stubbed | Remplacer `create(:dossier)` par `build(:dossier)` ou `build_stubbed(:dossier)` quand le test ne fait pas de query DB. **2 `build_stubbed` dans le projet** (relevé 2026-09-09) — la technique est quasi vierge. | `create(:` dans un test qui ne fait ni query, ni reload, ni `find`. Model specs de validations, méthodes pures. | Faible si bien ciblé — le test casse immédiatement si la conversion est incorrecte. ⚠️ La factory `:dossier` force un `create(:procedure)` dans son transient. | **5-15%** |
| T02 | includes/preload | Corriger les N+1 queries dans le code applicatif détectés pendant les tests. | `SELECT` répétés dans les logs de test. Utiliser `Prosopite` ou `Bullet`. | Modifie le code de prod — nécessite review. | **Moyen** |
| T03 | stub API externe | Mocker les appels réseau (HTTP, SMTP, S3) avec WebMock/VCR. | `Net::HTTP`, `Faraday` appelés dans le code sous test. | Cassettes VCR périmées qui masquent des changements d'API. | **Fort** |
| T04 | réduire setup inutile | Supprimer les `create`/`let!` non nécessaires au test. | `let!(:foo)` dont le nom n'apparaît pas dans le bloc `it`. Fichiers avec 10+ `let!` (ex: `expired_dossiers_deletion_service_spec.rb` = 57 `let!`). | Un side-effect implicite existe parfois (callback qui crée un record nécessaire). | **Moyen** |
| T06 | supprimer tests dupliqués | Supprimer les tests qui vérifient le même comportement. | Deux `it` avec la même assertion ou le même `expect`. | Supprimer un test qui couvrait un edge case subtil. | **Moyen** |
| T08 | let_it_be / before_all | **À tenter APRÈS T13** (cf. arbre de décision). Remplacer `let(:procedure) { create(:procedure) }` par `let_it_be(:procedure)` dans les describe qui ne mutent pas l'objet. Gem requise dans `rails_helper.rb`, **103 usages dans 16 fichiers seulement** (relevé 2026-09-09) : le levier est très largement inexploité. Réserver aux records dont les attributs sont l'objet du test — sinon c'est T13. Chaque `let_it_be(:dossier)` économise (N-1) créations × 15-25 INSERTs. | `let(:procedure) { create(:procedure` — des centaines d'occurrences. `let(:dossier) { create(:dossier` idem. | Si un test mute l'objet → pollution inter-tests. Utiliser `let_it_be(..., reload: true)` ou `refind: true`. | **15-40%** |
| T09 | aggregate_failures | Regrouper plusieurs assertions dans un seul `it` avec `aggregate_failures` — réduit le nombre de setups répétés. | Un `describe` avec 5+ `it` qui ont le même `before` et testent des attributs différents du même objet. | Le premier échec ne bloque pas les suivants (atténué par `aggregate_failures` qui les montre tous). | **Moyen** |
| T10 | let! → let (lazy) | Convertir les `let!` en `let` (lazy) quand le record n'est pas utilisé par tous les examples du group. **1912 `let!` dans le projet** (relevé 2026-09-09). | `let!(:x)` non référencé dans certains `it`. Fichiers lourds : `dossier_filter_service_spec.rb` (76 `let!`). | Si un `let!` existe pour un side effect (création en DB pour un scope), le retirer casse le test. Vérifier au cas par cas. | **10-20%** |
| T11 | factory_default / create_default | Définir une procedure par défaut avec `create_default(:procedure)` pour éviter que chaque `create(:dossier)` recrée une procedure. Élimine la cascade. ⚠️ **Non actionnable en l'état** : `require 'test_prof/recipes/rspec/factory_default'` est **absent** de `spec_helper.rb` comme de `rails_helper.rb`, et il y a **0 `create_default`** dans le projet (relevé 2026-09-09). Le require est un prérequis à faire valider séparément — ne pas l'ajouter au détour d'une PR d'optimisation. | Context avec 5+ dossiers pour la même procedure — chaque dossier recrée sa propre procedure. | Si deux examples ont besoin de procedures différentes dans le même context, ça casse. | **20-30%** |
| T12 | split fichier spec | Découper un fichier spec monolithique en fichiers thématiques. **Deux axes** : (a) **par concern** — un `describe '#method'` qui teste une méthode définie dans un concern inclus par le modèle appartient à `spec/models/concerns/<concern>_spec.rb`, souvent déjà existant ; (b) **par thème/action** quand il n'y a pas de concern (specs de contrôleur : un fichier par groupe d'actions). Le gain immédiat est le parallélisme CI, mais **le vrai objectif est de rendre le fichier optimisable** : au-delà de ~1500 lignes, ni un humain ni un agent ne tient le setup en tête pour arbitrer générique/objet-du-test, et T13 comme T08 deviennent inapplicables. Faire T12 **avant** de tenter les autres techniques sur un gros fichier. Duplication explicite des déclarations (voir risque) — **pas de shared_context ni shared_example**. | Fichier spec > 1000 lignes ou > 100 examples. Échec répété en `context_limit` sur ce fichier. `describe` indépendants avec des setups distincts. | Un bloc déplacé **perd tout le scope déclaré au-dessus de lui**. Reporter dans le fichier de destination — et conserver dans la source si elle en a encore besoin — **`let` / `let_it_be` / `subject`, `before`, `include`, ET les déclarations de seeds : `before_all { seed "cases/xxx" }` et `empty_seeds Model`**. Ces deux dernières sont le piège : elles ne ressemblent pas à une dépendance, un grep sur les `let` ne les voit pas, et leur oubli ne casse que les quelques examples qui touchent le seed concerné. Vécu : deux specs SVA/SVR rouges après un déplacement, `procedures.sva` levant `NoMethodError` sur l'accesseur. Scoper le `before_all` au `describe` qui en a besoin plutôt qu'au fichier entier. | **10-20%** (via parallélisme) — et surtout : débloque T13/T08 |

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
- ⚠️ **`before_all { seed "cases/xxx" }` et `empty_seeds` sont des dépendances de scope**, au même
  titre qu'un `let`. Tout bloc déplacé (T12) ou tout `describe` extrait doit les emporter, et la
  source doit les garder si elle en a encore besoin. Un grep sur les `let` ne les voit pas, et leur
  oubli ne casse que les examples qui touchent effectivement le seed — l'échec est local et tardif,
  pas immédiat. Cf. T12.

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

### AL-3 (2026-09-03 17:37)

Dans patterns.md, ajouter une règle : lors du calcul du répertoire de travail pour une spec, ne jamais reconstruire le chemin à partir du hash du batch. Utiliser le working directory réel (cwd) ou le path complet du fichier spec passé en paramètre. Si le nom du répertoire contient un préfixe comme 'auto-test-optimization-batch-XXXX', conserver le path complet sans tronquer le préfixe.

### AL-4 (2026-09-03 18:50)

Dans patterns.md (ou dans le prompt du skill), ajouter une note que le skill requiert l'autorisation préalable des commandes Bash pour l'exécution de specs : « Le skill test-optimization a besoin d'exécuter `bundle exec rspec` / `bundle exec spring rspec` via Bash. Assurez-vous que ces commandes sont pré-autorisées dans les permissions du projet (settings.json) avant de lancer le skill, sinon l'agent ne pourra pas mesurer les temps d'exécution et le workflow échouera. »

### AL-5 (2026-09-04 14:20)

Dans patterns.md, ajouter une règle pour les runs autonomes :

### Autonomous mode – permission prompts
When running as a background subagent (no interactive approval), avoid any `bundle exec rspec` command wrapped in `TIMED=1` or multi-operation constructs (`for loop`, `&&` chains) that trigger 'requires approval' permission prompts. Instead:
- For timing measurements, use a single `TIMED=1 bundle exec rspec <file>` without a loop wrapper.
- If the tool still blocks it, fall back to a plain `bundle exec rspec <file>` (no TIMED prefix) and skip timing.
- Never use compound commands (`for i in ...`, `cmd1 && cmd2`) for rspec invocations in autonomous mode.
