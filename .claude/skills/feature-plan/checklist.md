# Checklist Supplémentaire : Feature Plan (Stage 1)

Le workflow principal est dans `SKILL.md`. Cette checklist ne contient que les commandes utiles, pièges et métriques.

---

## Commandes Utiles

### Estimer Nombre Fichiers Impactés
```bash
grep -r "old_route_name" app/views/ app/components/
grep -r "JobName.perform" app/ lib/ spec/
find spec -name "*nom*_spec.rb"
```

### Vérifier Ordre Dépendances
```bash
grep -r "NewQueryName" app/
# Si résultats avant commit création Query → ordre incorrect
```

---

## Pièges Critiques

### 1. Commits Trop Larges
> 5 fichiers modifiés → découper (1 concept = 1 commit).

### 2. Tests Séparés du Code
Commits 4-14 code, commits 15-16 tests → interleave code + specs à chaque commit.

### 3. Breaking Changes Éparpillés
Change signature commit 5, fix call-site commit 12 → grouper en bloc.

### 4. Ordre Illogique
UI avant DB → respecter dépendances (DB → Infra → Features → UI → Tests).

### 5. > 20 Commits
Fusionner commits similaires ou revoir découpage feature.

---

## Métriques de Succès

- [ ] Commits atomiques (< 20)
- [ ] Phases logiques (7 phases)
- [ ] Breaking changes isolés en blocs
- [ ] Tests exécutables après chaque commit
- [ ] User a validé structure

