# Module 09 — Scripting Bash : automatiser comme un professionnel

> **Niveau** : Intermédiaire | **Durée** : 6 h (3 h cours + 3 h labo) | **Prérequis** : modules 02–07
>
> **Objectifs** — À la fin de ce module vous saurez :
> - écrire des scripts lisibles, sûrs et réutilisables (shebang, droits, structure) ;
> - manipuler variables, tableaux, arguments et codes retour ;
> - maîtriser conditions, boucles, `case`, fonctions et `getopts` ;
> - rendre un script robuste (`set -euo pipefail`, `trap`, `mktemp`, journalisation) ;
> - déboguer (`bash -x`, `shellcheck`) et connaître les pièges classiques.

---

## 1. Premier script

```bash
#!/usr/bin/env bash
# bonjour.sh — affiche un message
echo "Bonjour $USER, nous sommes le $(date +%F)"
```

```bash
chmod +x bonjour.sh      # rendre exécutable
./bonjour.sh             # exécution (le ./ est nécessaire)
bash bonjour.sh          # ou sans droit x
```

- La première ligne `#!` (**shebang**) indique l'interpréteur : `#!/usr/bin/env bash` (portable) ou `#!/bin/bash`.
- `sh script` ≠ `bash script` : `sh` peut être `dash` (POSIX strict, pas de `[[ ]]`, tableaux…). Si vous utilisez des fonctions bash, mettez `bash` dans le shebang.
- `./script` (nouveau processus) vs `source script` / `. script` (exécuté **dans le shell courant**, modifie ses variables et son `cd`).

## 2. Variables

```bash
nom="Alice"                  # PAS d'espace autour du =
age=30
echo "Nom: $nom, ${nom}s"    # ${nom} délimite le nom de variable
readonly VERSION="1.0"       # constante
export PATH="$PATH:/opt/bin" # visible par les processus enfants
unset nom                    # supprime
resultat=$(date +%s)         # capture une sortie
```

**Toujours entourer d'apostrophes doubles** : `"$var"`. Sans cela, espaces et jokers dans la valeur cassent le script (*word splitting* et *globbing*).

### Variables spéciales

| Variable | Contenu |
|----------|---------|
| `$0` | nom du script |
| `$1` … `$9`, `${10}` | arguments positionnels |
| `$#` | nombre d'arguments |
| `"$@"` | tous les arguments, **chacun entre guillemets** (à utiliser presque toujours) |
| `"$*"` | tous les arguments en **une seule** chaîne |
| `$?` | code retour de la dernière commande |
| `$$` | PID du script |
| `$!` | PID de la dernière commande en arrière-plan |
| `$LINENO`, `$RANDOM`, `$SECONDS` | numéro de ligne, nombre aléatoire, secondes écoulées |
| `shift` | décale les arguments (`$2` devient `$1`) |

### Expansion de paramètres (très utile, sans appeler d'autres commandes)

| Syntaxe | Effet | Exemple (`f=/data/rapport.tar.gz`) |
|---------|-------|------------------------------------|
| `${v:-défaut}` | valeur par défaut si vide/non défini | `${PORT:-8080}` |
| `${v:=défaut}` | idem **et** affecte | |
| `${v:?message}` | **erreur** si vide (arrête le script) | `${DIR:?DIR requis}` |
| `${v:+alt}` | `alt` si `v` est défini | |
| `${#v}` | longueur | `${#f}` → 22 |
| `${v#motif}` / `${v##motif}` | retire le plus court / long préfixe | `${f##*/}` → `rapport.tar.gz` |
| `${v%motif}` / `${v%%motif}` | retire le plus court / long suffixe | `${f%.gz}` → `/data/rapport.tar` ; `${f%%.*}` → `/data/rapport` |
| `${v/a/b}` / `${v//a/b}` | remplace première / toutes occurrences | `${f//\//_}` |
| `${v^^}` / `${v,,}` | majuscules / minuscules | |
| `${v:2:5}` | sous-chaîne | |
| `$(basename "$f")` / `$(dirname "$f")` | nom / dossier | |

### Arithmétique

