# Spec Technique : Fix snowball emails de renouvellement de session

**Date :** 2026-03-13
**Auteur :** Agent + mfo
**Status :** v2 (post-review PM)
**Temps estimé implémentation :** 1-2h
**Complexité :** Simple
**Version template :** 2.0

---

## Checkpoints Critiques

- [x] **Bug architectural détecté ?** → Oui, mais fix simple (pas besoin de refactoring global)
- [ ] **> 5 fichiers impactés ?** → Non, 3 fichiers (job + spec + migration)
- [ ] **Décisions d'architecture nécessaires ?** → Toutes tranchées (voir section 2)
- [ ] **Logique répétée 3+ fois ?** → Non

---

## 1. Contexte & Problème

### Description

Une instructrice remonte qu'elle est "noyée sous les mails" de connexion sécurisée. L'analyse montre un effet boule de neige (snowball) sur les emails de renouvellement.

### Root Cause

Le cron `Cron::TrustedDeviceTokenRenewalJob` (quotidien, ~12h) itère sur **chaque token** expirant individuellement :

```ruby
# app/jobs/cron/trusted_device_token_renewal_job.rb:7
TrustedDeviceToken.expiring_in_one_week.find_each do |token|
  token.touch(:renewal_notified_at)
  renewal_token = token.instructeur.create_trusted_device_token
  InstructeurMailer.trusted_device_token_renewal(...).deliver_later
end
```

Chaque token génère :
1. Un email de renouvellement
2. Un **nouveau token** (`create_trusted_device_token`)

Si un instructeur s'est connecté 4 fois dans la semaine → 4 tokens activés → 4 emails de renouvellement → 4 nouveaux tokens → boucle d'amplification au cycle suivant.

**Preuves dans les logs :**
- 28 fév : 4 renouvellements à 12:00, 12:01, 12:01, 12:01
- 13 fév : 4 renouvellements à 12:06, 12:10, 12:11, 12:19
- 11 mars : 3 renouvellements à 12:03, 12:08, 12:12

### Point clé validé : indépendance cookie / token DB

L'investigation a confirmé que le cookie `trusted_device` est **self-contained** :

- `trusted_device?` (`trusted_device_concern.rb:21-23`) ne lit **que le cookie** (timestamp chiffré), jamais la DB
- `redirect_if_untrusted` (`application_controller.rb:320-338`) appelle `trusted_device?` → cookie only
- Après activation (`trust_device()`), le token DB n'est **plus jamais consulté** pour l'authentification

**Conséquence :** modifier les tokens en DB n'impacte pas les sessions actives. Le fix est safe.

### Objectifs

- [x] Un instructeur ne reçoit **jamais plus d'un email** de renouvellement par exécution du cron
- [x] Les tokens "en trop" sont marqués `renewal_notified_at` pour ne pas repasser
- [x] L'historique des tokens est préservé (pas de suppression)
- [x] Le nouveau token de renouvellement est créé une seule fois par instructeur

---

## 2. Décisions d'Architecture

### Décision 1 : Dédupliquer dans le cron uniquement (pas de changement au flow de création)

**Choix :** Grouper les tokens expirants par instructeur dans le cron, n'envoyer qu'un email avec le token le plus récent.

**Alternative :** Révoquer les anciens tokens à la création d'un nouveau (champ `revoked_at`, migration DB).

**Rationale :**
- Fix minimal : 1 fichier + 1 spec + 1 migration hygiène
- L'historique des tokens est préservé (chaque connexion = 1 token = 1 trace)
- La création de tokens reste inchangée (pas de risque de régression sur le flow de connexion)

**Impact :** Le cron passe de O(N tokens) emails à O(N instructeurs) emails.

### Décision 2 : Marquer les tokens non-envoyés avec `renewal_notified_at`

**Choix :** Les tokens expirants "en trop" sont marqués `renewal_notified_at` silencieusement.

**Alternative :** Les ignorer (ils repasseraient au prochain run du cron).

**Rationale :**
- Idempotent : si le cron tourne 2 fois, 1 seul email
- Utilise le champ existant `renewal_notified_at`, pas de migration
- Évite de retraiter les mêmes tokens

**Impact :** Comportement idempotent garanti.

---

## 3. Architecture Proposée

### Vue d'ensemble

```
AVANT :
  cron → find_each(token) → 1 email/token → N emails/instructeur

APRÈS :
  cron → find_each(instructeur) → 1 email/instructeur → marquer tous tokens
```

### Composants impactés

