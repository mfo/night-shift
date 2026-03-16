# Workflow

## Utiliser un skill

Les skills sont des slash commands. Lancer Claude Code dans le bon contexte et invoquer le skill :

```bash
# Migration HAML → ERB (dans le worktree du projet cible)
/haml-migration app/views/path/to/file.html.haml

# Optimisation d'un fichier spec (dans un worktree isolé)
/test-optimization spec/models/dossier_spec.rb

# Investigation bug
/bugfix <description ou lien Sentry>

# Feature complète (4 phases)
/feature-spec    # Phase 0 : spec
/feature-plan    # Phase 1 : plan de commits
/feature-implementation  # Phase 2 : code
/feature-review  # Phase 3 : review + cleanup
```

Chaque skill est autonome : il contient son workflow, ses règles, et ses patterns.

## Kaizen — boucle d'amélioration

Deux modes :

### `/kaizen write` — après une session

L'agent écrit un post-it dans `kaizen/<catégorie>/` avec ce qui s'est passé, ce qu'il a appris, et les actions suggérées. C'est un livrable passif — on ne modifie rien.

### `/kaizen synth` — le matin

On consomme les kaizen accumulés et on améliore les skills :

1. Scanner les kaizen non traités
2. Choisir lesquels traiter
3. Pour chaque kaizen : comparer avec le skill actuel, proposer des modifications
4. Valider chaque proposition avant d'écrire

Rien n'est écrit sans validation.

## Review transversale

```bash
# Review 3 Amigos (PM + UX + Dev) sur n'importe quel input
/review-3-amigos <spec, plan, ou PR diff>
```
