---
name: haml-migration
description: Migrate HAML templates to ERB with validation and visual comparison
---

# Migration HAML → ERB

**Contexte :** Migration des templates HAML vers ERB pour le projet demarche.numerique.gouv.fr

**Version :** v7 - Touch .rb + MCP CLI + isVisible filter (2026-03-15)

---

## Prérequis

**MCP Playwright** doit être enregistré via la CLI (le `.mcp.json` seul n'est PAS détecté par Claude Code) :
```bash
claude mcp add playwright -- npx -y @playwright/mcp@latest
# Le -- est obligatoire pour séparer les args
# Relancer Claude Code après ajout (/exit puis claude)
```

**Serveur de dev** doit tourner (`rails server` sur `localhost:3000`).

**Stash `haml-migration-adapter`** : Contient 2 fichiers indispensables :
1. **`app/controllers/application_controller.rb`** — auto-login dev (bypass auth)
2. **`config/initializers/view_component_dev_reload.rb`** — invalidation cache ViewComponent (plus besoin de redémarrer le serveur après switch .haml → .erb)

```bash
# Trouver le stash
git stash list | grep "haml-migration-adapter"
# Appliquer (garder dans le stash pour réutilisation)
git stash apply stash@{N}
# Redémarrer le serveur UNE fois pour charger l'initializer
# Ensuite, plus jamais de redémarrage pour les changements de templates
```
⚠️ Ne jamais commiter ces fichiers. Les re-stasher ou `git checkout` après les captures.

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

**Évaluer la complexité de capture pour chaque composant :**

| Niveau | Critère | Action |
|---|---|---|
| **Simple** | Visible sur `/patron` ou page accessible directement | Screenshot automatique |
| **Moyen** | Nécessite navigation + auth mais pas de données spécifiques | Screenshot avec bypass auth |
| **Complexe** | Nécessite données spécifiques, interactions (modal, dropdown), ou aucune page standard | **Skip → validation manuelle** |

**Si Complexe** : ne pas perdre de temps (seuil : > 5min de setup par composant). Documenter dans la PR : "Composant X : screenshot skippé (raison), à valider manuellement par le reviewer."

**Si Simple ou Moyen** : capturer l'état visuel AVANT de modifier quoi que ce soit.

1. **Identifier les pages qui affichent les composants du batch** :
   - Utiliser `/patron` pour les composants DSFR courants (couvre ~10/12)
   - Pour les composants absents de `/patron`, chercher dans les pages réelles (admin, instructeur, usager)
   - **Préférer les pages réelles** = preuve plus forte que `/patron` isolé
   ```bash
   grep -r "NomDuComposant\|render.*nom_du_composant" app/views/ app/components/
   ```

   **Mapping composants DSFR connus :**

   | Composant | Page | Sélecteur CSS |
   |---|---|---|
   | AlertComponent | `/patron` | `.fr-alert` |
   | CalloutComponent | `/patron` | `.fr-callout` |
   | CardVerticalComponent | `/patron` | `.fr-card` |
   | NoticeComponent | `/patron` | `.fr-notice` |
   | DownloadComponent | `/patron` (si attachment) | `.fr-download` |
   | InputComponent | `/patron` (formulaire) | `.fr-input-group` |
   | RadioButtonListComponent | `/patron` (formulaire) | `.fr-fieldset .fr-radio-group` |
   | ToggleComponent | `/patron` (formulaire) | `.fr-toggle` |
   | CopyButtonComponent | page admin | `.fr-btn.fr-icon-clipboard-line` |
   | SidemenuComponent | page instructeur | `.fr-sidemenu` |

2. **Naviguer avec MCP Playwright** :
   - Utiliser `browser_navigate` vers la page identifiée
   - S'assurer que le stash `haml-migration-adapter` est appliqué (voir Prérequis)

3. **Capturer les screenshots HAML par sélecteur CSS** :
   - Utiliser `browser_run_code` avec `page.$$` (querySelectorAll) pour cibler chaque composant
   ```javascript
   async (page) => {
     const components = [
       { selector: '.fr-callout', name: 'callout' },
       { selector: '.fr-card', name: 'card' },
       { selector: '.fr-notice', name: 'notice' }
       // Adapter selon le batch
     ];
     for (const comp of components) {
       const elements = await page.$$(comp.selector);
       for (let i = 0; i < elements.length; i++) {
         // ⚠️ Toujours vérifier isVisible() — des éléments hidden causent un timeout
         if (await elements[i].isVisible()) {
           await elements[i].screenshot({ path: `tmp/screenshots/haml/dsfr-${comp.name}-${i+1}.png` });
         }
       }
     }
   }
   ```

4. **Commiter les screenshots HAML** (preuve de l'état avant migration) :
   ```bash
   git add tmp/screenshots/haml/
   git commit --no-gpg-sign -m "chore(haml): capture screenshots HAML avant migration [BATCH]"
   ```

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

1. **Supprimer les fichiers `.haml` et ajouter les `.erb`**
   - ⚠️ **ViewComponent refuse la coexistence `.haml` + `.erb`** → `TemplateError: More than one HTML template found`
   - Le switch est atomique : supprimer le `.haml` AVANT de pouvoir servir le `.erb`

2. **Forcer le reload du cache ViewComponent** :
   - ⚠️ `config.to_prepare` ne se déclenche que sur les changements de fichiers `.rb` surveillés — supprimer/ajouter des `.haml`/`.erb` ne déclenche PAS le reload
   - **Fix obligatoire** : après suppression des `.haml`, toucher le `.rb` de chaque composant migré :
   ```bash
   touch app/components/dsfr/nom_component.rb
   ```
   - Alternative si le stash `haml-migration-adapter` est appliqué : l'initializer aide, mais le `touch` reste nécessaire pour garantir l'invalidation

3. **Naviguer sur les mêmes pages que l'étape 2** avec MCP Playwright

4. **Capturer les screenshots ERB** avec le même script que l'étape 2, en changeant le path :
   - `tmp/screenshots/erb/dsfr-${comp.name}-${i+1}.png`

4. **Comparer** :
   - Comparer les tailles de fichiers (identique au byte = preuve forte)
   ```bash
   for f in tmp/screenshots/erb/*.png; do name=$(basename "$f"); haml_size=$(stat -f%z "tmp/screenshots/haml/$name"); erb_size=$(stat -f%z "$f"); [ "$haml_size" = "$erb_size" ] && echo "✅ $name" || echo "❌ $name"; done
   ```
   - Si différence détectée → investiguer et corriger avant de continuer

5. **Commiter les screenshots ERB** (preuve de l'état après migration) :
   ```bash
   git add tmp/screenshots/erb/
   git commit --no-gpg-sign -m "chore(haml): capture screenshots ERB après migration [BATCH]"
   ```

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

4. **Supprimer les screenshots avant merge** (ne pas polluer le repo) :
   ```bash
   git rm -r tmp/screenshots/haml/ tmp/screenshots/erb/
   git commit --no-gpg-sign -m "chore(haml): remove screenshots after visual validation [BATCH]"
   ```

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

**v7 intègre (iteration 4 — crash-proof 2026-03-15) :**
- MCP Playwright via `claude mcp add` (`.mcp.json` seul non détecté par Claude Code)
- `touch *.rb` après suppression `.haml` pour forcer invalidation cache ViewComponent (`config.to_prepare` ne détecte pas les changements .haml/.erb)
- Filtre `isVisible()` avant screenshot (éléments hidden = timeout)
- Auth dev via `letter_opener` pour valider trusted device

**v6 intégrait (fix cache ViewComponent 2026-03-14) :**
- Stash `haml-migration-adapter` remplace `bypass auth` (inclut bypass auth + initializer cache ViewComponent)
- Plus de redémarrage serveur après switch .haml → .erb (initializer `view_component_dev_reload.rb` invalide le cache via `config.to_prepare`)
- Fix API ViewComponent 4.1.0 : `klass.compiler` → `klass.instance_variable_get(:@__vc_compiler)`

**v5 intégrait :**
- Auth dev via stash `bypass auth` en prérequis
- Page `/patron` comme cible screenshots (composants DSFR en situation)
- `page.$$` (querySelectorAll) au lieu de `page.$` pour capturer tous les éléments
- Sélecteurs CSS des composants DSFR courants documentés
- Comparaison par taille de fichier (`stat -f%z`) = preuve forte
- Redémarrage serveur Rails obligatoire après changement de templates (corrigé en v6)

**v4 intégrait :**
- Validation visuelle via MCP Playwright (screenshots HAML vs ERB)
- `git rm` au lieu de `rm` (learning Phase 3.1)
- 5 patterns critiques (Phase 1.1 + 2.8a)
- Sélection automatique batch (max 15 fichiers)
- Validation tests locaux si identifiés
- Vérification string interpolation helpers

Voir `essentials.md` pour les patterns détaillés.
