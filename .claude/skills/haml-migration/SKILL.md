---
name: haml-migration
description: Migrate HAML templates to ERB with validation and visual comparison
allowed-tools: mcp__playwright__browser_navigate, mcp__playwright__browser_run_code, mcp__playwright__browser_take_screenshot, Bash(git rm:*), Bash(git mv:*), Bash(git add:*), Bash(git commit:*), Bash(bun lint:herb *), Bash(bundle exec rspec:*), Bash(find:*), Bash(shuf:*), Bash(rm -rf docs/migrations/screenshots:*), Bash(mkdir:*), Bash(grep:*), Bash(bundle exec rake:*), Bash(gh:*), Bash(git -C:*)
---

# Migration HAML → ERB

**Contexte :** Migration d'un fichier HAML vers ERB avec validation visuelle via screenshots

**Input :** chemin vers un fichier `.html.haml` (ex: `app/components/alert/alert_component.html.haml`)

**⚠️ Règle Bash** : ne jamais utiliser de commandes qui déclenchent une approbation de sécurité. Concrètement :
- Pas de `$()` (command substitution) — stocker dans une variable via un appel séparé
- Pas de `;` ou `&&` pour chaîner — faire des appels Bash séparés
- Pas de pipes complexes (`cmd1 | cmd2`) — découper en étapes
- 1 commande simple = 1 appel Bash

---

## Prérequis

