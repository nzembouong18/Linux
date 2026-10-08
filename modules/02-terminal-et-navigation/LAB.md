# Labo 02 — Chasse au trésor dans l'arborescence

> **Durée** : 45 min · **Difficulté** : ⭐ · **Prérequis** : module 02

## Contexte

Vous héritez d'un projet dont l'arborescence est inconnue. Avant de toucher à quoi que ce soit, vous devez la cartographier uniquement avec `cd`, `ls`, `tree`, `find`, `stat`, `file`.

## Mise en place

```bash
./lab setup 02
cd ~/labs/02/arbre && ls -la
```

## Tâches

Créez le fichier `~/labs/02/reponses.txt` avec les 6 lignes suivantes (`CLÉ=valeur`) :

| Clé | Question |
|-----|----------|
| `PROFOND` | Chemin **absolu** du répertoire le plus profond de `arbre/` |
| `NB_FICHIERS` | Nombre de **fichiers réguliers** dans `arbre/` (récursif, cachés inclus) |
| `GROS` | **Nom** (sans chemin) du fichier le plus volumineux |
| `CACHES` | Nombre d'entrées **cachées** directement à la racine de `arbre/` (hors `.` et `..`) |
| `RELATIF` | Chemin **relatif** pour aller de `arbre/src/app` à `arbre/docs/manuel` |
| `LIEN` | Cible du lien symbolique présent dans `arbre/bin/` |

## Validation

```bash
./lab check 02
```

<details><summary>💡 Indices</summary>

- `tree -a` montre aussi les fichiers cachés (installez-le si besoin : `sudo apt install tree`).
- `find arbre -type f | wc -l` compte les fichiers ; `find arbre -type d` liste les dossiers.
- `ls -lS` trie par taille. `ls -l` sur un lien affiche `lien -> cible`, ou `readlink`.
- Pour le chemin absolu : `realpath` ou `pwd` après un `cd`.
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/02
{
  echo "PROFOND=$(find "$PWD/arbre" -type d | awk -F/ '{print NF, $0}' | sort -rn | head -1 | cut -d' ' -f2-)"
  echo "NB_FICHIERS=$(find arbre -type f | wc -l)"
  echo "GROS=$(find arbre -type f -printf '%s %f\n' | sort -rn | head -1 | cut -d' ' -f2-)"
  echo "CACHES=$(ls -A arbre | grep -c '^\.')"
  echo "RELATIF=../../docs/manuel"
  echo "LIEN=$(readlink arbre/bin/lancer)"
} > reponses.txt
```
</details>

## Pour aller plus loin

- Retrouvez le fichier modifié le plus récemment (`ls -lt` / `find -newer`).
- Affichez l'arborescence sur 2 niveaux seulement (`tree -L 2`).
- Écrivez un alias `ll` permanent dans `~/.bashrc`.

## Nettoyage

```bash
./lab reset 02
```
