# Checklist Supplémentaire : Feature Review (Stage 3)

Le workflow principal est dans `SKILL.md`. Cette checklist ne contient que les commandes utiles, pièges et métriques.

---

## Commandes Utiles

### Détection Dead Code
```bash
grep -r "OldClassName" app/ spec/
bundle exec rubocop --only Lint/UselessAssignment
```

### N+1 Queries
```bash
BULLET=true rails server
# Tester feature, vérifier logs bullet
```

### Validation Uniqueness
```bash
grep "validates.*uniqueness" app/models/
grep -r "add_index.*unique: true" db/migrate/
```

### Rubocop
```bash
bundle exec rubocop
bundle exec rubocop -a          # Auto-correct safe
bundle exec rubocop -A          # Auto-correct unsafe (vérifier)
```

### Git Absorb
```bash
git add -p                      # Stage par hunk
git absorb                      # Intègre dans commits existants
git rebase -i HEAD~N --autosquash  # Si fragments restants
```

---

## Pièges Critiques

### 1. Skip Bloquants
Merger avec dead code ou tests cassés → production crash.

### 2. Fixes Sans Tests
Corriger sans vérifier → nouvelle régression.

### 3. Commits "fix typo" Multiples
Historique pollué → utiliser git absorb.

---

## Métriques de Succès

- [ ] Document review créé
- [ ] Bloquants fixés (rouge = 0)
- [ ] Importants fixés ou backlog documenté
- [ ] Git absorb effectué
- [ ] PR mergeable

