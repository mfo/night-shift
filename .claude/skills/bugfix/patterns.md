# Patterns Critiques Découverts

### Pattern 1 : Rate Limiting + Enqueue Massif

**Symptômes :** Faraday::TooManyRequestsError, erreurs en vagues

**Piège :** Job cron enqueue en masse → Sidekiq parallélise → API externe saturée.
**Solution :** Stagger les jobs :
```ruby
Procedure.find_each.with_index do |procedure, idx|
  MyJob.set(wait: idx * 15.seconds).perform_later(procedure)
end
```
Alternatives : queue dédiée + throttling, circuit breaker + Redis rate limiter.

### Pattern 2 : Rescue Global dans un Job = Piège

**Symptôme :** Job échoue silencieusement, `rescue LibError` avale l'erreur, pas de retry.
**Solution :** Exception custom (`class MyService::Error < StandardError`) + `retry_on` :
```ruby
class MyService::Error < StandardError; end
# Service raise MyService::Error, job retry_on MyService::Error
# Le rescue Vips::Error ne catch pas → retry fonctionne
```

### Pattern 3 : Rails STI et polymorphic_name

**Piège :** `record_type` stocke le **polymorphic_name** (base class STI), pas la sous-classe.
```ruby
# ❌ where(record_type: "Champs::TitreIdentiteChamp") → rien
# ✅ Joindre la table STI :
ActiveStorage::Attachment
  .joins("JOIN champs ON champs.id = active_storage_attachments.record_id")
  .where(record_type: "Champ")
  .where(champs: { type: "Champs::TitreIdentiteChamp" })
```

### Pattern 4 : Suppression > Désactivation

**Supprimer** si business confirme non-critique + probabilité réactivation < 10%. **Désactiver** si rollback potentiel < 1 mois. En cas de doute → demander.

### Pattern 5 : Régression par perte de guard (migration composant)

**Symptôme :** `NoMethodError` sur nil ou `UrlGenerationError` après migration/réécriture de composant.
**Piège :** Un guard défensif (`.persisted?`, `.blank?`, `&.`) existait dans l'ancien composant mais a été perdu lors de la réécriture.
**Solution :** Lors de l'investigation, remonter l'historique git jusqu'au composant d'origine pour retrouver les guards perdus.
**Ref :** kaizen 2026-03-26 (unpersisted-attachments, V1→V2→V3)
