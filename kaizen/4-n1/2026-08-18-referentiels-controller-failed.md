---
name: 2026-08-18-referentiels-controller-failed
description: n1-query-fix failed on referentiels_controller.rb — context overflow after 109 turns, $6.01
metadata:
  type: kaizen
---

# n1-query-fix failed: `Administrateurs::ReferentielsController`

**Session**: `app/controllers/administrateurs/referentiels_controller.rb`
**Reason**: `claude_error` (API Error 400: Prompt 100064 > 100000 tokens)
**Cost**: $6.01 — 109 turns, 21k output tokens
**Duration**: ~6 min API, 31 min wall-clock

## Ce qui s'est passé

1. **Etape 0** — Setup Prosopite → OK (bundle install, 354 gems)
2. **Etape 1** — Lecture contexte → score 8.8, `active_storage_attachments` N+1 patterns sur 4 endpoints (#create, #update, #update_mapping_type_de_champ, #update_prefill_and_display_type_de_champ)
3. **Spec run** — `bundle exec rspec` → **38 exemples, 4 failures** (tous `ActiveRecord::RecordInvalid` sur `:with_autocomplete_response` trait — URL validation)
4. **Permission denied** — `tee /dev/stderr 2>&1` rejeté → retry + approche alternative (`--out tmp/rspec_output.txt`)
5. **Prosopite scan** — log vide (1 ligne en-tête), 0 N+1 détecté
6. **Analyse code** — lecture controller, vues, modèles pour trouver N+1 visuellement → rien trouvé
7. **Context window overflow** — 100064 tokens > 100000, session terminée, aucun fix produit

## Bien passé

- Setup Prosopite a réussi sans intervention
- Contexte skill (`score 8.8`) bien fourni par le scanner
- Les 4 failures ont été identifiées comme préexistantes (validation `URL du référentiel`)

## Mal passé

- **Permission bloquante** : `tee /dev/stderr` rejeté → retry + 2e tentative rspec, ~15 turns de friction
- **Spec failures préexistantes** : les 4 failures `ActiveRecord::RecordInvalid` sur `:with_autocomplete_response` ont forcé la skill à analyser les failures au lieu du N+1
- **Prosopite 0 détection** : pas de N+1 détecté car `render_views` absent du spec + fixtures trop pauvres (1 record)
- **Context window overflow** : après 109 turns, le prompt a dépassé 100k tokens. La session a continué à accumuler du contexte sans jamais produire de fix, jusqu'à saturation
- **6 API retries** : plusieurs commandes `grep`/`cat` sans output ont causé des retries, consumant des turns

## Appris

- **Permission `tee` est un pattern fragile** dans les skills — le pipe vers `/dev/stderr` est systématiquement rejeté. Le skill n1-query-fix utilise `tee /dev/stderr` dans plusieurs étapes. Solution : utiliser `--out tmp/rspec_output.txt` ou `2>&1` sans `tee`.
- **render_views absent = Prosopite aveugle** : si les specs controller n'utilisent pas `render_views`, les templates ne sont pas exécutés → pas de N+1 détecté par Prosopite. Le scanner signale un score basé sur le code, pas sur le run.
- **Spec failures préexistantes bloquent le diagnostic N+1** : le skill devrait détecter que les failures ne sont pas des N+1 et les ignorer, pas les analyser en profondeur.
- **Context window overflow est le kill switch** : 109 turns × lecture/écriture de fichiers longs → saturation. Le skill n'a pas de mécanisme pour détecter la proximité du limite ou faire un early exit.

## Permissions bloquantes

1. `tee /dev/stderr 2>&1` — rejeté à ligne 468, a causé retry + perte de temps

## Actions

- [x] Kaizen écrit
- [ ] Modifier le skill n1-query-fix pour utiliser `--out` au lieu de `tee /dev/stderr` dans les commandes rspec
- [ ] Ajouter une détection early-exit dans le skill : si 0 N+1 détecté après 3 tentatives et que les failures sont des validation errors, skip
- [ ] Vérifier si `render_views` peut être ajouté au spec ou si le scanner doit signaler ce risque
- [ ] Considérer un mécanisme de compactage/truncate du contexte pour éviter overflow sur sessions longues
