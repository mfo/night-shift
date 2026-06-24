# Checklist Supplémentaire : Feature Spec (Stage 0)

Le workflow principal est dans `SKILL.md`. Cette checklist ne contient que les commandes utiles, pièges et métriques.

---

## Commandes Utiles

### Détection Call-Sites (Breaking Changes)
```bash
grep -r "JobName.perform" app/ lib/ spec/
grep -r "ServiceName.new" app/ lib/ spec/
grep -r "method_name" app/ lib/ spec/
```

### Détection Duplications (Query Object)
```bash
grep -r "pattern_métier" app/ | wc -l
```

### Détection Tests Existants
```bash
find spec -name "*nom_fichier*_spec.rb"
find spec/models -name "*.rb"
find spec/controllers -name "*.rb"
find spec/system -name "*.rb"
```

### Vérification Index DB
```bash
grep -r "add_index.*unique: true" db/migrate/
cat db/schema.rb | grep -A3 "unique: true"
```

---

## Pièges Critiques

### 1. Patch au lieu de Spec Globale
Bug architectural découvert → STOP et proposer spec globale, pas patcher.

### 2. Validation Rails Sans Index DB
`validates :x, uniqueness: { scope: [...] }` sans index → tests passent (SQLite), prod crashe (PG).

### 3. Trade-Offs Non Documentés
N+1 détectée sans rationale → documenter Contexte + Options + Choix + Rationale.

---

## Métriques de Succès

- [ ] 16 sections complètes
- [ ] Review 3-amigos effectuée (si sizing Medium/Large)
- [ ] User a approuvé architecture
- [ ] Score confiance >= 7/10