1. **Job** : `app/jobs/cron/trusted_device_token_renewal_job.rb` — refactoring boucle
2. **Spec** : `spec/jobs/cron/trusted_device_token_renewal_job_spec.rb` — nouveau test dédup
3. **Migration** : `add NOT NULL` sur `trusted_device_tokens.instructeur_id` (hygiène)

---

## 4. Modèle (Database & ActiveRecord)

### Migrations

Strong Migrations requiert 2 migrations (check constraint pattern) :

```ruby
# Migration 1 : ajouter la contrainte (non validée, non bloquante)
class AddNotNullToTrustedDeviceTokensInstructeurId < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint :trusted_device_tokens, "instructeur_id IS NOT NULL",
      name: "trusted_device_tokens_instructeur_id_null", validate: false
  end
end

# Migration 2 : valider la contrainte
class ValidateNotNullTrustedDeviceTokensInstructeurId < ActiveRecord::Migration[7.2]
  def change
    validate_check_constraint :trusted_device_tokens,
      name: "trusted_device_tokens_instructeur_id_null"
  end
end
```

**Rationale :** la FK existe déjà et le modèle a `belongs_to :instructeur, optional: false`, mais la contrainte NOT NULL manque côté DB. Migration d'hygiène sans risque (aucun row avec `instructeur_id NULL` ne peut exister grâce à la FK).

### Validations

Aucun changement.

### Index

Aucun index à ajouter. L'index existant `index_trusted_device_tokens_on_instructeur_id` supporte le `joins` SQL.

---

## 5. Controller

Aucun changement.

---

## 6. Jobs

### Signature

Inchangée : `perform` sans arguments.

### Code actuel (`trusted_device_token_renewal_job.rb`)

```ruby
def perform
  TrustedDeviceToken.expiring_in_one_week.find_each do |token|
    begin
      ActiveRecord::Base.transaction do
        token.touch(:renewal_notified_at)
        renewal_token = token.instructeur.create_trusted_device_token
        InstructeurMailer.trusted_device_token_renewal(
          token.instructeur, renewal_token,
          token.instructeur.trusted_device_tokens.last.token_valid_until
        ).deliver_later
      end
    rescue StandardError => e
      Sentry.capture_exception(e)
    end
  end
end
```

### Code proposé

```ruby
def perform
  Instructeur
    .joins(:trusted_device_tokens)
    .merge(TrustedDeviceToken.expiring_in_one_week)
    .distinct
    .find_each do |instructeur|
      begin
        tokens = instructeur.trusted_device_tokens.expiring_in_one_week

        ActiveRecord::Base.transaction do
          # Marquer tous les tokens comme notifiés en 1 requête (idempotence)
          tokens.update_all(renewal_notified_at: Time.current)

          # Créer un seul nouveau token et envoyer un seul email
          renewal_token = instructeur.create_trusted_device_token
          InstructeurMailer.trusted_device_token_renewal(
            instructeur, renewal_token,
            instructeur.trusted_device_tokens.order(created_at: :desc).first.token_valid_until
          ).deliver_later
        end
      rescue StandardError => e
        Sentry.capture_exception(e)
      end
    end
end
```

### Changements clés

1. Itération sur `Instructeur.find_each` au lieu de `TrustedDeviceToken.find_each` : déduplication naturelle par instructeur, mémoire constante (batché par 1000)
2. `tokens.update_all(renewal_notified_at: Time.current)` : marque **tous** les tokens en 1 requête SQL
3. Un seul `create_trusted_device_token` + un seul email par instructeur

### Breaking changes

Aucun. La signature du job est inchangée. Aucun call-site impacté.

---

## 7. Services / Query Objects

Aucun service ou query object nécessaire. La logique de groupement est triviale et localisée dans le job (1 seul endroit, pas de duplication).

---

## 8. Tests

### Tests à modifier

**`spec/jobs/cron/trusted_device_token_renewal_job_spec.rb`**

Le test existant couvre le cas 1 token → 1 instructeur. Il faut ajouter :

### Tests à créer