```bash
a=7; b=3
echo $((a + b)) $((a * b)) $((a % b)) $((a ** 2))     # 10 21 1 49
((a++)); ((a > b)) && echo "a plus grand"
(( total = a * b + 1 ))
# bash ne gère QUE les entiers. Pour les décimaux : bc -l  ou  awk
echo "scale=2; 10/3" | bc ; awk 'BEGIN{printf "%.2f\n", 10/3}'
```

## 3. Lire des entrées

```bash
read -p "Votre nom : " nom              # interactif
read -rs -p "Mot de passe : " mdp; echo # -s silencieux ; -r n'interprète pas les \
read -r -t 5 reponse || reponse="non"   # délai maximal
while IFS= read -r ligne; do echo "→ $ligne"; done < fichier.txt     # lire un fichier ligne à ligne
IFS=: read -r user _ uid _ < <(grep ^root /etc/passwd)               # découper une ligne
```

## 4. Conditions

### `if` et les tests

```bash
if [[ -f "$fichier" ]]; then
    echo "existe"
elif [[ -d "$fichier" ]]; then
    echo "c'est un dossier"
else
    echo "absent"
fi

commande && echo "réussi" || echo "échoué"      # raccourcis (attention à la précédence)
if grep -q "root" /etc/passwd; then echo trouvé; fi    # if teste le CODE RETOUR d'une commande
```

`[[ … ]]` (bash) est plus sûr que `[ … ]` : pas de découpage, `&&`/`||`, motifs, regex.

| Test fichier | Vrai si… | Test chaîne | Vrai si… |
|-------------|----------|-------------|----------|
| `-e f` | existe | `-z "$s"` | vide |
| `-f f` | fichier régulier | `-n "$s"` | non vide |
| `-d f` | dossier | `"$a" == "$b"` | égales |
| `-L f` | lien symbolique | `"$a" == motif*` | correspond au motif |
| `-r -w -x f` | lisible, modifiable, exécutable | `"$a" =~ ^[0-9]+$` | regex |
| `-s f` | taille > 0 | `"$a" < "$b"` | ordre alphabétique |
| `f1 -nt f2` | f1 plus récent | | |

| Test numérique | Sens |
|---------------|------|
| `-eq -ne` | = ≠ |
| `-lt -le` | < ≤ |
| `-gt -ge` | > ≥ |

