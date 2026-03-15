---
name: haml-migration
description: Migrate HAML templates to ERB with validation and visual comparison
---

# Migration HAML → ERB

**Contexte :** Migration de templates HAML vers ERB avec validation visuelle via screenshots

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

## Objectif

Convertir un batch de fichiers HAML en ERB en préservant le markup HTML, les classes CSS, et tous les attributs data-/aria-. Prouver l'équivalence visuelle avec des screenshots comparatifs HAML vs ERB.

---

## Workflow (batch max 15 fichiers)

### Étape 0 : Sélection automatique du batch (2min)

**Critères de sélection automatique :**
- Max 15 fichiers par batch
- Privilégier composants simples (< 30 lignes, UI pur)
- Éviter composants avec logique métier complexe

**Si batch > 15 :** Créer automatiquement un subset sans demander à l'utilisateur

**Fichiers à migrer :**
```bash
# Lister les fichiers HAML restants
find app -name "*.html.haml" | head -15
```

### Étape 1 : Analyse complète (10min)

**⚠️ CRITIQUE :** Lire le HAML ET le fichier Ruby

1. Lire le fichier HAML : `app/components/nom/nom.html.haml`
2. **Lire le fichier Ruby : `app/components/nom/nom.rb`**
3. Identifier les méthodes utilisées dans le template :
   - Si retourne `Array` → utiliser `.join(' ')` en ERB
   - Si retourne `String` → utiliser directement
   - Si retourne `Hash` → utiliser `tag.attributes(**method)`
   - **⚠️ Si retourne HTML (helpers) → NE PAS interpoler dans string**
4. Rechercher les tests :
   ```bash
   grep -r "nom_du_composant" spec/
   ```

### Étape 2 : Capture screenshots HAML → commit (10min)

**Évaluer la complexité de capture pour chaque composant :**

| Niveau | Critère | Action |
|---|---|---|
| **Simple** | Visible sur une page accessible directement | Screenshot automatique |
| **Moyen** | Nécessite navigation + auth mais pas de données spécifiques | Screenshot avec bypass auth |
| **Complexe** | Nécessite données spécifiques, interactions (modal, dropdown), ou aucune page standard | **Skip → validation manuelle** |

**Si Complexe** : ne pas perdre de temps (seuil : > 5min de setup par composant). Documenter dans la PR : "Composant X : screenshot skippé (raison), à valider manuellement par le reviewer."

**Si Simple ou Moyen** : capturer l'état visuel AVANT de modifier quoi que ce soit.

1. **Identifier les pages qui affichent les composants du batch** :
   - Chercher les pages qui rendent les composants du batch
   - **Préférer les pages réelles** = preuve plus forte qu'une page de démo isolée
   ```bash
   grep -r "NomDuComposant\|render.*nom_du_composant" app/views/ app/components/
   ```

2. **Naviguer avec MCP Playwright** :
   - Utiliser `browser_navigate` vers la page identifiée
   - S'assurer que les adaptations dev sont appliquées (voir Prérequis)

3. **Capturer les screenshots HAML par sélecteur CSS** :
   - Utiliser `browser_run_code` avec `page.$$` (querySelectorAll) pour cibler chaque composant
   ```javascript
   async (page) => {
     const components = [
       { selector: '.component-class', name: 'component-name' },
       // Adapter selon le batch
     ];
     for (const comp of components) {
       const elements = await page.$$(comp.selector);
       for (let i = 0; i < elements.length; i++) {
         // ⚠️ Toujours vérifier isVisible() — des éléments hidden causent un timeout
         if (await elements[i].isVisible()) {
           await elements[i].screenshot({ path: `tmp/screenshots/haml/${comp.name}-${i+1}.png` });
         }
       }
     }
   }
   ```

4. **Commit** :
   ```bash
   git add tmp/screenshots/haml/
   git commit --no-gpg-sign -m "chore(haml): capture screenshots HAML avant migration [BATCH]"
   ```

