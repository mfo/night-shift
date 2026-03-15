# Kaizen - Itération 2 : Stratégie screenshots & découvertes techniques

**Date :** 2026-03-14
**Tâche :** Améliorer le workflow de capture screenshots HAML vs ERB
**PR :** [#12760](https://github.com/demarche-numerique/demarche.numerique.gouv.fr/pull/12760)
**Branch :** `poc-haml-migration`
**Status :** ⏸️ EN PAUSE — en attente de remontée de base

---

## 🎯 Objectif vs Résultat

**Objectif :**
- Capturer les 12 composants DSFR (pas seulement 3)
- Résoudre le problème de redémarrage serveur
- Trouver un workflow fiable pour les screenshots avant/après

**Résultat :**
- ✅ Identifié la cause du cache ViewComponent (investigation profonde)
- ✅ Tenté un initializer pour invalider le cache → insuffisant
- ✅ Découvert que ViewComponent refuse la coexistence `.haml` + `.erb`
- ✅ Tenté d'enrichir `/patron` avec les 7 composants manquants → fonctionnel
- ✅ Capturé 19 screenshots HAML (10 composants avec variantes)
- ❌ Changement de stratégie : ne pas modifier `/patron`, utiliser les pages existantes
- ✅ Analyse complète des 12 composants : où les trouver dans l'app

---

## ✅ Ce Qui a Bien Marché

1. **Capture par sélecteur CSS**
   - Script Playwright réutilisable pour cibler chaque composant
   - Fonctionne avec sélecteurs standards (`.fr-alert`, `.fr-callout`, etc.)
   - Workaround pour composants sans classe spécifique (ListComponent → `h1` + `nextElementSibling`)

2. **Investigation ViewComponent cache**
   - Root cause identifié : `Compiler#@templates` memoization persiste across reloads
   - `CompileCache.invalidate!` ne suffit pas (ne reset pas `@templates`)
   - Créé `config/initializers/view_component_dev_reload.rb` avec `ObjectSpace.each_object`

3. **Analyse exhaustive des pages par composant**
   - Mapping complet : composant → pages → rôle requis → données nécessaires
   - `/patron` couvre 10/12 composants sans données spécifiques

---

## ⚠️ Ce Qui a Coincé

### 1. **ViewComponent refuse la coexistence .haml + .erb (BLOQUANT)**

**Erreur :** `ViewComponent::TemplateError: More than one HTML template found`

**Impact :** Impossible de garder les deux fichiers côte à côte pour éviter le redémarrage.

**Conséquence :** Il FAUT redémarrer le serveur après suppression des `.haml`. Pas de workaround.

### 2. **L'initializer `view_component_dev_reload.rb` ne suffit pas**

**Cause :** L'initializer s'exécute au boot (`to_prepare`), mais le cache se reconstruit immédiatement au premier render. Si les `.haml` sont supprimés APRÈS le boot, le cache pointe toujours vers les anciens fichiers.

**Learning :** Le cache ViewComponent est un problème de process, pas de configuration.

### 3. **Modifier `/patron` n'est pas la bonne approche**

**Problème :** Ajouter des composants à `/patron` pollue la page de style guide.

**Feedback utilisateur :** "Il ne faut pas modifier patron pour tester les composants, mais trouver un point dans l'application pour effectuer ces captures d'écran."

**Learning :** Utiliser les pages existantes de l'app = preuve plus forte que le composant fonctionne en situation réelle.

### 4. **Approche deux serveurs (ports 3000/3001)**

**Idée utilisateur :** Lancer le serveur HAML sur port 3000 et ERB sur 3001.

**Problème :** La branche HAML n'a pas les modifications de `/patron`.

**Abandon :** Retour à l'approche séquentielle avec redémarrage.

---

## 📊 Métriques

**Score : 5/10**
- ✅ Bonne investigation technique
- ✅ Bons screenshots HAML capturés
- ❌ Pas de screenshots ERB finaux
- ❌ Trop de temps sur des impasses (coexistence, initializer, patron modifié)
- ❌ Changement de stratégie en cours de route

**Temps total :** ~1h30
**Temps en impasses :** ~45min (coexistence, initializer, patron enrichi puis revert)

---

## 💡 Learnings Clés

### 1. **ViewComponent = 1 template par composant, point final**
- `.haml` + `.erb` côte à côte → `TemplateError`
- Pas de coexistence possible → le switch est atomique
- Implique un redémarrage serveur obligatoire

### 2. **Ne pas modifier la page de style guide pour les tests**
- Utiliser les pages réelles de l'app
- Preuve plus forte : le composant fonctionne en contexte réel
- Moins de code à maintenir/reverter

### 3. **`/patron` couvre déjà 10/12 composants nativement**
- AlertComponent, CalloutComponent, CardVerticalComponent, NoticeComponent → section DSFR
- InputComponent, RadioButtonListComponent, ToggleComponent → section Formulaires
- CopyButtonComponent, ListComponent, SidemenuComponent → ajoutés mais revertés
- DownloadComponent → conditionnel (`ActiveStorage::Attachment.last`)
- InputStatusMessageComponent → rendu dans les champs du formulaire

### 4. **Le stash "bypass auth" fonctionne bien**
- `find_or_initialize_by` + `Administrateur.create!` + `sign_in(user, scope: :user)`
- Mot de passe complexe obligatoire : `Ds-P@ssw0rd!2026`
- `prepend_before_action` nécessaire

### 5. **Stratégie finale : pages réelles + redémarrage unique**
- Capturer HAML sur les pages existantes (serveur en état HAML)
- Supprimer `.haml`, ajouter `.erb`, redémarrer UNE fois
- Recapturer ERB sur les mêmes pages
- Comparer par taille de fichier

---

## 🔄 Plan pour la prochaine session

### Prérequis
- [ ] Base de données remontée
- [ ] Stash "bypass auth" disponible

### Workflow
1. Appliquer stash "bypass auth"
2. Naviguer sur `/patron` (qui auto-crée la procédure de démo)
3. Capturer screenshots HAML des composants visibles sur `/patron`
4. Pour les composants absents de `/patron`, chercher dans les pages admin/instructeur
5. Supprimer les `.haml`, ajouter les `.erb`
6. Redémarrer le serveur (une seule fois)
7. Recapturer screenshots ERB sur les mêmes pages
8. Comparer → publier sur PR

### Composants et leurs pages

| Composant | Page | Sélecteur CSS |
|---|---|---|
| AlertComponent | `/patron` | `.fr-alert` |
| CalloutComponent | `/patron` | `.fr-callout` |
| CardVerticalComponent | `/patron` | `.fr-card` |
| NoticeComponent | `/patron` | `.fr-notice` |
| CopyButtonComponent | à trouver (admin procedure confirmation?) | `.fr-btn.fr-icon-clipboard-line` |
| DownloadComponent | `/patron` (si attachment existe) | `.fr-download` |
| InputComponent | `/patron` (formulaire) | `.fr-input-group` |
| InputStatusMessageComponent | `/patron` (formulaire) | à déterminer |
| ListComponent | à trouver (admin revision?) | `ul` après h1 |
| RadioButtonListComponent | `/patron` (formulaire) | `.fr-fieldset .fr-radio-group` |
| SidemenuComponent | à trouver (instructeur avis?) | `.fr-sidemenu` |
| ToggleComponent | `/patron` (formulaire) | `.fr-toggle` |

---

## 📝 Fichiers créés/modifiés cette session

- `config/initializers/view_component_dev_reload.rb` — créé (non commité, à garder pour le dev)
- `app/views/root/patron.html.haml` — modifié puis revert
- `tmp/screenshots/haml/*.png` — 19 screenshots (à refaire)
