# Module 05 — Redirections, pipes et filtres : la puissance de la ligne de commande

> **Niveau** : Débutant | **Durée** : 4 h (2 h cours + 2 h labo) | **Prérequis** : modules 02–04
>
> **Objectifs** — À la fin de ce module vous saurez :
> - rediriger l'entrée standard, la sortie standard et l'erreur standard ;
> - chaîner des commandes avec des **pipes** ;
> - utiliser les filtres classiques : `grep`, `sort`, `uniq`, `cut`, `tr`, `wc`, `tee`, `xargs` ;
> - résoudre des problèmes d'analyse de données en une ligne de commande ;
> - utiliser `here-document`, substitution de commande et de processus.

---

## 1. Les trois flux standards

Chaque processus démarre avec trois « tuyaux » ouverts, identifiés par un **descripteur de fichier** (*file descriptor*, fd) :

```text
              ┌──────────────┐
 clavier ──►  │ fd 0 : stdin │
              │              │──► fd 1 : stdout  ──► écran
              │   COMMANDE   │
              │              │──► fd 2 : stderr  ──► écran
              └──────────────┘
```

| fd | Nom | Défaut | Rôle |
|---:|-----|--------|------|
| 0 | `stdin` | clavier | données lues |
| 1 | `stdout` | terminal | résultat normal |
| 2 | `stderr` | terminal | messages d'erreur / diagnostics |

La séparation stdout / stderr est essentielle : on peut sauvegarder les résultats tout en voyant les erreurs, ou l'inverse.

## 2. Redirections