### Étape 3 : Migration HAML → ERB → commit (35min)

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
   bun lint:herb app/components/nom/nom.html.erb
   ```

2. **Tests locaux (si tests identifiés)** :
   ```bash
   bundle exec rspec spec/path/to/test_spec.rb
   ```
   **⚠️ CRITIQUE :** Le linter détecte la syntaxe, PAS la logique métier (SafeBuffer, helpers)

3. **Vérifier patterns à risque** :
   ```bash
   # Pas de balises auto-fermantes
   grep '/>' app/components/nom/nom.html.erb  # Doit être vide

   # Vérifier arrays
   grep 'class=' app/components/nom/nom.html.erb

   # Vérifier string interpolation helpers
   grep '"#{.*link_to\|button_to\|form_' app/components/nom/nom.html.erb  # Doit être vide
   ```

#### 3c. Suppression HAML + commit

1. **Supprimer les fichiers `.haml`** :
   - ⚠️ **ViewComponent refuse la coexistence `.haml` + `.erb`** → `TemplateError: More than one HTML template found`
   ```bash
   git rm app/components/nom/*.html.haml
   ```

2. **Forcer le reload du cache ViewComponent** :
   - ⚠️ `config.to_prepare` ne se déclenche que sur les changements de fichiers `.rb` — supprimer/ajouter des `.haml`/`.erb` ne déclenche PAS le reload
   - **Fix obligatoire** : toucher le `.rb` de chaque composant migré :
   ```bash
   touch app/components/nom_component.rb
   ```

3. **Commit** :
   ```bash
   git add app/components/
   git commit --no-gpg-sign -m "refactor(haml): migrate [BATCH] to ERB"
   ```

### Étape 4 : Capture screenshots ERB → commit (10min)

1. **Naviguer sur les mêmes pages que l'étape 2** avec MCP Playwright

2. **Capturer les screenshots ERB** avec le même script que l'étape 2, en changeant le path :
   - `tmp/screenshots/erb/${comp.name}-${i+1}.png`

3. **Commit** :
   ```bash
   git add tmp/screenshots/erb/
   git commit --no-gpg-sign -m "chore(haml): capture screenshots ERB après migration [BATCH]"
   ```

### Étape 5 : Comparaison + publication PR (10min)

1. **Comparer les screenshots** (identique au byte = preuve forte) :
   ```bash
   for f in tmp/screenshots/erb/*.png; do name=$(basename "$f"); haml_size=$(stat -f%z "tmp/screenshots/haml/$name"); erb_size=$(stat -f%z "$f"); [ "$haml_size" = "$erb_size" ] && echo "✅ $name" || echo "❌ $name"; done
   ```
   - Si différence détectée → investiguer et corriger avant de continuer

2. **Mettre à jour la description de la PR** avec les résultats de comparaison :
   ```bash
   gh pr comment <PR_NUMBER> --body "$(cat <<'EOF'
   ## 📸 Validation Visuelle HAML → ERB

   ### Résumé
   - Composants migrés : X
   - Screenshots comparés : Y (identiques au byte)
   - Validation manuelle requise : Z

   ### Comparaison automatique

   #### [nom_composant]
   | HAML (avant) | ERB (après) |
   |--------------|-------------|
   | ![HAML](url) | ![ERB](url) |

   **Verdict :** ✅ Identique

   ### Validation manuelle requise

   | Composant | Raison du skip |
   |-----------|----------------|
   | [nom] | Nécessite données spécifiques / modal / etc. |

   ⚠️ Reviewer : merci de valider visuellement ces composants.
   EOF
   )"
   ```

   **Note :** Pour inclure les images dans le commentaire PR, les uploader d'abord via l'interface GitHub (drag & drop) ou via `gh release create` pour obtenir les URLs.

### Étape 6 : Suppression screenshots → commit final (avec résultat comparaison)

```bash
# Capturer le résultat de comparaison avant de supprimer
DIFF_RESULT=$(for f in tmp/screenshots/erb/*.png; do name=$(basename "$f"); haml_size=$(stat -f%z "tmp/screenshots/haml/$name"); erb_size=$(stat -f%z "$f"); [ "$haml_size" = "$erb_size" ] && echo "✅ $name" || echo "❌ $name (haml: ${haml_size}b, erb: ${erb_size}b)"; done)

git rm -r tmp/screenshots/haml/ tmp/screenshots/erb/
git commit --no-gpg-sign -m "$(cat <<EOF
chore(haml): remove screenshots after visual validation [BATCH]

$DIFF_RESULT
EOF
)"
```

---

## Checklist

**Étape 1 — Analyse**
- [ ] Batch sélectionné (max 15 fichiers)
- [ ] Fichier HAML + fichier Ruby lus (vérifier types de retour)

**Étape 2 — Screenshots HAML → commit**
- [ ] Screenshots HAML capturés (MCP Playwright)
- [ ] Commit screenshots HAML

**Étape 3 — Migration → commit**
- [ ] Conversion complète (arrays `.join`, pas de `/>`, espacement, pas d'interpolation helpers)
- [ ] Linter herb passé
- [ ] Tests passés (si identifiés)
- [ ] Patterns à risque vérifiés (grep)
- [ ] Fichiers HAML supprimés (`git rm`) + `touch` des `.rb`
- [ ] Commit migration

**Étape 4 — Screenshots ERB → commit**
- [ ] Screenshots ERB capturés (MCP Playwright)
- [ ] Commit screenshots ERB

**Étape 5 — Comparaison + PR**
- [ ] Screenshots comparés — pas de régression visuelle
- [ ] Résultats publiés dans la PR

**Étape 6 — Cleanup → commit**
- [ ] Screenshots supprimés (`git rm -r`)
- [ ] Commit final

