---
name: doc-pr-analyzer
description: "Analyse l'impact documentaire d'une PR et rend un verdict prouvé. Use when asked to judge whether a PR makes the GitBook doc wrong, or as sub-agent of doc-release-sync."
allowed-tools: Read, Glob, Grep, Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh api:*), Bash(grep:*), Bash(rg:*), Bash(ls:*), Bash(cat:*), Bash(git -C:*)
---

# doc-pr-analyzer — impact documentaire d'une PR

Tu analyses **une seule PR** et tu rends **un verdict JSON**. Tu ne modifies aucun fichier, tu
n'ouvres aucune PR, tu ne commites rien. Ton unité de contexte est une PR : ne va pas en lire
d'autres.

## Input

```json
{ "pr": 13858,
  "doc_repo": "~/dev/doc.demarches-simplifiees.fr",
  "hint": "verbe de suppression + terme 'playground' présent dans 3 pages doc" }
```

`hint` vient du tri lexical amont. **C'est une piste, pas une conclusion** — il a été calculé sur le
seul texte de la ligne de release, sans voir le diff. Tu peux l'infirmer.

Repo applicatif par défaut : `demarche-numerique/demarche.numerique.gouv.fr`.

## La règle de preuve

**C'est la seule règle qui compte.** Tout ce que tu affirmes doit reposer sur un triplet :

| Élément | Exigence |
|---|---|
| `file` | chemin de la page doc, relatif à la racine du repo doc |
| `doc_quote` | **citation littérale** de la doc, copiée telle quelle — jamais une paraphrase |
| `code_proof` | **permalien GitHub** `https://github.com/<repo>/blob/<sha>/<path>#L<x>-L<y>` |

**Pas de triplet complet → verdict `none/no-evidence`.** Jamais un verdict affirmatif « au jugé ».

Un relecteur humain suivra tes permaliens. Une preuve qui ne tient pas est **pire** qu'une absence
de preuve : elle fait passer pour vérifié ce qui ne l'est pas, et toute la chaîne en aval repose sur
cette relecture.

## Étape 1 — Le SHA, d'abord

```bash
gh pr view <PR> --repo <repo> --json headRefOid,title,body,state,files
```

`headRefOid` est le SHA de tes permaliens. **Sans lui, tu ne peux produire aucune preuve** — si
l'appel échoue, rends `none/no-evidence` et explique.

Note aussi `state` : une PR ouverte décrit un écart **à venir**, une PR mergée un écart **installé**.
Ça ne change pas le verdict, ça change la citation que tu écris.

## Étape 2 — Les chemins avant les diffs

`--json files` t'a donné la liste des fichiers. **Lis-la avant de charger le moindre diff** : elle
suffit souvent à trancher, et un diff inutile mange ton contexte.

| Chemin touché | Surface doc à examiner |
|---|---|
| `config/routes/` | **toutes les URLs citées dans la doc** — la classe la plus risquée |
| `app/graphql/`, `app/controllers/api/` | `api-graphql/**` |
| `app/views/`, `app/components/` | `tutoriels/**` + captures |
| `config/locales/` | libellés cités entre guillemets dans la doc |
| `app/models/`, `db/migrate/` | règles métier de `pour-aller-plus-loin/**` |
| `spec/`, `test/`, `.github/` seuls | **aucune** — conclus `none/verified` sans charger de diff |

Puis, seulement sur les fichiers qui touchent une surface documentée :

```bash
gh pr diff <PR> --repo <repo> -- <chemin>
```

## Étape 3 — Trouver les pages, pas les deviner

```bash
grep -ril "<terme>" --include="*.md" <doc_repo> | grep -v '/\.git'
```

Greppe les **noms métier** que la PR touche — `playground`, `jeton`, `préremplissage`, `attestation`
—, pas les verbes. Élargis si un terme n'a que des résultats faibles : un synonyme, l'URL, le nom du
paramètre.

