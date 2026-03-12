# Essentials - Base de Connaissances Night Shift

**Objectif :** Capitaliser les patterns, commandes, et learnings critiques découverts durant les POCs

---

## Patterns de Conversion HAML → ERB

### ⚠️ Patterns Critiques (Phase 1.1)

Ces 4 patterns ont causé des erreurs en Phase 1.1 (12 fichiers, 4 erreurs, 3 amends, 23min CI perdues).

---

#### 🔴 Pattern 1 : Arrays de Classes

**Problème :** HAML gère automatiquement les arrays de classes, ERB non.

**HAML (auto-join) :**
```haml
%div{ class: callout_class }  # callout_class = ["fr-callout", "fr-bg-blue"]
```
Génère : `<div class="fr-callout fr-bg-blue">`

**ERB INCORRECT :**
```erb
<div class="<%= callout_class %>">
```
Génère : `<div class="[&quot;fr-callout&quot;, &quot;fr-bg-blue&quot;]">` ❌

**ERB CORRECT :**
```erb
<div class="<%= callout_class.join(' ') %>">
```
Génère : `<div class="fr-callout fr-bg-blue">` ✅

**Action :** Toujours lire le fichier Ruby du composant pour vérifier le type de retour.

---

#### 🔴 Pattern 2 : Balises Auto-fermantes HTML5

**Problème :** HAML génère du XHTML, le linter herb impose HTML5 strict.

**HAML :**
```haml
%input{ type: "checkbox" }/
```
Génère : `<input type="checkbox" />`

**ERB INCORRECT :**
```erb
<input type="checkbox" />
```
Erreur linter : `html-no-self-closing` ❌

**ERB CORRECT :**
```erb
<input type="checkbox">
```
✅ HTML5 valide

**Void elements :** `<input>`, `<br>`, `<img>`, `<hr>`, `<meta>`, `<link>`

---

#### 🔴 Pattern 3 : Espacement

**Problème :** ERB préserve l'indentation du fichier source, HAML compacte.

**ERB INCORRECT :**
```erb
<div>
  <% if condition %>
    <p>Text</p>
  <% end %>
</div>
```
Génère des espaces inutiles dans le HTML ❌

**ERB CORRECT :**
```erb
<div>
<% if condition -%>
<p>Text</p>
<% end -%>
</div>
```
✅ `-%>` supprime le newline après le tag

---

#### 🟡 Pattern 4 : Guillemets

**Problème :** HAML génère `class='...'` (simples), ERB génère `class="..."` (doubles).

**Impact :** Tests qui comparent le HTML exact échouent.

**Solution si nécessaire :**
```erb
<div class='<%= my_class %>'>  ← Simples quotes pour matcher HAML
```

---

## Commandes Utiles

### Git
```bash
git commit --no-gpg-sign -m "message"  # Désactiver GPG pour CI
git worktree add -b nom ../projet-nom main  # Créer worktree isolé
```

### Rails / Linters
```bash
bun lint:herb app/components/**/*.html.erb  # Linter HTML5
bundle exec rspec spec/path/to/test_spec.rb  # Tests spécifiques
grep -r "nom_composant" spec/  # Trouver tests d'un composant
```

---

## Checklist Validation Locale (OBLIGATOIRE)

**⚠️ Ne JAMAIS commiter sans ces vérifications** (Phase 1.1 : 23min perdues)

```bash
# 1. Linter herb
bun lint:herb app/components/**/*.html.erb

# 2. Tests concernés
bundle exec rspec spec/path/

# 3. Vérifier patterns à risque
grep '/>' app/components/**/*.html.erb  # Doit être vide
grep 'class=' app/components/**/*.html.erb  # Vérifier .join si array

# 4. Diff visuel
git diff app/components/
```

---

## Hypothèses Validées / Invalidées

### Phase 1.1 (HAML→ERB)

**❌ Invalidées :**
- La conversion HAML → ERB peut être faite automatiquement sans erreur
- Le markup HTML reste identique
- Les tests passent après migration sans vérification locale
- L'IA peut migrer sans validation locale

**✅ Validées :**
- La documentation des erreurs permet d'améliorer le prompt
- Les composants simples (< 50 lignes) se migrent en ~1-2min
- Le linter peut détecter certaines erreurs (balises auto-fermantes)

---
