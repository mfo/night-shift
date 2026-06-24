# Checklist Supplémentaire : Feature Implementation (Stage 2)

Le workflow principal est dans `SKILL.md`. Cette checklist ne contient que les commandes utiles, pièges et métriques.

---

## Commandes Utiles

### Tests
```bash
bundle exec rspec                          # Suite complète
bundle exec rspec spec/models/             # Par type
bundle exec rspec spec/models/model_spec.rb:42  # Ligne spécifique
COVERAGE=true bundle exec rspec            # Avec coverage
```

### Qualité Code
```bash
bundle exec rubocop                        # Vérifier
bundle exec rubocop -a                     # Auto-correct safe
```

### Debug
```bash
rails console
tail -f log/development.log
rails dbconsole
```

---

## Pièges Critiques (avec exemples)

### 1. Boolean Combinations pour State
```ruby
# BAD
return if record&.persisted? && !record&.failed?
# GOOD
return if record&.state&.in?(['queued', 'running'])
```

### 2. Memoization dans Actions Changeant État
```ruby
# BAD — valeur stale après update
@current_schema_hash ||= calculate(draft.schema)
# GOOD
calculate_hash(draft.reload.schema)
```

### 3. Tests Sans Setup Context
```ruby
# BAD — before_action redirige sans context
get :action, params: { tunnel_id: 'abc123' }
# GOOD — setup complet
before { create(:record, tunnel_id:, state: 'accepted') }
```

### 4. Validation Rails Sans Index DB
Tests passent (SQLite permissive), prod crashe (PG strict).
```bash
grep "validates.*uniqueness" app/models/
grep -r "add_index.*unique: true" db/migrate/
```

---

## Métriques de Succès

- [ ] Tous commits tests verts (sauf exception documentée)
- [ ] Rubocop clean (0 offenses)
- [ ] Coverage >= 80%
- [ ] Patterns critiques appliqués
- [ ] Aucun blocage > 30min non signalé

