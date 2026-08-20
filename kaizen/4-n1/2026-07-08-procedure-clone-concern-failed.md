---
name: 2026-07-08-procedure-clone-concern-failed
description: n1-query-fix context overflow on procedure_clone_concern.rb — 100129 tokens > 100000 limit, 78 turns, $4.97
metadata:
  type: kaizen
status: traité
date_synth: 2026-08-20
---

# n1-query-fix failed: procedure_clone_concern.rb

**Date**: 2026-07-08
**Skill**: n1-query-fix
**File**: `app/models/concerns/procedure_clone_concern.rb`
**Worktree**: `auto-n1-query-fix-m-c-procedure_clone_concern`
**Log**: `tmp/logs/2026-07-08-n1-query-fix-procedure-clone-concern.log`
**Failure reason**: ClaudeError — context overflow (100129 > 100000 tokens)
**Duration**: 2128s (35 min), **Cost**: $4.97
**Turns**: 78

## Ce qui s'est passé

1. **Bootstrap OK** : `bundle install` réussi, spec trouvé, Prosopite setup script exécuté
2. **Permission denied** : `tee tmp/prosopite-scan.log` refusé (Bash multi-op)
3. **Prosopite hook cassé** : `config.before(:each)` invalide — `:each` pas un hook transaction valide (types attendus: `begin`, `rollback`)
4. **Edit multi-match** : `replace_all` pas utilisé, 3 occurrences du même pattern
5. **4 tentatives de scan** avec grep `'N+1 queries detected'` → 0 hits (spec pas lancée correctement)
6. **Write sans read** : `File has not been read yet` sur un fichier
7. **N+1 massif détecté** : une fois Prosopite fonctionnel, le spec `API::V2::GraphqlController demarche.dossiers` a explosé avec des dizaines de N+1 sur active_storage_blobs, flipper, procedures, commentaires, GraphQL `Sources::Association`, procedure_path_concern, etc.
8. **Context overflow** : à 100129 tokens (vs 100000 max deepseek-v4-flash), session terminée en erreur API

## Bien passé

- Le skill a trouvé la spec, installé les gems, setup Prosopite
- Une fois Prosopite actif, les N+1 sont bien détectés
- Le diagnostic de l'erreur spec_helper était correct (hook type)

## Mal passé

- **Context window overflow** : 100129 > 100000, 129 tokens de trop — le skill est mort à cause du volume de N+1 output combiné aux 78 turns de setup
- **Prosopite setup fragile** : le script a ajouté un hook `before(:each)` qui n'est pas valide pour le contexte transactionnel de ce projet (Rails diff)
- **N+1 output massif** : le spec GraphQL `demarche.dossiers` charge tout l'univers — des dizaines de N+1 simultanés, contexte saturé instantanément
- **$4.97 pour un échec** : 5.4M tokens cache read + 24k output, aucun fix produit

## Appris

1. **Le spec `demarche.dossiers` est un piège** : il déclenche des N+1 sur trop de models à la fois (flipper, active_storage, procedure_path, commentaires, GraphQL batch). Le skill ne peut pas les traiter tous dans une seule session — le volume explose le contexte.
2. **deepseek-v4-flash (100k)** est trop juste pour ce pattern : entre le code du projet, le setup Prosopite, et le output des N+1, le seuil est atteint rapidement.
3. **Prosopite hook `:each` invalide** : le script de setup du skill ne gère pas les projets où `config.before(:each)` n'est pas supporté dans spec_helper — le hook transactionnel attend `begin`/`rollback`.

## Permissions bloquantes

- `tee tmp/prosopite-scan.log` (Bash multi-op) — 1 denial. Ajouter `tee` à la allowlist dans `.claude/settings.json` du projet cible.

## Actions

- **Ajouter un check amont dans n1-query-fix** : avant de lancer le spec complet, vérifier si le spec cible est un GraphQL controller test qui charge beaucoup d'associations. Si oui, soit (a) limiter le scope du test avec `--tag focus` et un subset de N+1, soit (b) échouer rapidement avec un message explicite.
- **Remplacer deepseek-v4-flash par un model avec plus de contexte** (sonnet-5 200k) dans la config du skill pour les fichiers à forte densité de N+1.
- **Hardener le Prosopite setup** : le script doit détecter si `config.before(:each)` est supporté dans spec_helper, et utiliser `config.before(:begin)`/`config.after(:rollback)` si `:each` n'est pas valide.
- **Couper le output N+1** : au lieu d'afficher les N+1 bruts, les agréger par call stack et ne garder que les 3-5 premiers patterns pour économiser le contexte.

[[2026-06-24-attestation-template-v2s-controller-failed]] — même pattern (context overflow sur deepseek-v4-flash avec N+1 massif)
