---
name: haml-migration
description: Migrate HAML templates to ERB with validation
---

# Migration HAML → ERB

**Contexte :** Migration des templates HAML vers ERB pour le projet demarche.numerique.gouv.fr

**Version :** v3 - Améliorée après Phase 2.8a (5 learnings critiques + autonomie)

---

## Objectif

Convertir un batch de fichiers HAML en ERB en préservant le markup HTML, les classes CSS DSFR, et tous les attributs data-/aria-.

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

### Étape 2 : Conversion (20min)

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
5. **⚠️ NOUVEAU - String interpolation avec helpers HTML** :
   - ❌ `<%= "#{link_to('text', url)}." %>` (échappe le HTML)
   - ✅ `<%= link_to('text', url) %>.` (sortir le texte de l'interpolation)

### Étape 3 : Validation locale (15min)

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

   # ⚠️ NOUVEAU - Vérifier string interpolation helpers
   grep '"#{.*link_to\|button_to\|form_' app/components/nom/nom.html.erb  # Doit être vide
   ```

4. **Diff visuel** :
   ```bash
   git diff app/components/nom/
   ```

### Étape 4 : Commit (5min)

**Seulement si linter + tests passent ✅**

1. Supprimer fichiers HAML :
   ```bash
   rm app/**/*.haml
   ```
   (Permission pré-approuvée pour `rm app/**/*.haml`)

2. Commit :
   ```bash
   git commit --no-gpg-sign -m "refactor(haml): migrate [BATCH] to ERB"
   ```

---

## Checklist

- [ ] Batch sélectionné automatiquement (max 15 fichiers)
- [ ] Fichier HAML lu
- [ ] **Fichier Ruby lu (vérifier types de retour)**
- [ ] Conversion complète
- [ ] Arrays avec `.join(' ')` si nécessaire
- [ ] Pas de balises auto-fermantes
- [ ] Espacement contrôlé (`<%-`, `-%>`)
- [ ] **⚠️ NOUVEAU - Pas d'interpolation de helpers HTML dans strings**
- [ ] **Linter herb passé**
- [ ] **Tests passés (si identifiés)**
- [ ] Patterns à risque vérifiés (grep)
- [ ] Diff vérifié
- [ ] Fichiers HAML supprimés
- [ ] Commit créé

---

## Évolution du Prompt

**Phase 1.1 :** 4 erreurs, 3 amends, score 3/10
**Phase 2.8a :** 1 erreur, 1 amend, score 8/10 (amélioration +75%)

**v3 intègre :**
- 5 patterns critiques (Phase 1.1 + 2.8a)
- Sélection automatique batch (max 15 fichiers)
- Validation tests locaux si identifiés
- Vérification string interpolation helpers

Voir `essentials.md` pour les patterns détaillés.
