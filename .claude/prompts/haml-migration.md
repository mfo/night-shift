# Prompt : Migration HAML → ERB

**Contexte :** Migration des templates HAML vers ERB pour le projet demarche.numerique.gouv.fr

---

## Objectif

Convertir un batch de fichiers HAML en ERB en préservant le markup HTML, les classes CSS DSFR, et tous les attributs data-/aria-.

---

## Workflow (45min)

### Étape 1 : Lire le fichier HAML (5min)

1. Lire le fichier HAML : `app/components/nom/nom.html.haml`
2. Comprendre la structure (divs, itérations, helpers)
3. Rechercher les tests :
   ```bash
   grep -r "nom_du_composant" spec/
   ```

### Étape 2 : Conversion (25min)

**Règles de conversion :**

```haml
%div.class-name          →  <div class="class-name">
  = content              →    <%= content %>
                         →  </div>

- if condition           →  <% if condition %>
  = content              →    <%= content %>
                         →  <% end %>

%div{ class: my_class }  →  <div class="<%= my_class %>">

%div{ **options }        →  <div <%= tag.attributes(**options) %>>
```

### Étape 3 : Vérification (10min)

1. Vérifier le diff :
   ```bash
   git diff app/components/nom/
   ```

2. Vérifier que le markup reste cohérent

### Étape 4 : Commit (5min)

1. Supprimer fichiers HAML
2. Commit :
   ```bash
   git commit -m "refactor(haml): migrate [BATCH] to ERB"
   ```

---

## Checklist

- [ ] Fichiers HAML lus
- [ ] Conversion complète
- [ ] Diff vérifié
- [ ] Commit créé
