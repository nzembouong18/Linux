# Labo 09 — Écrire cinq scripts Bash testés automatiquement

> **Durée** : 3 h · **Difficulté** : ⭐⭐⭐ · **Prérequis** : module 09

## Contexte

Vous êtes l'administrateur d'un petit serveur. Vous écrivez une boîte à outils de scripts, chacun répondant à un **cahier des charges précis**. Le correcteur exécute vos scripts avec différents jeux d'essai.

## Mise en place

```bash
./lab setup 09
cd ~/labs/09 && ls -l && cat CAHIER_DES_CHARGES.md
```

## Cahier des charges

Tous les scripts : shebang bash, exécutables (`chmod +x`), **syntaxe valide** (`bash -n`), `set -u` ou `set -euo pipefail` recommandé. Messages d'erreur sur **stderr**.

### 1. `salut.sh NOM`
- `./salut.sh Alice` → affiche `Bonjour Alice !` (code 0).
- Avec plusieurs mots entre guillemets : `./salut.sh "Alice Dupont"` → `Bonjour Alice Dupont !`.
- Sans argument : message `Usage: salut.sh NOM` **sur stderr**, code retour **1**.

### 2. `parite.sh N`
- `./parite.sh 7` → `7 est impair` ; `./parite.sh 10` → `10 est pair` (code 0). Gérez aussi `0` et les négatifs (`-4` est pair).
- Argument non entier (`abc`, `3.5`, vide) : message sur stderr, code retour **2**.

### 3. `somme.sh [N...]`
- Affiche la somme de ses arguments entiers : `./somme.sh 1 2 3` → `6`. Sans argument → `0`.

### 4. `compte-ext.sh DOSSIER`
- Pour les **fichiers réguliers situés directement** dans `DOSSIER` (pas les sous-dossiers), affiche une ligne `extension: nombre` par extension (sans le point). Les fichiers sans extension sont comptés sous `(aucune)`. L'extension est ce qui suit le **dernier** point (`archive.tar.gz` → `gz`). Les fichiers cachés ne sont pas à traiter. L'ordre des lignes est libre.
- Dossier inexistant : message sur stderr, code retour **3**.
- Exemple pour `a.txt b.txt c.log Makefile` → `txt: 2`, `log: 1`, `(aucune): 1`.

### 5. `sauvegarde.sh SOURCE DESTINATION`
- Crée `DESTINATION` si besoin et y place une archive `backup-AAAAMMJJ.tar.gz` (date du jour) contenant le dossier `SOURCE` ; **affiche le chemin de l'archive sur stdout** (et rien d'autre sur stdout).
- Pas assez d'arguments → usage sur stderr, code **1**.
- `SOURCE` inexistante → message sur stderr, code **3**, aucune archive créée.
- Le script doit contenir `set -e` (ou `set -Eeuo pipefail`).

## Validation

```bash
./lab check 09
```

<details><summary>💡 Indices</summary>

- Test d'entier : `[[ $1 =~ ^-?[0-9]+$ ]]`. Pair : `(( $1 % 2 == 0 ))` (attention aux négatifs : `-4 % 2` vaut `0`, `-3 % 2` vaut `-1`).
- Extension : `ext=${f##*.}` — mais pour `Makefile` sans point, `${f##*.}` renvoie le nom entier : testez `[[ $f == *.* ]]`.
- Comptage : tableau associatif `declare -A n` et `((n[$ext]++))`.
- `tar -czf "$dest/backup-$(date +%Y%m%d).tar.gz" -C "$(dirname "$src")" "$(basename "$src")"`
</details>

<details><summary>✅ Solution</summary>

Voir `./lab solve 09` : les scripts de référence sont écrits dans `~/labs/09`. Tentez d'abord seul !

```bash
# salut.sh
#!/usr/bin/env bash
set -euo pipefail
[[ $# -ge 1 ]] || { echo "Usage: salut.sh NOM" >&2; exit 1; }
echo "Bonjour $* !"
```
</details>

## Pour aller plus loin

- Passez chaque script à `shellcheck` et corrigez tous les avertissements.
- Ajoutez `-v` (mode verbeux) à `sauvegarde.sh` avec `getopts`, et une rotation (`-k JOURS`).
- Écrivez des tests avec `bats-core`.
- Planifiez `sauvegarde.sh` toutes les nuits avec cron (module 14).

## Nettoyage

```bash
./lab reset 09
```