**MCP Playwright** doit être enregistré via la CLI (le `.mcp.json` seul n'est PAS détecté par Claude Code) :
```bash
claude mcp add playwright -- npx -y @playwright/mcp@latest
# Le -- est obligatoire pour séparer les args
# Relancer Claude Code après ajout (/exit puis claude)
```

**Serveur de dev** doit tourner (`rails server` sur `localhost:3000`).

**Bypass `trusted_device_token`** : après le auto-login, `redirect_if_untrusted` bloque l'accès aux pages. Aller sur `localhost:3000/letter_opener`, ouvrir le dernier email et cliquer le lien de connexion sécurisé.

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

  # Credentials fictifs — usage dev local uniquement, jamais commités
  user = User.find_or_initialize_by(email: 'martin.fourcade@beta.gouv.fr')
  if user.new_record?
    user.password = 'Ds-P@ssw0rd!2026'
    user.confirmed_at = Time.current
    user.save!
    Administrateur.create!(user: user)
  end
  sign_in(user, scope: :user)
end
```

> **Note RGPD :** L'email et le mot de passe ci-dessus sont des **valeurs mock pour l'environnement de dev local**. Ce code n'est jamais commité dans le repo cible (instruction "NE JAMAIS COMMITER" ci-dessus). Les screenshots de validation visuelle sont pris sur une **base de dev anonymisée** (seed data fictive), sans données personnelles réelles.

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

## Plan de commits (OBLIGATOIRE — suivre dans l'ordre)

**❌ Ne jamais commencer à coder sans avoir ce plan en tête.**
**❌ Ne jamais sauter un commit ou en fusionner deux.**

```
Commit 1: chore(haml): screenshot HAML avant migration   → voir Étape 2
Commit 2: refactor(haml): migrate NomDuComposant to ERB   → voir Étape 3
Commit 3: chore(haml): screenshot ERB après migration     → voir Étape 4
  ── Comparaison (Étape 5) ──
  Si ❌ : fix → commit "fix(haml): ..." → reprendre commit 3 → re-comparer
Commit 4: chore(haml): remove screenshots                 → voir Étape 6
  ── Créer ou mettre à jour la PR (Étape 6) ──
```

**Après chaque commit, vérifier quel est le PROCHAIN dans ce plan. Ne pas improviser l'ordre.**

---

## Workflow (1 fichier)

### Étape 0 : Reset des répertoires de screenshots

```bash
rm -rf docs/migrations/screenshots/haml docs/migrations/screenshots/erb
mkdir -p docs/migrations/screenshots/haml docs/migrations/screenshots/erb
```

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

2. **Évaluer la faisabilité** (dans cet ordre de préférence) :

   **a. Page réelle disponible** → capturer directement (cas idéal)

   **b. Pas de page réelle mais composant simple** → créer un **preview ViewComponent** :
   - Évaluer la complexité : le composant peut-il se rendre avec des données mockées simples ?
   - Si oui (< 5min de setup) → créer un preview dans `spec/components/previews/` :
     ```ruby
     # spec/components/previews/nom_du_composant_preview.rb
     class NomDuComposantPreview < ViewComponent::Preview
       def default
         render NomDuComposant.new(param: valeur_simple)
       end
     end
     ```
   - Visiter `localhost:3000/rails/view_components/nom_du_composant/default`
   - Commiter le preview avec le commit 1 (il restera dans le projet — utile pour la suite)

   **c. Composant trop complexe** (données imbriquées, interactions, contexte lourd) → **skip le screenshot**, documenter la raison dans la PR
   - Seuil : > 5min de setup = skip

3. **Capturer avec MCP Playwright** :
   ```javascript
   async (page) => {
     const elements = await page.$$('.component-selector');
     for (let i = 0; i < elements.length; i++) {
       if (await elements[i].isVisible()) {
         await elements[i].screenshot({ path: `docs/migrations/screenshots/haml/component-${i+1}.png` });
       }
     }
   }
   ```

4. **Commit** (inclure le preview si créé à l'étape 2b) :
   ```bash
   git add docs/migrations/screenshots/haml/
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
6. **Extraction i18n obligatoire** : tout texte français en dur dans le HAML doit être extrait en clé i18n dans l'ERB. Ne PAS recopier les textes tels quels.

   **Pour un ViewComponent** (`app/components/`) : utiliser le fichier de traduction du composant (le créer si besoin) :
   ```yaml
   # app/components/export_dropdown/export_dropdown_component.yml
   fr:
     standard: "Standard"
     cancel: "Annuler"
   ```
   ```erb
   <%= t(".standard") %>
   <%= t(".cancel") %>
   ```

   **Pour une vue classique** (`app/views/`) : utiliser le namespace Rails standard correspondant au chemin du fichier :
   ```yaml
   # config/locales/views/dossiers/show.fr.yml
   fr:
     dossiers:
       show:
         submit_button: "Envoyer le dossier"
   ```
   ```erb
   <%= t(".submit_button") %>
   ```


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

3. **Vérifier patterns à risque** (1 grep par appel Bash) :
   - `grep '/>' <fichier.html.erb>` → doit être vide (pas de balises auto-fermantes)
   - `grep 'link_to' <fichier.html.erb>` → vérifier qu'aucun n'est dans une interpolation `"#{}"`
   - `grep 'button_to' <fichier.html.erb>` → idem

4. **Linter apostrophes typographiques** :
   ```bash
   bundle exec rake apostrophe_lint
   ```

5. **Check i18n** : relire le fichier ERB et vérifier qu'aucun texte français n'est resté en dur (cf. règle 6 étape 3a)

#### 3c. Remplacement HAML → ERB + commit

1. **Renommer le fichier via `git mv`** (préserve l'historique git) :
   ```bash
   git mv <fichier.html.haml> <fichier.html.erb>
   ```
   Puis écrire le contenu ERB dans le fichier renommé.

2. **Si ViewComponent** — forcer le reload du cache :
   ```bash
   touch <fichier.rb>
   ```
   (Uniquement pour les composants ViewComponent, pas pour les vues classiques)

3. **Commit** (inclure les fichiers i18n si créés) :
   ```bash
   git add <fichier.html.erb>
   git commit --no-gpg-sign -m "refactor(haml): migrate NomDuComposant to ERB"
   ```

### Étape 4 : Screenshot ERB → commit

1. **Naviguer sur la même page que l'étape 2** avec MCP Playwright

2. **Capturer les screenshots ERB** avec le même script, path `docs/migrations/screenshots/erb/`

3. **Commit** :
   ```bash
   git add docs/migrations/screenshots/erb/
   git commit --no-gpg-sign -m "chore(haml): screenshot ERB après migration — NomDuComposant"
   ```

### Étape 5 : Comparaison

1. **Comparer les screenshots** (identique au byte = preuve forte) :
   - Pour chaque fichier dans `docs/migrations/screenshots/erb/`, comparer sa taille avec le fichier correspondant dans `haml/`
   - Utiliser `stat -f%z` sur chaque fichier (1 appel Bash par fichier)
   - Identique au byte = ✅, différence = ❌

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

1. **Construire le résultat de comparaison** : reprendre les résultats de l'étape 5 (✅/❌ par fichier)

2. **Supprimer les screenshots** :
   ```bash
   rm -rf docs/migrations/screenshots/haml/
   ```
   ```bash
   rm -rf docs/migrations/screenshots/erb/
   ```
   ```bash
   git rm -r docs/migrations/screenshots/
   ```

3. **Commit avec le résultat de comparaison dans le message** :
   ```
   chore(haml): remove screenshots — NomDuComposant

   ✅ component-1.png
   ✅ component-2.png
   ```

4. **Mettre à jour ou créer la PR** :
   - Si une PR existe déjà sur la branche → mettre à jour sa description (`gh pr edit`)
   - Sinon → créer une PR (`gh pr create`)

   **Template de description PR** (adapter les liens vers les commits réels) :
   ```markdown
   ## Migration HAML → ERB — NomDuComposant

   ### Plan de commits
   1. 📸 [`chore: screenshot HAML`](lien-commit-1) — captures avant migration ([voir screenshots](lien-tree-commit-1/docs/migrations/screenshots/haml/))
   2. 🔄 [`refactor: migrate to ERB`](lien-commit-2) — conversion + validation
   3. 📸 [`chore: screenshot ERB`](lien-commit-3) — captures après migration ([voir screenshots](lien-tree-commit-3/docs/migrations/screenshots/erb/))
   4. 🧹 [`chore: remove screenshots`](lien-commit-4) — résultat comparaison dans le message de commit

   ### Résultat comparaison visuelle
   <!-- Coller ici le DIFF_RESULT -->

   ### Validation
   - Linter herb : ✅ / ❌
   - Tests : ✅ / ❌
   - Apostrophes : ✅ / ❌
   - Screenshots : ✅ identiques au byte / ❌ différences documentées

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   ```

   Les liens `lien-tree-commit-X` pointent vers `github.com/<repo>/tree/<sha>/docs/migrations/screenshots/` — le reviewer peut voir les screenshots directement dans GitHub même après leur suppression au commit 4.

---

## Checklist

- [ ] Fichier HAML + fichier Ruby lus (vérifier types de retour)
- [ ] Screenshot HAML capturé (+ preview si créé) → commit
- [ ] Conversion complète (arrays `.join`, pas de `/>`, espacement, pas d'interpolation helpers)
- [ ] Textes français extraits en i18n (pas de texte en dur dans l'ERB)
- [ ] Linter herb passé
- [ ] Tests passés (si identifiés)
- [ ] `git mv` HAML → ERB + `touch` du `.rb` + fichiers i18n → commit migration
- [ ] Screenshot ERB capturé → commit
- [ ] Comparaison : tous ✅ ou différences investiguées et fixées
- [ ] Screenshots supprimés avec résultat dans le commit → commit final
- [ ] PR créée ou mise à jour