| Syntaxe | Effet |
|---------|-------|
| `cmd > f` | stdout → `f` (**écrase**) |
| `cmd >> f` | stdout → `f` (**ajoute**) |
| `cmd < f` | stdin ← `f` |
| `cmd 2> f` | stderr → `f` |
| `cmd 2>> f` | stderr ajouté à `f` |
| `cmd > f 2>&1` | stdout **et** stderr → `f` (l'ordre compte !) |
| `cmd &> f` | idem (bash) |
| `cmd 2>&1 \| autre` | stderr rejoint stdout pour passer dans le pipe |
| `cmd > /dev/null` | jette la sortie normale |
| `cmd 2> /dev/null` | jette les erreurs |
| `cmd > /dev/null 2>&1` | silence total |
| `cmd <<< "texte"` | *here-string* : texte comme stdin |
| `cmd << FIN … FIN` | *here-document* : bloc multi-lignes comme stdin |

```bash
ls /etc /inexistant > sortie.txt 2> erreurs.txt     # sépare les deux flux
ls /etc /inexistant > tout.txt 2>&1                 # les deux dans un fichier
ls /etc /inexistant 2>&1 > tout.txt                 # ✘ PIÈGE : stderr va encore à l'écran
```

> **Pourquoi le dernier ne marche pas ?** Le shell lit de gauche à droite : `2>&1` duplique stderr vers *là où va stdout à cet instant* (l'écran), **puis** `> tout.txt` redirige seulement stdout.

Effets de bord à connaître :

- `cmd > f` **crée/tronque `f` avant** d'exécuter `cmd` : `sort f > f` vide `f` ! Utilisez `sort -o f f` ou un fichier temporaire (`sponge` du paquet *moreutils*).
- `set -o noclobber` interdit d'écraser par `>` (forcer : `>|`).
- `/dev/null` : trou noir ; `/dev/zero` : octets nuls ; `/dev/urandom` : octets aléatoires.

### Here-document

```bash
cat > config.ini << 'EOF'
[server]
port = 8080
home = $HOME        # littéral car 'EOF' est entre quotes
EOF

cat << EOF
Bonjour $USER       # ici $USER est développé (EOF sans quotes)
EOF

mysql -u root << SQL
CREATE DATABASE app;
SQL
```

`<<-` supprime les tabulations initiales (pour indenter dans un script).

## 3. Les pipes

Le **pipe** `|` relie la stdout d'une commande à la stdin de la suivante. Les commandes s'exécutent **en parallèle**, le noyau gérant un tampon entre elles.

```bash
ls -l /etc | wc -l                       # combien d'entrées ?
cat /etc/passwd | cut -d: -f1 | sort     # noms d'utilisateurs triés
ps aux | grep nginx | grep -v grep       # processus nginx
dmesg | tail -20 | less
```

Un pipeline = une usine : chaque commande fait une transformation. **Construisez-les pas à pas** : tapez la première commande, vérifiez, ajoutez la suivante.

```text
cat access.log │ awk '{print $1}' │ sort │ uniq -c │ sort -rn │ head
   lire         extraire l'IP      grouper  compter    classer   top 10
```

Code de retour d'un pipeline : celui de la **dernière** commande, sauf `set -o pipefail` (module 09) qui renvoie le premier échec.

## 4. Les filtres essentiels

### `grep` — chercher des motifs

```bash
grep "erreur" fichier            # lignes contenant « erreur »
grep -i "erreur" f               # insensible à la casse
grep -v "debug" f                # lignes NE contenant PAS « debug »
grep -n "root" /etc/passwd       # avec numéros de ligne
grep -c "GET" access.log         # nombre de lignes correspondantes
grep -r "TODO" ./src             # récursif dans un dossier
grep -rl "password" /etc 2>/dev/null     # noms des fichiers seulement
grep -w "port" f                 # mot entier
grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+" f   # uniquement la partie qui correspond
grep -E "error|warn|fatal" f     # regex étendue (OU)
grep -A2 -B1 "panic" f           # 2 lignes après, 1 avant (-C2 : autour)
grep -F "a.b*c" f                # texte littéral, pas de regex
grep -q "motif" f && echo oui    # silencieux : utile dans les if
```

Mini-regex (détails au module 10) : `^` début · `$` fin · `.` n'importe quel caractère · `*` répétition · `[abc]` ensemble · `\|`/`-E` ou · `+ ? {n}` (avec `-E`).

### `sort` et `uniq`

```bash
sort fichier                     # ordre alphabétique
sort -r f                        # inverse
sort -n f                        # numérique (10 > 2)
sort -h f                        # tailles humaines (1K < 2M)
sort -u f                        # trie et supprime les doublons
sort -t: -k3 -n /etc/passwd      # séparateur ':', clé = 3e champ, numérique
sort -k2,2 -k1,1n f              # plusieurs clés

uniq f                           # supprime les doublons CONSÉCUTIFS (donc trier avant !)
uniq -c f                        # préfixe par le nombre d'occurrences
uniq -d f                        # n'affiche que les lignes dupliquées
sort f | uniq -c | sort -rn      # classement par fréquence : LE grand classique
```

### `cut`, `paste`, `tr`, `column`

```bash
cut -d: -f1,3 /etc/passwd        # champs 1 et 3, séparateur :
cut -c1-8 f                      # caractères 1 à 8
paste a.txt b.txt                # colle côte à côte
tr 'a-z' 'A-Z' < f               # minuscules → majuscules
tr -d '\r' < win.txt             # supprime les CR
tr -s ' ' < f                    # comprime les espaces répétés
tr ' ' '\n' < f                  # un mot par ligne
column -t -s: /etc/passwd | head # mise en forme en colonnes
```

### `wc`, `head`, `tail`, `tee`, `rev`, `nl`

```bash
wc -l fichier ; ls | wc -l
tee fichier                      # copie stdin vers stdout ET vers fichier
cmd | tee sortie.log | grep ERROR    # on garde tout, on affiche le filtré
cmd | sudo tee /etc/fichier >/dev/null    # écrire un fichier root depuis un pipe
cmd | tee -a journal.log         # mode ajout
```

### `xargs` — transformer l'entrée en arguments

```bash
find . -name '*.tmp' | xargs rm                 # ✘ casse avec les espaces
find . -name '*.tmp' -print0 | xargs -0 rm      # ✔ séparateur NUL
cat urls.txt | xargs -n1 -P4 curl -sO           # 4 téléchargements en parallèle
echo a b c | xargs -I{} echo "valeur: {}"       # placeholder
```

## 5. Substitutions

| Syntaxe | Rôle |
|---------|------|
| `$(commande)` | **substitution de commande** : remplacée par sa sortie (préférez à `` `…` ``) |
| `<(commande)` | **substitution de processus** : la sortie apparaît comme un fichier |
| `$((1+2))` | calcul arithmétique |

```bash
echo "Il y a $(ls | wc -l) fichiers ici, kernel $(uname -r)"
diff <(sort a.txt) <(sort b.txt)           # compare deux sorties sans fichier temporaire
mkdir "backup-$(date +%F)"                 # backup-2024-03-12
```

## 6. Exemples d'analyse réels

```bash
# 1. Top 10 des IP les plus actives dans un log Apache/Nginx
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -10

# 2. Répartition des codes HTTP
awk '{print $9}' access.log | sort | uniq -c | sort -rn

# 3. Les 5 plus gros répertoires de /var
du -sk /var/* 2>/dev/null | sort -rn | head -5

# 4. Utilisateurs avec un shell de connexion
grep -v -E 'nologin|false' /etc/passwd | cut -d: -f1

# 5. Mots les plus fréquents d'un texte
tr -cs 'A-Za-zÀ-ÿ' '\n' < texte.txt | tr 'A-Z' 'a-z' | sort | uniq -c | sort -rn | head

# 6. Échecs de connexion SSH par IP
grep "Failed password" /var/log/auth.log | grep -o 'from [0-9.]*' | sort | uniq -c | sort -rn
```

## 7. Erreurs classiques

| Piège | Correction |
|-------|-----------|
| `cat f \| grep x` (cat inutile) | `grep x f` |
| `sort f > f` vide le fichier | `sort -o f f` |
| `uniq` sans `sort` | trier d'abord |
| `2>&1 > f` mauvais ordre | `> f 2>&1` |
| `ps aux \| grep x` trouve aussi grep | `pgrep x` ou `grep '[x]'` |
| `rm $(cat liste)` avec espaces | `xargs -d '\n' rm < liste` |
| `sudo cmd > /etc/f` (la redirection n'est pas sudo) | `cmd \| sudo tee /etc/f` |

## 8. Résumé

- 3 flux : **0** stdin · **1** stdout · **2** stderr. `>`, `>>`, `<`, `2>`, `2>&1`, `/dev/null`.
- `|` chaîne des commandes ; construisez les pipelines pas à pas.
- `grep` filtre, `sort | uniq -c | sort -rn` classe, `cut`/`tr` transforment, `tee` duplique, `xargs` convertit en arguments.
- `$(…)` capture une sortie ; `<(…)` la présente comme fichier.

## 9. Quiz

1. Quelle commande enregistre stdout dans `ok.txt` et stderr dans `ko.txt` ?
2. Pourquoi `sort data.txt > data.txt` détruit-il le fichier ?
3. Donnez le pipeline qui affiche les 5 IP les plus fréquentes (champ 1) de `access.log`.
4. Quelle différence entre `>` et `>>` ?
5. Pourquoi `sudo echo x > /etc/fichier` échoue-t-il ? Comment faire ?
6. Que fait `grep -v '^#' fichier` ?
7. À quoi sert `-print0` avec `xargs -0` ?
8. Comment comparer le contenu trié de deux fichiers sans fichier temporaire ?

<details><summary>Réponses</summary>

1. `cmd > ok.txt 2> ko.txt`
2. Le shell tronque `data.txt` avant que `sort` ne le lise. Utiliser `sort -o data.txt data.txt`.
3. `awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -5`
4. `>` écrase ; `>>` ajoute à la fin.
5. Seule `echo` est élevée, la redirection est faite par votre shell non-root. `echo x | sudo tee /etc/fichier`.
6. Affiche les lignes qui ne commencent pas par `#` (supprime les commentaires).
7. Séparer les noms par NUL pour gérer espaces et retours à la ligne dans les noms.
8. `diff <(sort a) <(sort b)`
</details>

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 05` · **Suivant** : [06 — Utilisateurs et permissions](../06-utilisateurs-et-permissions/README.md)
