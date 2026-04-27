# Patterns i18n-hardcoded

## Patterns valides

### Mailer subjects
```ruby
# Avant
@subject = "Votre archive est disponible"

# Apres — utiliser default_i18n_subject quand le scope match
@subject = default_i18n_subject

# Ou avec interpolation
@subject = default_i18n_subject(count: @dossiers.size)
```

YAML correspondant :
```yaml
fr:
  user_mailer:
    archive_available:
      subject: "Votre archive est disponible"
```

### Lazy lookup dans les vues
```erb
<!-- Avant -->
<h1>Modifier votre dossier</h1>

<!-- Apres -->
<h1><%= t(".edit_title") %></h1>
```

### ViewComponent sidecar
```ruby
# Avant
when :error then "Erreur : "

# Apres
when :error then t(".error_prefix")
```

YAML sidecar (`app/components/dsfr/alert/alert_component.yml`) :
```yaml
fr:
  error_prefix: "Erreur : "
```

### Interpolation
```ruby
# Avant
"Dossier n#{dossier.id} depose"

# Apres
I18n.t("dossiers.deposited", id: dossier.id)
```

```yaml
fr:
  dossiers:
    deposited: "Dossier n%{id} depose"
```

### Turbo confirm
```erb
<!-- Avant -->
data: { turbo_confirm: "Confirmez-vous la suppression ?" }

<!-- Apres -->
data: { turbo_confirm: t(".confirm_delete") }
```

## Anti-patterns (ne PAS extraire)

### Strings techniques
```ruby
# NE PAS extraire
content_type = "application/pdf"
format = "csv"
redirect_to root_path, status: :moved_permanently
```

### Interpolation HTML complexe
```ruby
# NE PAS extraire (helper HTML dans l'interpolation)
"Cliquez #{link_to('ici', url)} pour continuer"
# → Laisser en l'etat, trop risque
```

### Strings de log/debug
```ruby
# NE PAS extraire
Rails.logger.info "Processing dossier #{id}"
```

### Constantes de seeds/migrations
```ruby
# NE PAS extraire (code one-shot)
CommentaireService.build(instructeur, dossier, { body: "Migration automatique" })
```
