---
name: i18n-hardcoded
description: "Extract hardcoded French strings to i18n YAML. Use when user says 'extract i18n', 'translate hardcoded', or provides a .rb/.erb file with French text."
allowed-tools: Bash(git status:*), Bash(git add:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Bash(grep:*), Bash(bundle exec rspec:*), Bash(bundle exec rubocop:*), Bash(bundle exec rake lint:apostrophe:fix), Bash(echo:*), Bash(stat:*), Bash(touch:*), Bash(.claude/skills/screenshot-gist/create-gist.sh:*), Bash(bash .claude/skills/screenshot-gist/create-gist.sh:*), Bash(.claude/skills/screenshot-gist/push-gist.sh:*), Bash(bash .claude/skills/screenshot-gist/push-gist.sh:*), Bash(cp:*), Bash(ls:*), Edit(app/*), Edit(spec/*), Edit(config/*), Write(app/*), Write(spec/*), Write(config/*), Write(pr-description.md), mcp__playwright__browser_navigate, mcp__playwright__browser_run_code, mcp__playwright__browser_take_screenshot, mcp__playwright__browser_resize, mcp__playwright__browser_close
---

# Extraction i18n : textes francais hardcodes

**Contexte :** Extraire les textes francais en dur d'un fichier Ruby ou ERB vers les fichiers YAML i18n.

**Input :**
- Fichier a traiter : `$ARGUMENTS` (ex: `app/mailers/user_mailer.rb`)
- Scope : francais uniquement (v1)

**Regles Bash** : memes regles que haml-migration :
- Pas de `$()` (command substitution)
- Pas de `;` ou `&&` pour chainer
- Pas de pipes complexes
- 1 commande simple = 1 appel Bash
- Ne JAMAIS utiliser `git -C` — le working directory est deja le repo cible

---

## Setup (avant le workflow)

**1. Serveur** — verifier que le serveur tourne (`.overmind.sock` ou process Rails).

**2. Auto-login** — verifier :
```bash
grep auto_sign_in_dev_user config/initializers/dev_auto_login.rb
```
Si absent → appliquer le skill `/dev-auto-login`.

**3. Playwright** — naviguer sur `localhost:$PORT` pour verifier que Playwright fonctionne. Si Chrome est deja ouvert → demander a l'utilisateur de le fermer.

**4. Viewport** — toujours appeler `browser_resize` (1280x800) juste apres le premier `browser_navigate`.

**5. Gist** — lancer le skill `/screenshot-gist <NomFichier>` pour creer le gist et cloner dans `tmp/<nom>/`.

---

## Workflow (1 fichier)

### Etape 1 : Analyse du fichier

1. **Lire le fichier** cible
2. **Identifier les textes francais hardcodes** :
   - Strings entre guillemets contenant du francais (`"Votre dossier..."`, `"Erreur"`, etc.)
   - Sujets d'emails (`subject = "..."`, `@subject = "..."`)
   - Labels, titres, messages flash, confirmations turbo
   - Attributs `data: { turbo_confirm: "..." }`
   - Prefixes/suffixes (`"Erreur : "`, `"Attention : "`)
3. **Exclure** :
   - Strings deja i18n (`t("...")`, `I18n.t(...)`)
   - Commentaires Ruby
   - Noms de fichiers, chemins, identifiants techniques
   - Strings uniquement ASCII sans mots francais
   - Constantes techniques (`"application/pdf"`, `"text/html"`)
4. **Si aucun texte hardcode trouve** : ecrire `pr-description.md` avec "Aucun texte hardcode trouve" et terminer (le pipeline marquera `no_diff`).

### Etape 2 : Screenshot AVANT (preuve visuelle)

Capturer le rendu actuel AVANT toute modification.

**Trouver la page de preview :**

- **Mailer** (`app/mailers/`) : `localhost:$PORT/rails/mailers/<mailer_name>/<action>`
  - Exemple : `localhost:$PORT/rails/mailers/notification_mailer/send_accepte_notification`
  - Consulter `spec/mailers/previews/<mailer_name>_preview.rb` pour la liste des actions disponibles
  - Si le preview n'existe pas ou crash → skip le screenshot, documenter dans la PR

- **ViewComponent** (`app/components/`) : chercher dans cet ordre :
  1. Page reelle utilisant le composant (consulter `data/routes-reference.txt`)
  2. Preview ViewComponent : `localhost:$PORT/rails/view_components/<nom>/<variant>`
  3. Si aucun preview → skip le screenshot, documenter dans la PR

- **Vue ERB** (`app/views/`) : page reelle via `data/routes-reference.txt`

**Capturer avec Playwright** (jusqu'a 3 points d'entree) :

Pour les mailers, capturer le body de l'email :
```javascript
async (page) => {
  // Les mail previews Rails affichent le mail dans un iframe ou directement
  const body = await page.$('body');
  if (body) {
    await page.screenshot({ path: `tmp/<nom>/before-1.png`, fullPage: true });
  }
}
```

Pour les composants, cibler le selecteur CSS :
```javascript
async (page) => {
  const elements = await page.$$('.component-selector');
  const padding = 50;
  const vp = page.viewportSize() || { width: 1280, height: 800 };
  for (let i = 0; i < elements.length; i++) {
    if (await elements[i].isVisible()) {
      const box = await elements[i].boundingBox();
      if (!box) continue;
      const clip = {
        x: Math.max(0, box.x - padding),
        y: Math.max(0, box.y - padding),
        width: Math.min(box.width + padding * 2, vp.width - Math.max(0, box.x - padding)),
        height: box.height + padding * 2
      };
      await page.screenshot({ path: `tmp/<nom>/before-${i+1}.png`, clip });
    }
  }
}
```

Nommage : `before-1.png`, `before-2.png`, etc.

### Etape 3 : Determiner la structure i18n cible

**Convention de l'app** (a respecter strictement) :

#### Pour les vues (`app/views/`)
- Fichier YAML : `config/locales/views/<controller>/<action>.fr.yml` (s'il existe deja) OU `config/locales/views/<controller>/fr.yml`
- Scope : lazy lookup `.key` → resolu en `<controller>.<action>.<key>`
- Exemple :
  ```yaml
  # config/locales/views/users/dossiers/fr.yml
  fr:
    users:
      dossiers:
        show:
          submit_button: "Envoyer le dossier"
  ```
  ```erb
  <%= t(".submit_button") %>
  ```

#### Pour les composants ViewComponent (`app/components/`)
- Fichier YAML : `app/components/<nom>/<nom>_component.yml` (fichier sidecar du composant)
- Scope : lazy lookup `.key` (ViewComponent resout automatiquement)
- Exemple :
  ```yaml
  # app/components/dsfr/alert/alert_component.yml
  fr:
    error_prefix: "Erreur : "
    info_prefix: "Information : "
  ```
  ```ruby
  when :error then t(".error_prefix")
  ```

#### Pour les mailers (`app/mailers/`)
- Fichier YAML : `config/locales/views/<mailer_name>/<action>.fr.yml` OU le fichier existant le plus proche
- Sujets : utiliser `default_i18n_subject` quand possible, sinon `I18n.t("<mailer>.<action>.subject")`
- Corps : les textes dans les templates `.html.erb` / `.text.erb` associes suivent la convention views
- Exemple :
  ```yaml
  # config/locales/views/user_mailer/fr.yml
  fr:
    user_mailer:
      archive_available:
        subject: "Votre archive est disponible"
  ```
  ```ruby
  # Avant
  @subject = "Votre archive est disponible"
  # Apres
  @subject = default_i18n_subject
  ```

#### Pour les controllers/services (`app/controllers/`, `app/services/`)
- Fichier YAML : le plus proche fichier `fr.yml` existant dans `config/locales/`
- Scope : chemin complet `I18n.t("controllers.<controller>.<action>.<key>")`

### Etape 4 : Verifier la structure YAML existante

**CRITIQUE** : avant d'ecrire, lire le fichier YAML cible s'il existe.

1. **Si le fichier YAML existe** : parser la structure, trouver le bon noeud d'insertion
2. **Si une cle identique existe avec la meme valeur** → skip (idempotent)
3. **Si une cle identique existe avec une valeur differente** → ne PAS ecraser, choisir un nom de cle different (suffixe `_v2` ou plus descriptif)
4. **Si le fichier YAML n'existe pas** : le creer avec la bonne structure

### Etape 5 : Extraction

Pour chaque texte hardcode identifie :

1. **Choisir un nom de cle** : court, descriptif, snake_case
   - `"Envoyer le dossier"` → `submit_dossier`
   - `"Erreur : "` → `error_prefix`
   - `"Votre archive est disponible"` → `archive_available` (ou `subject` si c'est un sujet mail)
2. **Ajouter la cle au YAML** avec la valeur francaise
3. **Remplacer dans le code** :
   - Vue ERB : `<%= t(".cle") %>`
   - Ruby (vue lazy) : `t(".cle")`
   - Ruby (scope explicite) : `I18n.t("scope.cle")`
   - Mailer subject : `default_i18n_subject` ou `I18n.t("mailer.action.subject")`
4. **Gerer l'interpolation** :
   - `"Dossier #{dossier.number}"` → cle `dossier_number: "Dossier %{number}"` + `t(".dossier_number", number: dossier.number)`
   - `"#{count} dossier(s)"` → cle avec `count:` pour pluralisation Rails
   - Interpolation complexe (HTML, helpers) → skip, ne pas extraire

### Etape 6 : Validation

**OBLIGATOIRE — ne JAMAIS skip**

1. **Verifier chaque cle i18n** : relire le YAML et confirmer que CHAQUE `t(".cle")` insere dans le code a bien une entree correspondante dans le YAML. Si une cle manque → **FAIL** (corriger avant de continuer).

2. **Linter apostrophes** :
   ```bash
   bundle exec rake lint:apostrophe:fix
   ```

3. **Tests** (si identifiables) :
   ```bash
   bundle exec rspec spec/path/to/relevant_spec.rb
   ```
   - Si un test echoue a cause du texte hardcode change (ex: `have_text("Envoyer")`) → fixer le test :
     - Remplacer `have_text("Envoyer")` par `have_text(I18n.t("scope.cle"))` ou par le nouveau texte
   - Si le test echoue pour une autre raison → investiguer, ne pas ignorer

4. **Rubocop** (sur les fichiers modifies uniquement) :
   ```bash
   bundle exec rubocop <fichier_modifie.rb>
   ```

### Etape 7 : Commit

```bash
git add <fichier_modifie>
git add <fichier_yaml>
git add <specs_modifiees>  # si applicable
git commit -m "i18n(<scope>): extract hardcoded strings from <NomFichier>"
```

Un seul commit par fichier traite. Inclure le fichier source + YAML + specs modifiees.

### Etape 8 : Screenshot APRES + comparaison

1. **Reprendre les memes pages** que l'etape 2 (memes URLs, meme ordre)
2. **Capturer les screenshots APRES** : memes scripts Playwright, path `tmp/<nom>/after-1.png`, `after-2.png`, etc.
3. **Comparer avant/apres** :
   - `stat -f%z` sur chaque paire before/after (1 appel Bash par fichier)
   - Identique au byte = le rendu n'a pas change (preuve forte)
   - Si difference : comparer visuellement avec `Read` sur les PNG
     - i18n ne devrait RIEN changer visuellement (meme texte, juste la source change)
     - Si regression visible → c'est un bug d'extraction (cle manquante, interpolation cassee) → **fixer**

4. **Si fix necessaire** :
   - Corriger le fichier source ou YAML
   - Relancer validation (etape 6)
   - Reprendre screenshot after
   - Commit le fix : `git commit -m "fix(i18n): fix extraction <NomFichier> — <description>"`

### Etape 9 : Push gist + pr-description.md

**1. Pousser les screenshots sur le gist** : lancer `push-gist.sh` avec tous les PNG de `tmp/<nom>/`.

**2. Ecrire `pr-description.md`** a la racine du worktree :

   Pour construire les URLs des images du gist :
   - Recuperer le gist ID depuis l'URL (derniere partie du path)
   - Format des URLs raw : `https://gist.githubusercontent.com/<user>/<gist-id>/raw/<filename>`

   **Template :**
   ```markdown
   ## Probleme

   Textes francais en dur dans `<fichier>` — non internationalisable, non maintenable.

   ## Solution

   Skill [`/i18n-hardcoded`](https://github.com/mfo/night-shift/blob/main/.claude/skills/i18n-hardcoded/SKILL.md)

   Extraction de N cles i18n vers `<fichier_yaml>`.

   ### Cles extraites

   | Cle | Valeur |
   |-----|--------|
   | `scope.cle1` | "Texte francais" |
   | `scope.cle2` | "Autre texte" |

   ### Validation visuelle — RESULTAT

   **Avant :**
   ![before](https://gist.githubusercontent.com/<user>/<gist-id>/raw/before-1.png)

   **Apres :**
   ![after](https://gist.githubusercontent.com/<user>/<gist-id>/raw/after-1.png)

   **Couverture :**
   - ✅ `localhost:$PORT/rails/mailers/...` — preview mail
   - ⏭️ raison du skip (si applicable)

   [Voir tous les screenshots](https://gist.github.com/<user>/<gist-id>)

   ### Validation technique

   - [x] Chaque `t()` a sa cle YAML correspondante
   - [x] Apostrophes typographiques verifiees
   - [x] Tests passes
   - [x] Rubocop OK
   - [x] Screenshots avant/apres identiques

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   ```

**3. Fermer Playwright** : appeler `mcp__playwright__browser_close`

---

## Regles critiques

1. **Jamais de "translation missing" en prod** : chaque `t()` DOIT avoir sa cle YAML. Verifier AVANT le commit.
2. **Respecter la structure existante** : ne pas creer une nouvelle hierarchie YAML si une existe deja. S'inserer dedans.
3. **Idempotence** : si une cle existe deja avec la meme valeur, skip. Ne pas dupliquer.
4. **1 fichier = 1 run** : traiter un seul fichier par execution. Ne pas elargir le scope.
5. **Francais uniquement** : ne pas creer de fichier `en.yml`. V1 = extraction francais.
6. **Pas de texte technique** : ne pas extraire les constantes, chemins, formats techniques.
7. **Interpolation simple uniquement** : `#{variable}` → `%{variable}`. Si l'interpolation contient du HTML ou des helpers complexes → skip cette string.
