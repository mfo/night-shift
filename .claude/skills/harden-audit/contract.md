# Contrat frontmatter — fichier d'audit securite

**Version :** 1
**Source unique :** `.claude/skills/harden-audit/contract.md`
**Producteur :** `/harden-audit` (status: qualified)
**Consommateurs :** `/harden-fix` (gate d'entree), `/harden-pentest` (format rapport)

---

## Champs remplis par le producteur (`/harden-audit`)

| Champ | Obligatoire | Format |
|-------|-------------|--------|
| `title` | oui | Titre court de la faille |
| `source` | oui | YesWeHack / audit / CVE / interne / harden-pentest |
| `date` | oui | YYYY-MM-DD |
| `owasp` | oui | A01-A10 |
| `cwe` | recommande | CWE-XXX |
| `dread_score` | oui | X/15 |
| `verdict` | oui | fix immediat / sprint courant / backlog / accepter le risque / faux positif |
| `status` | oui | qualified / false-positive / not-reproducible / wont-fix / fixed |
| `category` | oui | security / hardening |
| `confidence` | oui | high / medium / low |
| `chain_verified` | oui | true / false |
| `test_vector` | recommande | methode HTTP + URL + payload minimal |
| `affected_files` | recommande | liste de chemin/fichier.rb:ligne |

## Champs ajoutes par le consommateur (`/harden-fix`) apres correction

| Champ | Obligatoire | Format |
|-------|-------------|--------|
| `fixed_date` | oui | YYYY-MM-DD |
| `fix_pr` | oui | URL de la PR |

---

## Regles de calcul

### `confidence`

| Valeur | Conditions |
|--------|-----------|
| `high` | Chaine tracee integralement (chaque maillon avec fichier:ligne) ET reproduction locale confirmee |
| `medium` | Chaine tracee mais reproduction non confirmee, OU 1 maillon non lu |
| `low` | Analyse statique seule, chaine partiellement tracee |

Impact en aval : `confidence: low` → harden-fix DOIT re-verifier la chaine avant de coder.

### `category`

| Valeur | Quand l'utiliser |
|--------|-----------------|
| `security` | Faille exploitable → pipeline normal (audit → fix) |
| `hardening` | Hygiene / defense en profondeur (headers, source maps, CSP) → batch trimestriel |
