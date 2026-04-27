---
name: i18n-hardcoded
description: "Extract hardcoded French strings to i18n YAML. Use when user says 'extract i18n', 'translate hardcoded', or provides a .rb/.erb file with French text."
allowed-tools: Bash(git status:*), Bash(git add:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Bash(grep:*), Bash(bundle exec rspec:*), Bash(bundle exec rubocop:*), Bash(bundle exec rake lint:apostrophe:fix), Bash(echo:*), Bash(stat:*), Bash(touch:*), Edit(app/*), Edit(spec/*), Edit(config/*), Write(app/*), Write(spec/*), Write(config/*), Write(pr-description.md)
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

### Etape 2 : Determiner la structure i18n cible

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

### Etape 3 : Verifier la structure YAML existante

**CRITIQUE** : avant d'ecrire, lire le fichier YAML cible s'il existe.

1. **Si le fichier YAML existe** : parser la structure, trouver le bon noeud d'insertion
2. **Si une cle identique existe avec la meme valeur** → skip (idempotent)
3. **Si une cle identique existe avec une valeur differente** → ne PAS ecraser, choisir un nom de cle different (suffixe `_v2` ou plus descriptif)
4. **Si le fichier YAML n'existe pas** : le creer avec la bonne structure

### Etape 4 : Extraction

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

### Etape 5 : Validation

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

### Etape 6 : Commit

```bash
git add <fichier_modifie>
git add <fichier_yaml>
git add <specs_modifiees>  # si applicable
git commit -m "i18n(<scope>): extract hardcoded strings from <NomFichier>"
```

Un seul commit par fichier traite. Inclure le fichier source + YAML + specs modifiees.

### Etape 7 : pr-description.md

Ecrire `pr-description.md` a la racine du worktree :

```markdown
## Probleme

Textes francais en dur dans `<fichier>` — non internationalisable, non maintenable.

## Solution

Extraction de N cles i18n vers `<fichier_yaml>`.

### Changements

| Fichier | Modification |
|---------|-------------|
| `<fichier_source>` | N appels `t()` remplaces |
| `<fichier_yaml>` | N cles ajoutees |
| `<spec_file>` | Assertions mises a jour (si applicable) |

### Cles extraites

| Cle | Valeur |
|-----|--------|
| `scope.cle1` | "Texte francais" |
| `scope.cle2` | "Autre texte" |

### Validation

- [x] Chaque `t()` a sa cle YAML correspondante
- [x] Apostrophes typographiques verifiees
- [x] Tests passes
- [x] Rubocop OK

Generated with [Claude Code](https://claude.com/claude-code)
```

---

## Regles critiques

1. **Jamais de "translation missing" en prod** : chaque `t()` DOIT avoir sa cle YAML. Verifier AVANT le commit.
2. **Respecter la structure existante** : ne pas creer une nouvelle hierarchie YAML si une existe deja. S'inserer dedans.
3. **Idempotence** : si une cle existe deja avec la meme valeur, skip. Ne pas dupliquer.
4. **1 fichier = 1 run** : traiter un seul fichier par execution. Ne pas elargir le scope.
5. **Francais uniquement** : ne pas creer de fichier `en.yml`. V1 = extraction francais.
6. **Pas de texte technique** : ne pas extraire les constantes, chemins, formats techniques.
7. **Interpolation simple uniquement** : `#{variable}` → `%{variable}`. Si l'interpolation contient du HTML ou des helpers complexes → skip cette string.
