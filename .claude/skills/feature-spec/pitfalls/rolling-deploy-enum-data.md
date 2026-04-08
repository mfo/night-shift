---
triggers: [enum, migration, rename, lowercase, uppercase, rolling-deploy, nature, data-migration, backfill]
---
# Rolling Deploy : Migration de valeurs enum/data

**Piege :** Changer le format d'ecriture (ex: enum values) dans le meme deploiement que le changement de code. Pendant le rolling deploy, ancien et nouveau code coexistent et lisent la meme DB.

```
Serveur A (nouveau code) ecrit 'titre_identite' en DB
                    |
Serveur B (ancien code) lit → ne reconnait pas → crash
```

**Solution :** Separer lecture et ecriture en N deploiements :
1. Rendre la lecture tolerante aux deux formats (ex: surcharge getter avec `.downcase`)
2. Changer le format d'ecriture + backfill des donnees existantes
3. Supprimer la tolerance (le getter standard suffit)

**Regle d'or :** Ne jamais ecrire un nouveau format en DB tant que tous les serveurs ne savent pas le lire.

**Signe d'alerte :** La spec mentionne un changement d'enum, un rename de colonne, ou une migration de format de donnees.

**Ref :** PR #12927 / #12930 / #12931 (cleanup-nature, avril 2026)
