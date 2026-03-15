# Reprise Migration HAML → ERB

**Dernière session :** 2026-03-14
**Branch :** `poc-haml-migration`
**PR :** [#12760](https://github.com/demarche-numerique/demarche.numerique.gouv.fr/pull/12760)

---

## État actuel

### Git
- **HEAD :** `7977f9fedb` (propre, aucune migration commitée sur cette branche)
- **Branch backup :** `poc-haml-migration-backup` contient les 3 commits de migration (Phases 1.1, 2.8a, 3.1)
- **Working tree :** propre (aucun changement non commité)

### Stash
- **`stash@{0}` — `haml-migration-adapter`** : contient les 2 fichiers d'outillage dev :
  - `app/controllers/application_controller.rb` — auto-login admin en dev (bypass auth pour Playwright)
  - `config/initializers/view_component_dev_reload.rb` — fix cache ViewComponent (plus de redémarrage serveur)
- **`stash@{4}`** : ancien stash avec les 3 phases de migration (Phase 1.1 + 2.8a + 3.1 mélangées)

### PR #12760
- Description mise à jour avec des placeholders pour screenshots (à remplacer via drag & drop GitHub)
- Demande de colinux : fournir des screenshots comparatifs HAML vs ERB

---

## Ce qui reste à faire

### 1. Remonter la base de données
- La base locale a été supprimée → `bin/setup` ou restore dump
- Nécessaire pour que `/patron` fonctionne (auto-crée une procédure de démo)

### 2. Capturer les screenshots HAML (avant migration)
- Appliquer le stash adapter : `git stash apply stash@{0}`
- Redémarrer le serveur UNE fois (pour charger l'initializer)
- Naviguer sur `/patron` avec MCP Playwright
- Capturer chaque composant par sélecteur CSS :

| Composant | Sélecteur CSS | Présent sur /patron |
|---|---|---|
| AlertComponent | `.fr-alert` | ❌ non (à trouver ailleurs ou ajouter) |
| CalloutComponent | `.fr-callout` | ✅ oui (×4) |
| CardVerticalComponent | `.fr-card` | ✅ oui (×2) |
| CopyButtonComponent | `.fr-btn.fr-icon-clipboard-line` | ❌ non |
| DownloadComponent | `.fr-download` | conditionnel (si attachment en base) |
| InputComponent | `.fr-input-group` | ✅ oui (dans le formulaire) |
| InputStatusMessageComponent | n/a | ✅ dans le formulaire (si champs SIRET/RNA) |
| ListComponent | `ul` après h1 | ❌ non |
| NoticeComponent | `.fr-notice` | ✅ oui (×2) |
| RadioButtonListComponent | `.fr-fieldset .fr-radio-group` | ✅ oui (dans le formulaire) |
| SidemenuComponent | `.fr-sidemenu` | ❌ non |
| ToggleComponent | `.fr-toggle` | ✅ oui (dans le formulaire) |

**Option A :** Capturer les 7 composants disponibles sur `/patron`, documenter les 5 manquants
**Option B :** Trouver d'autres pages pour les 5 manquants (voir analyse dans kaizen itération 2)
**Option C :** Ajouter les composants manquants à `/patron` (rejeté — ne pas modifier patron)

### 3. Appliquer la migration Phase 1.1 (12 composants DSFR)
- Récupérer les fichiers `.erb` depuis la branche backup :
  ```bash
  git checkout poc-haml-migration-backup -- app/components/dsfr/*/alert_component.html.erb ...
  ```
- Ou recréer depuis le stash@{4} en isolant uniquement les fichiers DSFR
- Supprimer les `.haml` correspondants avec `git rm`
- Grâce à l'initializer corrigé, **pas de redémarrage serveur nécessaire**

### 4. Capturer les screenshots ERB (après migration)
- Même script Playwright, même pages, path `tmp/screenshots/erb/`
- Comparer par taille de fichier (`stat -f%z`)

### 5. Publier sur la PR
- Uploader les screenshots via drag & drop sur GitHub
- Remplacer les placeholders dans la description PR
- Commiter la migration Phase 1.1

---

## Outillage disponible

### Stash `haml-migration-adapter`
```bash
git stash apply stash@{0}
# Puis redémarrer le serveur UNE fois
```

Contient :
- **Auto-login dev** : crée automatiquement un user admin et le connecte (Devise)
- **Cache fix** : invalide le cache ViewComponent à chaque requête en dev

### MCP Playwright
⚠️ Le `.mcp.json` seul n'est PAS détecté par Claude Code. Enregistrer via la CLI :
```bash
claude mcp add playwright -- npx -y @playwright/mcp@latest
# Relancer Claude Code après ajout (/exit puis claude)
```

Script de capture :
```javascript
async (page) => {
  const components = [
    { selector: '.fr-callout', name: 'callout' },
    { selector: '.fr-card', name: 'card' },
    // ...
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

### Kaizen
- `iteration-2/kaizen-2026-03-14-screenshots-playwright.md` — learnings Playwright + auth
- `iteration-2/kaizen-2026-03-14-iteration-2-strategy.md` — changement de stratégie screenshots
- `iteration-3/kaizen-2026-03-14-iteration-3-viewcomponent-cache-fix.md` — fix cache ViewComponent
- `iteration-4/2026-03-15-phase-1.1-dsfr-migration.md` — crash-proof (touch .rb, MCP CLI, isVisible)

---

## Découvertes techniques clés

1. **ViewComponent refuse la coexistence `.haml` + `.erb`** → `TemplateError: More than one HTML template found`
2. **L'initializer de cache était cassé** : `klass.compiler` n'existe plus en v4.1.0, remplacé par `@__vc_compiler`
3. **`sign_in(user, scope: :user)`** obligatoire avec Devise multi-rôle
4. **`/patron` requiert le rôle administrateur** (`authenticate_administrateur!` dans `RootController`)
5. **Mot de passe dev doit être complexe** : validation custom rejette les mots de passe simples
