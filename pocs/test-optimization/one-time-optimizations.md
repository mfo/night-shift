# Optimisations one-shot — hors scope agent

Changements de config à appliquer une seule fois sur le projet cible. Pas par fichier.

**Projet cible** : demarches-simplifiees.fr (Rails 7.2, Ruby 3.4, PostgreSQL 17)

---

## Config & runtime

| ID | Technique | Description | Déjà en place ? | Gain typique |
|---|---|---|---|---|
| G01 | YJIT en local | `RUBY_YJIT_ENABLE=1` dans `.env` local. Ruby 3.4.5 + YJIT = 15-25% CPU en moins. | En CI oui, en local non | **5-15%** |
| G02 | `--profile` hors `.rspec` | Déplacer `--profile` de `.rspec` dans `.rspec-local` (gitignored). Overhead de profiling sur chaque run. | Non | **1-3%** |
| G03 | `log_level: :fatal` en local | Appliquer `config.log_level = :fatal` aussi en local (pas seulement CI). | CI oui, local non | **3-8%** |
| G04 | `synchronous_commit = off` | Ajouter `synchronous_commit: 'off'` dans `database.yml` section test. Chaque INSERT/COMMIT ~10x plus rapide. | Non | **5-10%** |
| G08 | `DISABLE_SPRING=1` en local | Spring actif en local mais cause du file-watching overhead. Avec Ruby 3.4 + bootsnap, le cold boot est rapide. | CI oui, local non | **2-5%** |
| G10 | Disable verbose SQL query logs | `config.active_record.verbose_query_logs = false` et `config.active_record.query_log_tags_enabled = false` en test. Plus gros gain de l'article Evil Martians/Whop (2x speedup). | À vérifier | **Fort** |

## Factories & fixtures

| ID | Technique | Description | Déjà en place ? | Gain typique |
|---|---|---|---|---|
| G05 | Utiliser `:simple_procedure` | Le trait `:simple_procedure` existe déjà (procedure published pour individus + 1 champ texte). Privilégier ce trait au lieu de la factory par défaut quand le test n'a pas besoin d'une procedure complète. | Trait existant, sous-utilisé | **15-25%** |
| G09 | Fixtures Rails pour les acteurs | Utiliser les fixtures YAML existantes (`spec/fixtures/administrateurs.yml`, `instructeurs.yml`, `users.yml`) au lieu de `create(:user)` / `create(:instructeur)` / `create(:administrateur)`. Les fixtures sont chargées une fois en DB avant la suite, pas recréées à chaque test. | Fixtures présentes, sous-utilisées | **5-15%** |

## CI

| ID | Technique | Description | Déjà en place ? | Gain typique |
|---|---|---|---|---|
| G06 | Augmenter CI split | Passer de 6 à 8 workers unit tests dans `.github/workflows/ci.yml`. | Non (6 actuellement) | **~25% wall-clock** |

## Diagnostic

| ID | Technique | Description | Déjà en place ? | Gain typique |
|---|---|---|---|---|
| G07 | Diagnostic test-prof | Lancer `FPROF=1`, `TAG_PROF=type`, `EVENT_PROF=factory.create` pour cartographier les coûts. test-prof déjà installé. | Non utilisé | N/A |
| G11 | StackProf sampling | `TEST_STACK_PROF=1 SAMPLE=200 bundle exec rspec spec` — profiling CPU pour identifier les bottlenecks (I/O, logging, etc.). test-prof l'intègre. | Non utilisé | N/A |
| G12 | FactoryDefault profiler | `FPROF=1 FACTORY_DEFAULT_PROF=1` — identifie les associations créées implicitement par les factories. Complète G07. | Non utilisé | N/A |

---

**Source** : catalogue interne + [Evil Martians — The Whop Chop](https://evilmartians.com/chronicles/the-whop-chop-how-we-cut-a-rails-test-suite-and-ci-time-in-half)
