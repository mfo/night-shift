# POC 1 : Migration HAML → ERB - Setup

**Date :** 2026-03-08
**Objectif :** Valider que Claude peut migrer HAML → ERB en mode fire-and-forget

---

## Setup

### Worktree Créé

```bash
cd ../demarche.numerique.gouv.fr
git worktree add -b poc-haml-migration ../demarche.numerique.gouv.fr-poc-haml main
```

**Localisation :** `/Users/mfo/dev/demarche.numerique.gouv.fr-poc-haml`
**Branche :** `poc-haml-migration`

### Fichier Choisi

**Fichier :** `app/views/release_notes/_announce.html.haml`
**Taille :** 10 lignes
**Complexité :** SIMPLE

**Contenu actuel :**
```haml
.fr-mb-4w
  %h3= l(notes[0].released_on, format: :long)

  - notes.each do |note|
    .fr-mb-4w.fr-px-2w.fr-py-2w.fr-background-alt--grey{ data: { turbo: "false" } }
      %p
        - note.categories.each do |category|
          = announce_category_badge(category)

      = render_release_note_content(note.body)
```

**Caractéristiques :**
- Classes DSFR (Design System FR)
- Itérations Ruby (`each`)
- Helpers Rails (`l()`, `announce_category_badge()`, `render_release_note_content()`)
- Data attributes (`data: { turbo: "false" }`)

**Tests associés :**
À vérifier : `spec/system/release_notes_spec.rb` ou similaire

---

## Prompt Minimal pour Claude

```markdown
# Tâche : Migrer 1 fichier HAML → ERB

## Contexte
Tu es dans le worktree : /Users/mfo/dev/demarche.numerique.gouv.fr-poc-haml

## Fichier à migrer
app/views/release_notes/_announce.html.haml (10 lignes)

## Instructions

### Étape 1 : Lire le fichier HAML (5min)
1. Lis le fichier actuel
2. Comprends la structure (divs, iterations, helpers)

### Étape 2 : Identifier les tests (10min)
1. Cherche les tests system specs qui utilisent ce partial
   ```bash
   grep -r "_announce" spec/system/
   grep -r "release_notes" spec/system/
   ```

2. Si tu trouves des tests, lance-les AVANT migration :
   ```bash
   bundle exec rspec spec/system/[fichier_trouve]
   ```

3. Note le résultat (PASS/FAIL)

### Étape 3 : Convertir HAML → ERB (15min)
1. Convertis le fichier en respectant ces règles :

   **Règle 1 : Markup HTML identique**
   ```haml
   .fr-mb-4w
   %h3= content
   ```

   Devient :
   ```erb
   <div class="fr-mb-4w">
     <h3><%= content %></h3>
   </div>
   ```

   **Règle 2 : Itérations Ruby**
   ```haml
   - items.each do |item|
     %p= item.name
   ```

   Devient :
   ```erb
   <% items.each do |item| %>
     <p><%= item.name %></p>
   <% end %>
   ```

   **Règle 3 : Attributs HTML**
   ```haml
   .class-name{ data: { turbo: "false" } }
   ```

   Devient :
   ```erb
   <div class="class-name" data-turbo="false">
   </div>
   ```

2. Crée le nouveau fichier : `app/views/release_notes/_announce.html.erb`

3. Supprime l'ancien : `app/views/release_notes/_announce.html.haml`

### Étape 4 : Vérifier (10min)
1. Lance les tests (si trouvés à l'étape 2) :
   ```bash
   bundle exec rspec spec/system/[fichier]
   ```

2. Vérifie que les tests passent (même résultat qu'AVANT)

3. Vérifie visuellement le diff :
   ```bash
   git diff app/views/release_notes/
   ```

### Étape 5 : Rapport (5min)
Écris un résumé (5-10 lignes) :

**Format :**
```markdown
## Résumé Migration HAML → ERB

**Fichier :** app/views/release_notes/_announce.html.haml → .html.erb
**Taille :** 10 lignes
**Tests trouvés :** [OUI/NON] - [nom fichier spec]
**Tests status :**
- Avant migration : [PASS/FAIL/PAS DE TESTS]
- Après migration : [PASS/FAIL/PAS DE TESTS]

**Changements :**
- Conversions effectuées : [syntaxe HAML → ERB]
- Markup HTML : [IDENTIQUE/DIFFÉRENT]
- Attributs data : [CONSERVÉS/MODIFIÉS]

**Problèmes rencontrés :** [AUCUN / liste]

**Commit :**
git add app/views/release_notes/
git commit -m "Migrate release_notes/_announce from HAML to ERB"
```

## Contraintes IMPORTANTES

**✅ AUTORISÉ (fais-le sans demander) :**
- Lire les fichiers
- Lancer les tests
- Convertir HAML → ERB
- Créer le fichier .erb
- Supprimer le fichier .haml
- Commit les changements

**❌ INTERDIT :**
- Modifier le markup HTML (doit rester identique)
- Modifier la logique Ruby (iterations, helpers)
- Changer les classes CSS
- Changer les attributs data

**⚠️ SI PROBLÈME :**
- Tests échouent après migration → explique pourquoi dans le rapport
- Tu ne trouves pas de tests → mentionne-le dans le rapport
- Tu bloques > 30min → arrête et explique où tu bloques

## Time Budget
**Total : 45min max**
- Lecture : 5min
- Tests : 10min
- Conversion : 15min
- Vérification : 10min
- Rapport : 5min

Si tu dépasses 45min → arrête et dis pourquoi.

Bonne chance ! 🚀
```

---

## Critères de Succès POC

**Ce POC est réussi si :**
- [ ] Claude comprend la tâche sans questions de clarification
- [ ] Migration effectuée correctement (markup identique)
- [ ] Tests passent (ou aucun test n'existe)
- [ ] Temps < 45min
- [ ] Rapport clair et actionnable
- [ ] Pas besoin d'intervenir pendant l'exécution

**Ce POC est partiellement réussi si :**
- [ ] Migration correcte mais > 45min
- [ ] 1-2 questions de clarification nécessaires
- [ ] Tests passent mais quelques ajustements manuels

**Ce POC échoue si :**
- [ ] Markup HTML modifié
- [ ] Tests échouent
- [ ] > 3 questions de clarification
- [ ] Bloqué > 1h
- [ ] Nécessite supervision constante

---

## Prochaines Étapes

**Une fois ce fichier créé :**
1. Ouvrir nouveau terminal dans le worktree POC
2. Lancer Claude
3. Lui donner le prompt ci-dessus
4. Observer sans intervenir (sauf si bloqué > 30min)
5. Noter le temps écoulé
6. Noter les questions posées
7. Review le résultat
8. Documenter dans `learnings/poc-1-haml-migration-results.md`

---

*Setup créé le : 2026-03-08 18:35*
