# Prompt : Migration HAML → ERB

**Contexte :** Migration des templates HAML vers ERB pour le projet demarche.numerique.gouv.fr

**Version :** Améliorée après Phase 1.1 (4 learnings critiques intégrés)

---

## Objectif

Convertir un batch de fichiers HAML en ERB en préservant le markup HTML, les classes CSS DSFR, et tous les attributs data-/aria-.

---

## Workflow (50min, batch max 5 fichiers)

### Étape 1 : Analyse complète (10min)

**⚠️ CRITIQUE :** Lire le HAML ET le fichier Ruby

1. Lire le fichier HAML : `app/components/nom/nom.html.haml`
2. **Lire le fichier Ruby : `app/components/nom/nom.rb`**
3. Identifier les méthodes utilisées dans le template :
   - Si retourne `Array` → utiliser `.join(' ')` en ERB
   - Si retourne `String` → utiliser directement
   - Si retourne `Hash` → utiliser `tag.attributes(**method)`
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

**⚠️ Règles critiques (Phase 1.1) :**

1. **Arrays de classes** : Si la méthode retourne un array, ajouter `.join(' ')`
2. **Pas de balises auto-fermantes** : `<input>` pas `<input />`
3. **Contrôler l'espacement** : Utiliser `<%-` et `-%>` pour supprimer newlines
4. **Guillemets** : Utiliser simples quotes `'` si tests sensibles

### Étape 3 : Validation locale (15min)

**⚠️ OBLIGATOIRE - Ne JAMAIS skip cette étape**

1. **Linter herb** :
   ```bash
   bun lint:herb app/components/nom/nom.html.erb
   ```

2. **Tests locaux** :
   ```bash
   bundle exec rspec spec/path/to/test_spec.rb
   ```

3. **Vérifier patterns à risque** :
   ```bash
   # Pas de balises auto-fermantes
   grep '/>' app/components/nom/nom.html.erb  # Doit être vide

   # Vérifier arrays
   grep 'class=' app/components/nom/nom.html.erb
   ```

4. **Diff visuel** :
   ```bash
   git diff app/components/nom/
   ```

### Étape 4 : Commit (5min)

**Seulement si linter + tests passent ✅**

1. Supprimer fichiers HAML
2. Commit :
   ```bash
   git commit --no-gpg-sign -m "refactor(haml): migrate [BATCH] to ERB"
   ```

---

## Checklist

- [ ] Fichier HAML lu
- [ ] **Fichier Ruby lu (vérifier types de retour)**
- [ ] Conversion complète
- [ ] Arrays avec `.join(' ')` si nécessaire
- [ ] Pas de balises auto-fermantes
- [ ] Espacement contrôlé (`<%-`, `-%>`)
- [ ] **Linter herb passé**
- [ ] **Tests passés**
- [ ] Diff vérifié
- [ ] Commit créé

---

## Learnings Phase 1.1

**4 erreurs découvertes sur 12 fichiers, 3 amends, 23min CI perdues.**

Ce prompt intègre ces learnings pour éviter les mêmes erreurs.

Voir `essentials.md` pour les patterns détaillés.
