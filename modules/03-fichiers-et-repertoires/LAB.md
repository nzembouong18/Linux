# Labo 03 — Remettre de l'ordre dans un dossier « vrac »

> **Durée** : 1 h 15 · **Difficulté** : ⭐⭐ · **Prérequis** : module 03

## Contexte

Un collègue a laissé un dossier `vrac/` où tout est mélangé : photos, documents, journaux, temporaires, noms avec espaces. Vous devez le ranger proprement et produire quelques indicateurs.

## Mise en place

```bash
./lab setup 03
cd ~/labs/03 && ls -la vrac
```

## Tâches

Travaillez dans `~/labs/03`. Aucun fichier ne doit être perdu (sauf les `.tmp` demandés).

1. Créez l'arborescence `range/{images,documents,logs}` en **une seule commande**.
2. **Déplacez** vers `range/images` tous les `*.jpg` et `*.png` de `vrac/` ; vers `range/documents` tous les `*.pdf` et `*.txt` ; vers `range/logs` tous les `*.log`. (Attention aux noms contenant des espaces !)
3. **Supprimez** tous les fichiers `*.tmp` de `vrac/` (récursivement), mais **pas** les autres.
4. Dans `range/documents`, créez un **lien symbolique** `courant.txt` pointant vers `note-2024.txt`.
5. Dans `range/logs`, créez un **lien dur** `dernier.log` vers `app.log`.
6. Faites une **copie de sauvegarde** de tout `range/` vers `sauvegarde/` en préservant dates et droits (`-a`).
7. Écrivez dans `rapport.txt` :
   - `PLUS_GROS=<nom du plus gros fichier de range/>` ;
   - `NB_LOGS=<nombre de fichiers .log réels (hors lien dur) dans range/logs>` — comptez `app.log` et `erreurs.log`, mais pas `dernier.log` → attendu : voir indices ;
   - `ESPACE=<taille totale de range/ en octets>` (`du -sb`).

## Validation

```bash
./lab check 03
```

<details><summary>💡 Indices</summary>

- `mkdir -p range/{images,documents,logs}`
- `mv vrac/*.jpg vrac/*.png range/images/` — les espaces ne posent pas de problème avec `*` (le shell gère le découpage).
- `find vrac -name '*.tmp' -delete`
- `ln -s note-2024.txt range/documents/courant.txt` (cible **relative au dossier du lien**).
- `cp -a range sauvegarde`
- `find range/logs -type f -name '*.log' ! -name dernier.log | wc -l`
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/03
mkdir -p range/{images,documents,logs}
mv vrac/*.jpg vrac/*.png range/images/
mv vrac/*.pdf vrac/*.txt range/documents/
mv vrac/*.log range/logs/
find vrac -name '*.tmp' -delete
ln -s note-2024.txt range/documents/courant.txt
ln range/logs/app.log range/logs/dernier.log
cp -a range sauvegarde
{
  echo "PLUS_GROS=$(find range -type f -printf '%s %f\n' | sort -rn | head -1 | cut -d' ' -f2-)"
  echo "NB_LOGS=$(find range/logs -type f -name '*.log' ! -name dernier.log | wc -l)"
  echo "ESPACE=$(du -sb range | cut -f1)"
} > rapport.txt
```

> ⚠️ `du -sb` compte aussi les liens : l'ordre des opérations compte (le rapport doit être écrit **après** les étapes 1 à 5).
</details>

## Pour aller plus loin

- Écrivez une seule commande `find … -exec mv -t … {} +` qui fait l'étape 2 pour toute une arborescence.
- Comptez les inodes utilisés dans `range/` (`find range | wc -l`) puis `df -i .`.
- Simulez un lien symbolique cassé et retrouvez-le : `find . -xtype l`.

## Nettoyage

```bash
./lab reset 03
```
