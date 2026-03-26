# Patterns Critiques Découverts

### Pattern 1 : Rate Limiting API Externes

**Symptômes :** Faraday::TooManyRequestsError, erreurs en vagues

**Root cause typique :** Job cron enqueue des centaines de jobs → Sidekiq traite en parallèle → API externe a des quotas stricts

**Solutions classiques :**
1. Désactiver le job cron (si non critique)
2. Queue dédiée + throttling + retry avec backoff
3. Circuit breaker + Redis rate limiter

### Pattern 2 : Jobs Cron avec Enqueue Massif

**Anti-pattern :**
```ruby
Procedure.find_each do |procedure|
  MyJob.perform_later(procedure)  # Enqueue immédiat
end
```

**Solution :**
```ruby
Procedure.find_each.with_index do |procedure, idx|
  MyJob.set(wait: idx * 15.seconds).perform_later(procedure)
end
```

### Pattern 3 : Rescue Global dans un Job = Piège

**Symptômes :** Job qui échoue silencieusement, pas de retry, erreur avalée

**Anti-pattern :**
```ruby
def perform(blob)
  process(blob)
rescue Vips::Error => e  # Attrape TOUTES les erreurs vips, même celles qu'on veut retry
  log_error(e)
end
```

**Solution :** Exception custom qui hérite de `StandardError` (pas de la lib error) :
```ruby
class MyService::Error < StandardError; end

# Dans le service : raise MyService::Error wrapping l'erreur originale
# Dans le job : retry_on MyService::Error, attempts: 3
# Le rescue Vips::Error ne catch pas MyService::Error → retry fonctionne
```

**Applicable à :** Tout job avec `rescue LibError` global qui risque d'avaler des erreurs spécifiques.

### Pattern 4 : Rails STI et polymorphic_name

**Symptômes :** Query sur `record_type` qui ne retourne rien

**Piège :** `active_storage_attachments.record_type` stocke le **polymorphic_name** (base class STI), pas la sous-classe.
```ruby
# ❌ Ne trouve rien
ActiveStorage::Attachment.where(record_type: "Champs::TitreIdentiteChamp")

# ✅ Correct
ActiveStorage::Attachment
  .joins("JOIN champs ON champs.id = active_storage_attachments.record_id")
  .where(record_type: "Champ")
  .where(champs: { type: "Champs::TitreIdentiteChamp" })
```

**Applicable à :** Toute query sur `active_storage_attachments` ou tables polymorphiques avec STI.

### Pattern 5 : Factories pour modèles Rails internes

**Piège :** `create(:blob)` → `KeyError: Factory not registered`. Pas de factory FactoryBot pour `ActiveStorage::Blob`, `ActiveStorage::Attachment`, etc.

**Solution :** Utiliser les associations réelles :
```ruby
# ❌ create(:blob)
# ✅ Créer un objet parent avec pièce jointe → accéder au blob via l'association
dossier = create(:dossier, :with_titre_identite)
blob = dossier.champs.first.piece_justificative_file.blob
```

### Pattern 6 : Suppression > Désactivation

**SUPPRIMER si :** Business confirme non-critique + probabilité réactivation < 10%
**DÉSACTIVER si :** Feature flag A/B testing + rollback potentiel < 1 mois

→ Demander à l'utilisateur en cas de doute.

### Pattern 7 : Régression par perte de guard

**Symptômes :** `NoMethodError` sur nil, `UrlGenerationError` sur id: nil — sur du code qui "marchait avant".

**Root cause typique :** Un guard défensif (`.persisted?`, `.blank?`, `&.`) existait dans un ancien composant. Lors d'une réécriture/migration/unification, le guard a été oublié.

**Investigation :**
1. Identifier le composant actuel qui crashe
2. Remonter l'historique git pour trouver le composant précédent (V-1)
3. **Ne pas s'arrêter là** — remonter 2-3 générations (V-2, V-3) pour retrouver le guard original
4. Comparer les guards défensifs entre l'ancienne et la nouvelle version

**Applicable à :** Toute migration de composant, réécriture, ou unification de code dupliqué.

### Pattern 8 : Préférer les tests composants aux tests controller pour les bugs de rendu

**Symptôme :** Bug visible uniquement dans le HTML rendu (nil dans un template, URL cassée).

**Piège :** Les controller specs sans `render_views` ne testent pas le rendu → le bug est invisible. Les controller specs avec simulation de flow complet (direct upload, etc.) sont lourdes et fragiles.

**Solution :** Tester directement le composant/partial en isolation :
```ruby
# ✅ Test composant ciblé
render_inline(MyComponent.new(object_with_nil))
expect(page).to have_no_css(".broken-link")

# ❌ Test controller lourd
post :create, params: { ... complex setup ... }
```

**Applicable à :** Tout bug de rendu dans un ViewComponent ou un partial.

---

## Règles d'Investigation

### Historique git : remonter en profondeur

Lors de l'analyse git d'un bug, **ne pas s'arrêter au commit précédent**. Remonter au moins 2-3 générations de refactoring pour retrouver les guards/comportements défensifs originaux. Toujours chercher "comment c'était avant la réécriture".