```ruby
# Cas : plusieurs tokens expirants pour le même instructeur
context 'when an instructeur has multiple expiring tokens' do
  let!(:same_instructeur_token_1) do
    create(:trusted_device_token,
      instructeur: token_to_notify.instructeur,
      activated_at: (TrustedDeviceConcern::TRUSTED_DEVICE_PERIOD - 3.days).ago,
      renewal_notified_at: nil)
  end

  it 'sends only one email' do
    expect(InstructeurMailer)
      .to receive(:trusted_device_token_renewal).once
      .and_return(double(deliver_later: true))
    subject
  end

  it 'marks all tokens as notified' do
    subject
    expect(token_to_notify.reload.renewal_notified_at).to be_present
    expect(same_instructeur_token_1.reload.renewal_notified_at).to be_present
  end

  it 'creates only one new token' do
    expect { subject }.to change { TrustedDeviceToken.count }.by(1)
  end
end

# Cas : deux instructeurs distincts avec tokens expirants
context 'when multiple instructeurs have expiring tokens' do
  let!(:other_instructeur_token) do
    create(:trusted_device_token,
      activated_at: (TrustedDeviceConcern::TRUSTED_DEVICE_PERIOD - 5.days).ago,
      renewal_notified_at: nil)
  end

  it 'sends one email per instructeur' do
    expect(InstructeurMailer)
      .to receive(:trusted_device_token_renewal).twice
      .and_return(double(deliver_later: true))
    subject
  end
end
```

### Principe : Tests verts à chaque commit

Un seul commit avec code + tests → tests verts.

---

## 9. Migration de Données (Backfill)

Aucune migration de données nécessaire. Le fix agit sur le comportement futur du cron uniquement.

---

## 10. Breaking Changes

Aucun breaking change. Le job garde la même signature, les mêmes effets (emails envoyés, tokens créés), mais dédupliqués par instructeur.

---

## 11. Performance

### Analyse

**Avant :** `TrustedDeviceToken.find_each` → itère par token, 1 email par token, N emails par instructeur.

**Après :** `Instructeur.find_each` → itère par instructeur (batché par 1000), mémoire constante, 1 email par instructeur. `update_all` pour marquer les tokens en 1 requête SQL par instructeur.

Pas de trade-off mémoire : `find_each` est conservé, on change juste l'entité itérée (instructeur au lieu de token).

### Index existants suffisants

- `index_trusted_device_tokens_on_instructeur_id` → supporte le `joins` SQL
- Pas d'index à ajouter

---

## 12. Sécurité

### Validations

Aucun changement. Les tokens continuent d'être créés via `has_secure_token`.

### Authorization

Aucun changement. Le cron est un job système sans contexte utilisateur.

---

## 13. UX / Product

### Comportement attendu

- Un instructeur reçoit **exactement 1 email** de renouvellement par exécution du cron
- L'email contient le lien vers le token le plus récent
- Aucun changement visible dans l'email (même template, même mailer)

### Edge cases

| Cas | Comportement |
|-----|-------------|
| 1 token expirant, 1 instructeur | Identique à l'actuel (1 email) |
| 4 tokens expirants, 1 instructeur | 1 seul email (token le plus récent), 4 tokens marqués notifiés |
| 0 tokens expirants | Aucun email (identique à l'actuel) |
| Cron exécuté 2 fois | Idempotent : 2e run ne trouve rien (tous marqués `renewal_notified_at`) |
| Erreur Sentry sur 1 instructeur | Les autres instructeurs sont traités normalement (rescue par groupe) |

---

## 14. Rollout Strategy

**Déploiement direct** — pas de feature flag nécessaire.

- Le changement est rétrocompatible
- Le cron tourne 1 fois/jour → déploiement entre 2 runs suffit
- Rollback = revert du commit (retour au comportement actuel)

---

## 15. Métriques & Monitoring

### Métriques à observer post-déploiement

- **Volume d'emails "renouvellement"** envoyés par jour → doit baisser significativement (cible : 1 max par instructeur)
- **Nombre de tokens créés par le cron** par jour → doit baisser proportionnellement
- **Tickets support "trop d'emails"** → cible : 0 sous 30 jours

### Alertes

Pas de nouvelles alertes nécessaires. Sentry capture déjà les erreurs du job.

---

## 16. Annexes

### Fichiers impactés

| Fichier | Action |
|---------|--------|
| `app/jobs/cron/trusted_device_token_renewal_job.rb` | Modifier : dédupliquer par instructeur |
| `spec/jobs/cron/trusted_device_token_renewal_job_spec.rb` | Modifier : ajouter tests déduplication |
| `db/migrate/XXXX_add_not_null_to_trusted_device_tokens_instructeur_id.rb` | Créer : contrainte NOT NULL |

### Estimations

- **Implémentation :** 30min
- **Tests :** 30min
- **Review + QA :** 30min
- **Total :** 1h30

### Références

- Document d'analyse incident : `snowball-renew-session.md`
- Investigation cookie/token : le cookie `trusted_device` est self-contained, la DB n'est jamais reconsultée après activation du token