(ou `(( a > b ))` pour l'arithmétique). Combinaisons : `[[ -f $f && -r $f ]]`, `[[ $a == x || $b == y ]]`, `! `.

### `case`

```bash
case "$1" in
    start|up)   demarrer ;;
    stop)       arreter ;;
    restart)    arreter; demarrer ;;
    *.txt)      echo "fichier texte" ;;
    [0-9]*)     echo "commence par un chiffre" ;;
    *)          echo "Usage: $0 {start|stop|restart}" >&2; exit 1 ;;
esac
```

## 5. Boucles

```bash
for i in 1 2 3; do echo "$i"; done
for i in {1..10}; do echo "$i"; done
for ((i = 0; i < 5; i++)); do echo "$i"; done
for f in *.log; do gzip "$f"; done            # ✔ jokers: sûr avec les espaces
for f in $(ls *.log); do …                    # ✘ à ne JAMAIS faire
while read -r l; do echo "$l"; done < f       # lecture ligne à ligne
while true; do …; sleep 5; done               # boucle infinie
until ping -c1 -W1 10.0.0.1 >/dev/null; do sleep 2; done     # jusqu'à succès
break ; continue                              # sortir / passer à l'itération suivante
```

Les boucles peuvent être alimentées par un pipe, mais attention : `commande | while …` s'exécute dans un **sous-shell** (les variables modifiées sont perdues). Préférez `while … done < <(commande)`.

## 6. Tableaux

```bash
fruits=("pomme" "poire" "kiwi")
echo "${fruits[0]}"            # pomme
echo "${fruits[@]}"            # tous les éléments
echo "${#fruits[@]}"           # nombre d'éléments
fruits+=("banane")             # ajouter
for f in "${fruits[@]}"; do echo "$f"; done

declare -A age                 # tableau associatif (bash ≥ 4)
age[alice]=30; age[bob]=25
for nom in "${!age[@]}"; do echo "$nom a ${age[$nom]} ans"; done
```

`mapfile -t lignes < fichier` charge un fichier dans un tableau.

## 7. Fonctions

```bash
log() {                         # ne pas écrire "function log()" pour rester portable
    local niveau=$1; shift      # local : variable limitée à la fonction
    printf '%s [%s] %s\n' "$(date '+%F %T')" "$niveau" "$*" >&2
}

est_entier() { [[ $1 =~ ^-?[0-9]+$ ]]; }     # le code retour de la fonction = celui de la dernière commande

somme() {
    local total=0 n
    for n in "$@"; do total=$((total + n)); done
    echo "$total"               # "retourne" une valeur en l'affichant
}

resultat=$(somme 1 2 3)         # capture
est_entier "$resultat" && log INFO "résultat = $resultat"
return 3                        # return : code retour (0–255) ≠ valeur
```

## 8. Arguments et options : `getopts`

```bash
usage() { echo "Usage: $0 [-v] [-n NOMBRE] [-o fichier] source..." >&2; exit 1; }

verbeux=0 nombre=10 sortie=""
while getopts ":vn:o:h" opt; do
    case $opt in
        v) verbeux=1 ;;
        n) nombre=$OPTARG ;;
        o) sortie=$OPTARG ;;
        h) usage ;;
        :) echo "L'option -$OPTARG requiert un argument" >&2; usage ;;
        \?) echo "Option inconnue: -$OPTARG" >&2; usage ;;
    esac
done
shift $((OPTIND - 1))          # il reste les arguments positionnels
[[ $# -ge 1 ]] || usage
```

Pour des options longues (`--verbose`), utilisez une boucle `while [[ $# -gt 0 ]]; do case $1 in …; shift; done`.

## 9. Codes retour et robustesse

Convention : **0 = succès**, 1–255 = erreur (1 générique, 2 mauvais usage, 126 non exécutable, 127 commande introuvable, 128+N tué par le signal N).

### Le mode strict

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
```

| Option | Effet |
|--------|-------|
| `-e` | arrête le script à la première commande en échec |
| `-u` | erreur si variable non définie (évite `rm -rf "$DIR/"*` avec `DIR` vide) |
| `-o pipefail` | un pipeline échoue si une de ses commandes échoue |
| `-E` | les `trap ERR` s'appliquent aussi dans les fonctions |

Nuances de `-e` : n'est pas déclenché dans un `if`, `&&`, `||`, `while`. Pour tolérer un échec : `commande || true`, ou `if commande; then …`.

### Nettoyage avec `trap`, fichiers temporaires

```bash
tmpdir=$(mktemp -d)                         # jamais /tmp/fichier prévisible
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT                           # exécuté dans tous les cas, même en erreur
trap 'echo "Erreur ligne $LINENO" >&2' ERR
```

### Verrou anti-doublon

```bash
exec 9>/var/lock/monscript.lock
flock -n 9 || { echo "Déjà en cours" >&2; exit 1; }
```

### Journaliser et gérer les erreurs

```bash
die() { echo "ERREUR: $*" >&2; exit 1; }
[[ -r "$config" ]] || die "config illisible: $config"
command -v rsync >/dev/null || die "rsync est requis"
(( EUID == 0 )) || die "à exécuter en root"
```

Envoyez les **messages d'erreur sur stderr** (`>&2`) et les **résultats sur stdout** : les scripts deviennent composables.

## 10. Un script complet commenté

```bash
#!/usr/bin/env bash
# sauvegarde.sh — archive un dossier avec rotation
# Usage: sauvegarde.sh [-k JOURS] SOURCE DESTINATION
set -Eeuo pipefail

readonly PROG=${0##*/}
keep=7

usage() { echo "Usage: $PROG [-k JOURS] SOURCE DESTINATION" >&2; exit 1; }
log()   { printf '%s %s\n' "$(date '+%F %T')" "$*" >&2; }

while getopts ":k:" o; do
    case $o in
        k) keep=$OPTARG ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))
