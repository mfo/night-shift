---
name: haml-migration
description: Migrate HAML templates to ERB with validation and visual comparison
---

# Migration HAML → ERB

**Contexte :** Migration des templates HAML vers ERB pour le projet demarche.numerique.gouv.fr

**Version :** v5 - Learnings session screenshots Playwright (2026-03-14)

---

## Prérequis

**MCP Playwright** doit être configuré dans `.mcp.json` :
```json
{
  "mcpServers": {
    "playwright": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"]
    }
  }
}
```

**Serveur de dev** doit tourner (`rails server` sur `localhost:3000`).

**Authentification dev** : Un stash nommé `bypass auth` contient un hack `auto_sign_in_dev_user` dans `ApplicationController` qui crée et connecte automatiquement un utilisateur admin en dev. Pour l'appliquer :
```bash
# Trouver le stash
git stash list | grep "bypass auth"
# Appliquer (garder dans le stash pour réutilisation)
git stash apply stash@{N}
```
⚠️ Ne jamais commiter ce hack. Le re-stasher ou `git checkout` après les captures.

---

## Objectif

Convertir un batch de fichiers HAML en ERB en préservant le markup HTML, les classes CSS DSFR, et tous les attributs data-/aria-. Prouver l'équivalence visuelle avec des screenshots comparatifs HAML vs ERB.

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

### Étape 2 : Screenshot HAML — avant migration (10min)

**⚠️ OBLIGATOIRE — Capturer l'état visuel AVANT de modifier quoi que ce soit**

1. **Naviguer sur la page `/patron`** (page de démo des composants DSFR) :
   - Utiliser `browser_navigate` vers `http://localhost:3000/patron`
   - Requiert rôle administrateur → s'assurer que le stash "bypass auth" est appliqué (voir Prérequis)

2. **Capturer les screenshots HAML par sélecteur CSS** :
   - Utiliser `browser_run_code` avec `page.$$` (querySelectorAll) pour cibler chaque composant
   ```javascript
   async (page) => {
     const components = [
       { selector: '.fr-callout', name: 'callout' },
       { selector: '.fr-card', name: 'card' },
       { selector: '.fr-notice', name: 'notice' },
       { selector: '.fr-alert', name: 'alert' },
       { selector: '.fr-download', name: 'download' },
       { selector: '.fr-input-group', name: 'input' },
       { selector: '.fr-select-group', name: 'select' }
     ];
     for (const comp of components) {
       const elements = await page.$$(comp.selector);
       for (let i = 0; i < elements.length; i++) {
         await elements[i].screenshot({ path: `tmp/screenshots/haml/dsfr-${comp.name}-${i+1}.png` });
       }
     }
   }
   ```
   - Adapter les sélecteurs selon les composants migrés dans le batch

### Étape 3 : Conversion (20min)

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

**⚠️ Règles critiques (Phases 1.1 + 2.8a) :**

