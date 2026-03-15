---
name: haml-migration
description: Migrate HAML templates to ERB with validation and visual comparison
allowed-tools: mcp__playwright__browser_navigate, mcp__playwright__browser_run_code, Bash(git rm:*), Bash(git mv:*), Bash(git add:*), Bash(git commit:*), Bash(bun lint:herb:*), Bash(bundle exec rspec:*)
---

# Migration HAML → ERB

**Contexte :** Migration d'un fichier HAML vers ERB avec validation visuelle via screenshots

**Input :** chemin vers un fichier `.html.haml` (ex: `app/components/alert/alert_component.html.haml`)

---

## Prérequis

**MCP Playwright** doit être enregistré via la CLI (le `.mcp.json` seul n'est PAS détecté par Claude Code) :
```bash
claude mcp add playwright -- npx -y @playwright/mcp@latest
# Le -- est obligatoire pour séparer les args
# Relancer Claude Code après ajout (/exit puis claude)
```

**Serveur de dev** doit tourner (`rails server` sur `localhost:3000`).

**Adaptations dev temporaires** — appliquer en début de PR, **NE JAMAIS COMMITER** :

**1. Auto-login dev** — ajouter dans `app/controllers/application_controller.rb` :
```diff
+  prepend_before_action :auto_sign_in_dev_user
   before_action :set_sentry_user
   before_action :redirect_if_untrusted
```

Et la méthode (avant `private`) :
```ruby
def auto_sign_in_dev_user
  return unless Rails.env.development?
  return if user_signed_in?

  user = User.find_or_initialize_by(email: 'dev@localhost')
  if user.new_record?
    user.password = 'Ds-P@ssw0rd!2026'
    user.confirmed_at = Time.current
    user.save!
    Administrateur.create!(user: user)
  end
  sign_in(user, scope: :user)
end
```

**2. Invalidation cache ViewComponent** — créer `config/initializers/view_component_dev_reload.rb` :
```ruby
# Force le reload des templates ViewComponent à chaque requête en dev
# Permet de switcher .haml → .erb sans redémarrer le serveur
Rails.application.config.to_prepare do
  next unless Rails.env.development?

  ViewComponent::CompileCache.invalidate!

  ObjectSpace.each_object(Class).select { |klass| klass < ViewComponent::Base }.each do |klass|
    if klass.instance_variable_defined?(:@__vc_compiler)
      compiler = klass.instance_variable_get(:@__vc_compiler)
      compiler.instance_variable_set(:@templates, nil) if compiler.instance_variable_defined?(:@templates)
    end
  end
end
```

⚠️ **CRITIQUE** : ces 2 modifications ne doivent JAMAIS être commitées. Les annuler avant tout commit :
```bash
git checkout app/controllers/application_controller.rb
rm config/initializers/view_component_dev_reload.rb
```

---

## Workflow (1 fichier)

### Étape 1 : Analyse

**⚠️ CRITIQUE :** Lire le HAML ET le fichier Ruby

1. Lire le fichier HAML
2. **Lire le fichier Ruby** associé (même dossier, `.rb`)
3. Identifier les méthodes utilisées dans le template :
   - Si retourne `Array` → utiliser `.join(' ')` en ERB
   - Si retourne `String` → utiliser directement
   - Si retourne `Hash` → utiliser `tag.attributes(**method)`
   - **⚠️ Si retourne HTML (helpers) → NE PAS interpoler dans string**
4. Rechercher les tests :
   ```bash
   grep -r "NomDuComposant" spec/
   ```

### Étape 2 : Screenshot HAML → commit

1. **Trouver une page qui affiche le composant** :
   ```bash
   grep -r "NomDuComposant\|render.*nom_du_composant" app/views/ app/components/
   ```
   - **Préférer les pages réelles** = preuve plus forte qu'une page de démo

2. **Évaluer la faisabilité** :
   - Si le composant nécessite des données spécifiques, des interactions (modal, dropdown), ou n'est visible sur aucune page standard → **skip le screenshot**, documenter la raison dans la PR
   - Seuil : > 5min de setup = skip

3. **Capturer avec MCP Playwright** :
   ```javascript
   async (page) => {
     const elements = await page.$$('.component-selector');
     for (let i = 0; i < elements.length; i++) {
       if (await elements[i].isVisible()) {
         await elements[i].screenshot({ path: `tmp/screenshots/haml/component-${i+1}.png` });
       }
     }
   }
   ```

4. **Commit** :
   ```bash
   git add tmp/screenshots/haml/
   git commit --no-gpg-sign -m "chore(haml): screenshot HAML avant migration — NomDuComposant"
   ```

### Étape 3 : Migration HAML → ERB → commit

#### 3a. Conversion

**Règles de conversion :**

```haml
%div.class-name          →  <div class="class-name">
  = content              →    <%= content %>
                         →  </div>

- if condition           →  <% if condition -%>
  = content              →    <%= content %>
                         →  <% end -%>

%div{ class: my_class }  →  <div class="<%= my_class %>">
                            (⚠️ Si my_class est un Array → .join(' '))

%div{ **options }        →  <div <%= tag.attributes(**options) %>>
```

**⚠️ Règles critiques :**

1. **Arrays de classes** : Si la méthode retourne un array, ajouter `.join(' ')`
2. **Pas de balises auto-fermantes** : `<input>` pas `<input />`
3. **Contrôler l'espacement** : Utiliser `<%-` et `-%>` pour supprimer newlines
4. **Guillemets** : Utiliser simples quotes `'` si tests sensibles
5. **String interpolation avec helpers HTML** :
   - ❌ `<%= "#{link_to('text', url)}." %>` (échappe le HTML)
   - ✅ `<%= link_to('text', url) %>.` (sortir le texte de l'interpolation)

#### 3b. Validation locale

**⚠️ OBLIGATOIRE - Ne JAMAIS skip cette étape**

1. **Linter herb** :
   ```bash
   bun lint:herb <fichier.html.erb>
   ```

2. **Tests locaux (si identifiés)** :
   ```bash
   bundle exec rspec spec/path/to/test_spec.rb
   ```
   **⚠️ CRITIQUE :** Le linter détecte la syntaxe, PAS la logique métier (SafeBuffer, helpers)

3. **Vérifier patterns à risque** :
   ```bash
   grep '/>' <fichier.html.erb>                                    # Pas de balises auto-fermantes
   grep '"#{.*link_to\|button_to\|form_' <fichier.html.erb>        # Pas d'interpolation helpers
   ```

#### 3c. Suppression HAML + commit

1. **Supprimer le fichier `.haml`** :
   - ⚠️ **ViewComponent refuse la coexistence `.haml` + `.erb`** → `TemplateError`
   ```bash
   git rm <fichier.html.haml>
   ```

2. **Forcer le reload du cache ViewComponent** :
   ```bash
   touch <fichier.rb>  # le .rb associé au composant
   ```

3. **Commit** :
   ```bash
   git add <fichier.html.erb>
   git commit --no-gpg-sign -m "refactor(haml): migrate NomDuComposant to ERB"
   ```

### Étape 4 : Screenshot ERB → commit

1. **Naviguer sur la même page que l'étape 2** avec MCP Playwright

2. **Capturer les screenshots ERB** avec le même script, path `tmp/screenshots/erb/`

3. **Commit** :
   ```bash
   git add tmp/screenshots/erb/
   git commit --no-gpg-sign -m "chore(haml): screenshot ERB après migration — NomDuComposant"
   ```

### Étape 5 : Comparaison

1. **Comparer les screenshots** (identique au byte = preuve forte) :
   ```bash
   for f in tmp/screenshots/erb/*.png; do name=$(basename "$f"); haml_size=$(stat -f%z "tmp/screenshots/haml/$name"); erb_size=$(stat -f%z "$f"); [ "$haml_size" = "$erb_size" ] && echo "✅ $name" || echo "❌ $name (haml: ${haml_size}b, erb: ${erb_size}b)"; done
   ```

2. **Si tous les screenshots sont ✅** → passer directement à l'étape 6

3. **Si un ou plusieurs screenshots sont ❌** :
   - **Comparer visuellement** : ouvrir les images HAML et ERB côte à côte (utiliser `Read` sur les PNG)
   - **Identifier la différence** : positionnement, espacement, contenu manquant, attributs perdus, etc.
   - **Diagnostiquer la cause** :
     - Différence de rendu PNG non significative (artefact < 0.1%) → documenter et continuer
     - Problème de conversion ERB (classe manquante, attribut perdu, helper mal converti) → **fixer**
   - **Si fix nécessaire** :
     1. Corriger le fichier `.html.erb`
     2. Valider (linter + tests)
     3. `touch` le `.rb` du composant
     4. Reprendre les screenshots ERB
     5. Commit le fix :
        ```bash
        git add <fichier.html.erb>
        git commit --no-gpg-sign -m "fix(haml): fix conversion NomDuComposant — <description du problème>"
        ```
     6. Re-commiter les nouveaux screenshots ERB
     7. Relancer la comparaison (retour au point 1)

### Étape 6 : Suppression screenshots + PR → commit final

1. **Capturer le résultat de comparaison** :
   ```bash
   DIFF_RESULT=$(for f in tmp/screenshots/erb/*.png; do name=$(basename "$f"); haml_size=$(stat -f%z "tmp/screenshots/haml/$name"); erb_size=$(stat -f%z "$f"); [ "$haml_size" = "$erb_size" ] && echo "✅ $name" || echo "❌ $name (haml: ${haml_size}b, erb: ${erb_size}b)"; done)
   ```

2. **Supprimer les screenshots + commit** :
   ```bash
   git rm -r tmp/screenshots/haml/ tmp/screenshots/erb/
   git commit --no-gpg-sign -m "$(cat <<EOF
   chore(haml): remove screenshots — NomDuComposant

   $DIFF_RESULT
   EOF
   )"
   ```

3. **Créer la PR** :
   ```bash
   gh pr create --title "refactor(haml): migrate NomDuComposant to ERB" --body "$(cat <<'EOF'
   ## Migration HAML → ERB — NomDuComposant

   ### Commits
   1. 📸 Screenshot HAML (avant)
   2. 🔄 Migration HAML → ERB
   3. 📸 Screenshot ERB (après)
   4. 🧹 Suppression screenshots (résultat comparaison dans le commit)

   ### Résultat comparaison visuelle
   <!-- Coller ici le DIFF_RESULT -->

   ### Validation
   - Linter herb : ✅ 0 offenses
   - Tests : ✅ passés
   - Screenshots : ✅ identiques au byte / ❌ différences documentées

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   EOF
   )"
   ```

---

## Checklist

- [ ] Fichier HAML + fichier Ruby lus (vérifier types de retour)
- [ ] Screenshot HAML capturé → commit
- [ ] Conversion complète (arrays `.join`, pas de `/>`, espacement, pas d'interpolation helpers)
- [ ] Linter herb passé
- [ ] Tests passés (si identifiés)
- [ ] HAML supprimé (`git rm`) + `touch` du `.rb` → commit migration
- [ ] Screenshot ERB capturé → commit
- [ ] Comparaison : tous ✅ ou différences investiguées et fixées
- [ ] Screenshots supprimés avec résultat dans le commit → commit final
- [ ] PR créée