[[ $# -eq 2 ]] || usage
src=$1 dest=$2

[[ -d "$src" ]] || { log "source absente: $src"; exit 3; }
mkdir -p "$dest"

archive="$dest/backup-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "$archive" -C "$(dirname "$src")" "$(basename "$src")"
log "archive créée: $archive ($(du -h "$archive" | cut -f1))"

# rotation : supprime les archives de plus de $keep jours
find "$dest" -name 'backup-*.tar.gz' -mtime +"$keep" -print -delete | while read -r f; do log "supprimée: $f"; done
echo "$archive"
```

## 11. Déboguer

```bash
bash -n script.sh            # vérifie seulement la syntaxe
bash -x script.sh            # trace chaque commande (préfixe +)
set -x … set +x              # trace une portion
PS4='+ ${BASH_SOURCE}:${LINENO}: ' bash -x script.sh      # trace détaillée
shellcheck script.sh         # ANALYSEUR STATIQUE : à utiliser systématiquement
```

`shellcheck` détecte guillemets manquants, `cd` non vérifié, `for f in $(ls)`, etc. Intégrez-le à votre CI et à votre éditeur.

## 12. Pièges classiques

| Piège | Solution |
|------|----------|
| `rm -rf $DIR/*` avec `DIR` vide | `set -u` + `"${DIR:?}"` |
| Variable sans guillemets | `"$var"` |
| `for f in $(ls)` | `for f in *` |
| `cd dossier; rm *` si le `cd` échoue | `cd dossier || exit 1` ou `set -e` |
| `[ $a = $b ]` avec valeur vide | `[[ $a == "$b" ]]` |
| Pipe vers `while` perd les variables | `done < <(commande)` |
| `echo` interprète `-n`, `\n` | `printf '%s\n' "$x"` |
| Script copié depuis Windows (`\r`) | `dos2unix` |
| Parser la sortie de `ls` | `find -print0`, `stat`, globbing |
| Mots de passe en argument (visibles dans `ps`) | variable d'environnement, fichier 600, gestionnaire de secrets |
| Script trop long et complexe | passer à **Python** (au-delà de ~100–200 lignes ou structures complexes) |

## 13. Bonnes pratiques

1. Shebang + `set -Eeuo pipefail` + commentaire d'en-tête (but, usage, auteur).
2. Une fonction par tâche, `main "$@"` à la fin.
3. Variables en `MAJUSCULES` pour la config/constantes, `minuscules` pour les locales (`local`).
4. Messages sur stderr, codes retour documentés.
5. Idempotence : relancer le script ne doit pas casser (`mkdir -p`, `ln -sfn`, tests d'existence).
6. Testez avec `shellcheck` et des cas limites (noms avec espaces, dossier vide, argument manquant).
7. Versionnez dans git ; `bats-core` pour tester automatiquement.

## 14. Résumé

- Shebang, `chmod +x`, `"$@"`, `"$var"`, `$(…)`, `$((…))`.
- `[[ ]]` pour les tests ; `if/case/for/while` ; fonctions avec `local` ; `getopts`.
- Robustesse : `set -Eeuo pipefail`, `trap … EXIT`, `mktemp`, `flock`, codes retour.
- Débogage : `bash -n`, `bash -x`, **`shellcheck`**.

## 15. Quiz

1. Quelle différence entre `"$@"` et `"$*"` ?
2. Que fait `${fichier%.txt}.bak` ?
3. Pourquoi `for f in $(ls)` est-il dangereux ?
4. Que font `set -e`, `set -u` et `set -o pipefail` ?
5. Comment exécuter du nettoyage même si le script échoue ?
6. Comment afficher une erreur sur stderr ?
7. Quelle est la différence entre `./s.sh` et `source s.sh` ?
8. Écrivez un test qui vérifie qu'une variable `n` est un entier positif.

<details><summary>Réponses</summary>

1. `"$@"` conserve chaque argument séparément ; `"$*"` les fusionne en une seule chaîne séparée par le premier caractère d'`IFS`.
2. Retire le suffixe `.txt` et ajoute `.bak` (`notes.txt` → `notes.bak`).
3. Le découpage sur les espaces casse les noms de fichiers avec espaces/retours à la ligne. Utilisez un joker.
4. Arrêt à la première erreur / erreur sur variable non définie / un pipeline échoue si une étape échoue.
5. `trap cleanup EXIT`.
6. `echo "erreur" >&2`.
7. `./s.sh` lance un sous-processus ; `source` exécute dans le shell courant (variables et `cd` persistent).
8. `[[ $n =~ ^[0-9]+$ ]]`
</details>

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 09` · **Suivant** : [10 — Traitement de texte avancé](../10-texte-avance/README.md)