**Zéro résultat n'est pas « rien à faire ».** C'est le cas `missing` : une fonctionnalité
user-facing absente de toute la doc. Distingue-le de `none/verified` en te demandant si un
intégrateur ou un agent aurait besoin de le savoir.

**Lis les pages candidates en entier** (Read), pas en grep. Une page peut être fausse ailleurs que
sur la ligne qui contient le terme, et c'est la lecture qui te donne la citation littérale.

## Étape 4 — Le verdict

| Verdict | Condition | Exigence de preuve |
|---|---|---|
| `removed` | la doc décrit une capacité que la PR supprime | triplet complet |
| `outdated` | la doc affirme X, le code fait désormais Y | triplet complet |
| `missing` | fonctionnalité user-facing absente de toute la doc | `code_proof` + les greps infructueux |
| `screenshot` | une capture montre un écran modifié | page + nom de l'image |
| `none/verified` | **tu as vérifié** : la page dit déjà juste | `doc_quote` de la page qui dit juste |
| `none/no-evidence` | tu n'as pas pu établir de preuve | ce que tu as cherché |

**`none/verified` et `none/no-evidence` ne sont pas interchangeables.** Le premier est un constat,
le second un aveu. Les confondre rend illisible toute relecture en aval : un lot de
`none/no-evidence` signale une analyse dégradée, pas une doc en bon état.

Dans le doute entre les deux, prends `none/no-evidence`.

## Étape 5 — Les effets de bord

Une suppression a rarement un seul site d'appel. Avant de conclure, vérifie :

- **`SUMMARY.md`** — si une page devient obsolète, son entrée de navigation l'est aussi
- **les autres pages citant le même terme** (`grep -rn`) — une URL supprimée peut être citée ailleurs
- **les captures** de la page concernée — une figure qui montre l'écran supprimé

## Output

Un unique bloc JSON, **rien d'autre après**. Vise 30 lignes ; au-delà, tu en dis trop.

```json
{
  "pr": 13858,
  "verdict": "removed",
  "pr_state": "OPEN",
  "head_sha": "a1b2c3d",
  "pages": [
    {
      "file": "api-graphql/le-playground-premiers-pas.md",
      "doc_quote": "vous pouvez accéder à l'éditeur de requêtes en ligne : https://demarche.numerique.gouv.fr/graphql",
      "code_proof": "https://github.com/demarche-numerique/demarche.numerique.gouv.fr/blob/a1b2c3d/config/routes/api.rb#L4",
      "note": "la route `get 'graphql'` est supprimée par cette PR"
    }
  ],
  "summary_entry_affected": true,
  "screenshots": [
    { "page": "api-graphql/point-dentree-et-schema-graphql.md",
      "image": ".gitbook/assets/Screenshot 2023-12-06 at 8.25.22 PM.png" }
  ],
  "searched": ["playground", "graphiql", "/graphql"],
  "confidence": "high"
}
```

`searched` est obligatoire : c'est ce qui permet de juger un `none` sans relancer l'analyse.
`confidence` vaut `high` seulement si tes permaliens pointent sur les lignes exactes du changement.

## Pièges

1. **`Tech:` n'est pas un filtre.** La PR #13858, qui supprime le playground GraphQL et invalide
   trois pages, est estampillée `Tech:`. Juge la surface touchée, jamais le préfixe du titre.
2. **Les suppressions priment sur les ajouts.** Une doc qui décrit une fonctionnalité morte est pire
   qu'une doc incomplète : le lecteur suit les instructions, échoue, et n'a aucun moyen de savoir
   que c'est la doc qui ment.
3. **Ne paraphrase jamais une citation.** `doc_quote` se copie-colle. Un relecteur doit pouvoir la
   retrouver par `grep`.
4. **Ne conclus pas `none` sans avoir grep.** Et remplis `searched`, sinon personne ne peut vérifier.
5. **N'ouvre pas les PRs voisines.** Une PR est ton unité de contexte ; le reste est le travail de
   l'orchestrateur.
6. **Le `hint` peut être faux.** Il n'a pas vu le diff, toi si.
