# Checklist i18n-hardcoded

## Pre-extraction
- [ ] Fichier lu et analyse
- [ ] Textes hardcodes identifies (liste complete)
- [ ] Fichier YAML cible identifie (existant ou a creer)
- [ ] Structure YAML existante lue et respectee
- [ ] Cles existantes verifiees (pas de doublon)

## Extraction
- [ ] Noms de cles descriptifs et snake_case
- [ ] Valeurs francaises ajoutees au YAML
- [ ] Appels `t()` avec le bon scope (lazy ou explicite)
- [ ] Interpolations converties (`#{var}` → `%{var}`)
- [ ] Strings complexes (HTML, helpers) laissees en l'etat

## Validation
- [ ] CHAQUE `t()` a sa cle dans le YAML (zero "translation missing")
- [ ] Apostrophes typographiques verifiees (`rake lint:apostrophe:fix`)
- [ ] Tests passes (specs adaptees si necessaire)
- [ ] Rubocop OK sur fichiers modifies

## Livrable
- [ ] 1 commit propre (source + YAML + specs)
- [ ] `pr-description.md` ecrit avec tableau des cles extraites