1. **Arrays de classes** : Si la méthode retourne un array, ajouter `.join(' ')`
2. **Pas de balises auto-fermantes** : `<input>` pas `<input />`
3. **Contrôler l'espacement** : Utiliser `<%-` et `-%>` pour supprimer newlines
4. **Guillemets** : Utiliser simples quotes `'` si tests sensibles
5. **String interpolation avec helpers HTML** :
   - ❌ `<%= "#{link_to('text', url)}." %>` (échappe le HTML)
   - ✅ `<%= link_to('text', url) %>.` (sortir le texte de l'interpolation)

### Étape 4 : Validation locale (15min)

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

4. **Diff visuel** :
   ```bash
   git diff app/components/nom/
   ```

### Étape 5 : Screenshot ERB — après migration (10min)

1. **Redémarrer le serveur Rails** (vider le cache de templates)

2. **Recharger la page dans MCP Playwright** :
   - Utiliser `browser_navigate` sur la même page que l'étape 2
   - Rails sert automatiquement le fichier ERB maintenant que le HAML est supprimé

3. **Capturer les screenshots ERB** avec le même script que l'étape 2, en changeant le path :
   - `tmp/screenshots/erb/dsfr-${comp.name}-${i+1}.png`

4. **Comparer** :
   - Comparer les tailles de fichiers (identique au byte = preuve forte)
   ```bash
   for f in tmp/screenshots/erb/*.png; do name=$(basename "$f"); haml_size=$(stat -f%z "tmp/screenshots/haml/$name"); erb_size=$(stat -f%z "$f"); [ "$haml_size" = "$erb_size" ] && echo "✅ $name" || echo "❌ $name"; done
   ```
   - Si différence détectée → investiguer et corriger avant de continuer

### Étape 6 : Commit + publication PR (10min)

**Seulement si validation locale + screenshots OK ✅**

1. Supprimer fichiers HAML :
   ```bash
   git rm app/**/*.haml
   ```

2. Commit :
   ```bash
   git commit --no-gpg-sign -m "refactor(haml): migrate [BATCH] to ERB"
   ```

3. **Publier screenshots dans la PR** :
   ```bash
   gh pr comment <PR_NUMBER> --body "$(cat <<'EOF'
   ## 📸 Validation Visuelle HAML → ERB

   ### Résumé
   - Composants migrés : X
   - Régressions visuelles : 0

   ### Comparaison

   #### [nom_composant]
   | HAML (avant) | ERB (après) |
   |--------------|-------------|
   | ![HAML](url) | ![ERB](url) |

   **Verdict :** ✅ Identique
   EOF
   )"
   ```

   **Note :** Pour inclure les images dans le commentaire PR, les uploader d'abord via l'interface GitHub (drag & drop) ou via `gh release create` pour obtenir les URLs.

---

## Checklist

- [ ] Batch sélectionné automatiquement (max 15 fichiers)
- [ ] Fichier HAML lu
- [ ] **Fichier Ruby lu (vérifier types de retour)**
- [ ] **📸 Screenshot HAML capturé (MCP Playwright)**
- [ ] Conversion complète
- [ ] Arrays avec `.join(' ')` si nécessaire
- [ ] Pas de balises auto-fermantes
- [ ] Espacement contrôlé (`<%-`, `-%>`)
- [ ] Pas d'interpolation de helpers HTML dans strings
- [ ] **Linter herb passé**
- [ ] **Tests passés (si identifiés)**
- [ ] Patterns à risque vérifiés (grep)
- [ ] Diff vérifié
- [ ] **📸 Screenshot ERB capturé (MCP Playwright)**
- [ ] **📸 Screenshots comparés — pas de régression visuelle**
- [ ] Fichiers HAML supprimés
- [ ] Commit créé
- [ ] **Screenshots publiés dans la PR**

---

## Évolution du Prompt

**Phase 1.1 :** 4 erreurs, 3 amends, score 3/10
**Phase 2.8a :** 1 erreur, 1 amend, score 8/10 (amélioration +75%)
**Phase 3.1 :** 0 erreur, score 9/10

**v5 intègre (learnings session screenshots 2026-03-14) :**
- Auth dev via stash `bypass auth` en prérequis
- Page `/patron` comme cible screenshots (composants DSFR en situation)
- `page.$$` (querySelectorAll) au lieu de `page.$` pour capturer tous les éléments
- Sélecteurs CSS des composants DSFR courants documentés
- Comparaison par taille de fichier (`stat -f%z`) = preuve forte
- Redémarrage serveur Rails obligatoire après changement de templates

**v4 intégrait :**
- Validation visuelle via MCP Playwright (screenshots HAML vs ERB)
- `git rm` au lieu de `rm` (learning Phase 3.1)
- 5 patterns critiques (Phase 1.1 + 2.8a)
- Sélection automatique batch (max 15 fichiers)
- Validation tests locaux si identifiés
- Vérification string interpolation helpers

Voir `essentials.md` pour les patterns détaillés.
