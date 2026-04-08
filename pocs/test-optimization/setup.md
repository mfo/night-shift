# POC 2 : Optimisation Tests Lents - Setup

**Date :** 2026-03-15
**Spec :** `pocs/test-optimization/spec.md` (source de vérité)
**Projet cible :** demarches-simplifiees.fr

---

## Créer un worktree

```bash
cd ~/dev/demarches-simplifiees.fr
git worktree add -b perf/<nom-fichier-spec> ../demarches-simplifiees.fr-perf-<nom> main
```

## Installer le hook DB

```bash
~/dev/night-shift/hooks/worktree/install.sh ~/dev/demarches-simplifiees.fr-perf-<nom>
```

Le hook crée automatiquement une DB PostgreSQL isolée pour le worktree.

## Lancer l'agent

```bash
cd ~/dev/demarches-simplifiees.fr-perf-<nom>
# Lancer Claude Code avec le skill test-optimization
# Input : chemin du fichier spec à optimiser
```

## Cleanup

```bash
cd ~/dev/demarches-simplifiees.fr
git worktree remove ../demarches-simplifiees.fr-perf-<nom>
# La DB est supprimable avec : dropdb -U tps_test -h localhost tps_test_perf_<nom>
```

---

## Références

- **Spec complète** : `pocs/test-optimization/spec.md`
- **Skill agent** : `.claude/skills/test-optimization/SKILL.md`
- **Inventaire** : `pocs/test-optimization/slow-tests-inventory.md`
- **Techniques** : `.claude/skills/test-optimization/patterns.md`
- **Template kaizen** : `.claude/skills/test-optimization/template.md`
- **Hook worktree** : `hooks/worktree/`
