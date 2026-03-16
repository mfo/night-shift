# Quick Start

## Lancer un skill

```bash
# 1. Se placer dans le projet cible (ou un worktree isolé)
cd /Users/mfo/dev/demarches-simplifiees.fr

# 2. Lancer Claude Code
claude

# 3. Invoquer le skill
/haml-migration app/views/path/to/file.html.haml
```

Skills disponibles : voir `WORKFLOW.md`.

## Après une session

```bash
# L'agent écrit un kaizen automatiquement
/kaizen write
```

## Améliorer les skills

```bash
# Consommer les kaizen et proposer des améliorations
/kaizen synth
```

## En savoir plus

| Fichier | Contenu |
|---|---|
| `README.md` | Vision et approche |
| `STRUCTURE.md` | Architecture du projet |
| `WORKFLOW.md` | Comment utiliser les skills |
| `pocs/` | Data projet par POC |
