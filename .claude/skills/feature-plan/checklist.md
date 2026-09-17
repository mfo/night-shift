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

### 6. Couche « Tests »
Faire de la phase 5 une couche produit une PR de specs sans code, et laisse les couches 1-4 sans
leurs tests. C'est le piège #2 érigé en structure. Chaque couche embarque ses propres specs.

### 7. Une Phase = Une Couche
Mapper mécaniquement les 7 phases sur les couches donne un découpage horizontal : chaque PR est plus
petite mais aucune n'est compréhensible seule. Les 7 phases sont un **ordre**, pas un gabarit.
Le critère de couche est le test de la phrase (SKILL.md Étape 2-bis).

---

## Métriques de Succès

- [ ] Commits atomiques (< 20)
- [ ] Phases logiques (7 phases)
- [ ] Couches : 2-5 (ou 1 = pas de pile), chacune avec sa phrase « ce que le reviewer peut vérifier ici »
- [ ] Aucune couche « Tests » ; chaque couche embarque ses specs
- [ ] Breaking changes isolés en blocs, jamais à cheval sur deux couches
- [ ] Tests exécutables après chaque commit
- [ ] User a validé structure

