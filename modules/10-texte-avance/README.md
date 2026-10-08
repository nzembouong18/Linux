# Module 10 — Traitement de texte avancé : regex, sed, awk, jq

> **Niveau** : Intermédiaire | **Durée** : 5 h (2 h 30 cours + 2 h 30 labo) | **Prérequis** : module 05
>
> **Objectifs** — À la fin de ce module vous saurez :
> - écrire des **expressions régulières** (BRE, ERE, PCRE) et les tester ;
> - transformer des flux avec **sed** (substitution, suppression, insertion, adressage) ;
> - extraire, calculer et produire des rapports avec **awk** ;
> - interroger du JSON avec **jq** ;
> - choisir le bon outil (`cut`, `grep`, `sed`, `awk`, `jq`, Python).

---

## 1. Expressions régulières

Une **regex** décrit un *motif* de texte. Trois dialectes courants :

| Dialecte | Outils | Remarque |
|----------|--------|----------|
| **BRE** (basique) | `grep`, `sed` par défaut | `+ ? | ( ) { }` doivent être échappés : `\+ \? \| \( \) \{ \}` |
| **ERE** (étendu) | `grep -E`, `sed -E`, `awk` | syntaxe moderne — **recommandé** |
| **PCRE** (Perl) | `grep -P`, `perl`, Python, PHP | `\d \w \s`, anticipations `(?=…)`, non-gourmand `.*?` |

### Atomes et quantificateurs (ERE)

| Motif | Signification |
|-------|---------------|
| `.` | un caractère quelconque |
| `[abc]` `[a-z]` `[^0-9]` | un caractère parmi / hors de |
| `[[:digit:]]` `[[:alpha:]]` `[[:space:]]` `[[:upper:]]` `[[:alnum:]]` | classes POSIX (portables, locale-aware) |
| `^` `$` | début / fin de ligne |
| `\b` | frontière de mot (GNU) · `\<` `\>` début/fin de mot |
| `*` | 0 ou plus · `+` 1 ou plus · `?` 0 ou 1 |
| `{n}` `{n,}` `{n,m}` | répétitions exactes / minimum / intervalle |
| `a|b` | a **ou** b |
| `( … )` | groupe, capturé (`\1`, `\2`…) |
| `\.` `\*` `\[` | caractère spécial littéral |

### Exemples

| Objectif | Regex ERE |
|----------|-----------|
| Ligne vide | `^$` ou `^[[:space:]]*$` |
| Commentaire | `^[[:space:]]*#` |
| Entier | `^-?[0-9]+$` |
| Date JJ/MM/AAAA | `[0-9]{2}/[0-9]{2}/[0-9]{4}` |
| Octet IPv4 (0–255) | `(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])` |
| IPv4 | `\b((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\b` |
| E-mail (simple) | `^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$` |
| Mot répété | `\b(\w+)\s+\1\b` (PCRE/GNU grep -E avec rétro-référence) |

> ⚠️ Les regex sont **gourmandes** (*greedy*) : `<.*>` capture tout de la première `<` à la dernière `>`. Utilisez `[^>]*` ou PCRE `.*?`.
> Testez vos regex : `echo "texte" | grep -Eo 'motif'`, <https://regex101.com> (choisir le dialecte).

### `grep` avancé

```bash
grep -E '^(ERROR|FATAL)' app.log
grep -Eo '[0-9]{1,3}(\.[0-9]{1,3}){3}' f       # extrait les motifs seuls
grep -P '\d{4}-\d{2}-\d{2}' f                  # PCRE
grep -P '(?<=user=)\w+' f -o                   # lookbehind : valeur après « user= »
grep -vE '^\s*(#|$)' fichier.conf              # config sans commentaires ni lignes vides
grep -rIn --include='*.py' 'TODO' src/         # récursif, ignore binaires, filtre extension
grep -c, -l, -L, -m5, -w, -x, -A -B -C
```

## 2. `sed` — l'éditeur de flux

`sed` lit l'entrée **ligne par ligne**, applique des commandes, écrit le résultat.

```text
sed [options] 'adresse commande' fichier
```

### Substitution (la commande reine)

```bash
sed 's/ancien/nouveau/' f           # 1re occurrence de chaque ligne
sed 's/ancien/nouveau/g' f          # toutes les occurrences
sed 's/ancien/nouveau/gI' f         # insensible à la casse (GNU)
sed -E 's/([0-9]{2})\/([0-9]{2})\/([0-9]{4})/\3-\2-\1/g' f      # groupes → 12/03/2024 devient 2024-03-12
sed 's#/usr/local#/opt#g' f         # autre délimiteur : # | , :
sed 's/.*/"&"/' f                  # & = tout le motif trouvé → entoure de guillemets
sed -i 's/^port=.*/port=8080/' config.ini      # -i : modifie le fichier EN PLACE
sed -i.bak 's/a/b/' f               # ... avec sauvegarde f.bak
```

### Adresses et autres commandes

| Commande | Effet | Exemple |
|----------|-------|---------|
| `p` | affiche (avec `-n`) | `sed -n '5,10p' f` |
| `d` | supprime | `sed '/^#/d' f` · `sed '1d' f` · `sed '$d' f` |
| `a\` / `i\` / `c\` | ajoute après / insère avant / remplace la ligne | `sed '/^\[main\]/a debug=1' f` |
| `y/abc/xyz/` | translittération (comme `tr`) | |
| `=` | affiche le numéro de ligne | |
| `q` | quitte | `sed 10q f` ≈ `head -10` |

Adresses : `3` (ligne 3) · `3,7` (intervalle) · `$` (dernière) · `/motif/` · `/début/,/fin/` (bloc) · `3,+2` · `1~2` (impaires) · `!` (négation).

```bash
sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' f        # supprime commentaires + lignes vides (« ; » enchaîne)
sed -n '/BEGIN/,/END/p' f                           # affiche un bloc
sed '/^server {/,/^}/ s/80/8080/' nginx.conf        # substitue seulement dans un bloc
sed -e 's/a/b/' -e 's/c/d/' f                       # plusieurs scripts
sed -n '$=' f                                       # nombre de lignes
```

## 3. `awk` — un langage pour les données tabulaires

`awk` découpe chaque ligne en **champs** (`$1`, `$2` … `$NF`, `$0` = ligne entière) et exécute des actions sur les lignes qui correspondent.

```text
awk 'motif { action }' fichier
```

| Variable | Sens |
|----------|------|
| `NR` | numéro de ligne (cumulé) · `FNR` par fichier |
| `NF` | nombre de champs de la ligne |
| `FS` / `-F` | séparateur d'entrée (défaut : espaces) |
| `OFS` | séparateur de sortie |
| `RS`, `ORS` | séparateurs d'enregistrement |

```bash
awk '{print $1}' f                          # 1re colonne
awk -F: '{print $1, $3}' /etc/passwd        # séparateur ':'
awk -F: -v OFS=';' '{print $1,$7}' /etc/passwd
awk '$3 > 1000' /etc/passwd                 # filtre sans action = afficher (ici avec -F:)
awk -F: '$3 >= 1000 && $7 !~ /nologin/ {print $1}' /etc/passwd
awk 'NR==1 || /ERROR/' app.log              # 1re ligne OU lignes contenant ERROR
awk 'NR>1' fichier.csv                      # saute l'en-tête
awk 'length($0) > 80' f                     # lignes longues
awk '{print NF}' f ; awk '{print $NF}' f    # nb de champs / dernier champ
```

### `BEGIN`, `END`, accumulateurs et tableaux associatifs

```bash
# somme et moyenne d'une colonne
awk '{s+=$3} END {print "total:", s, "moyenne:", s/NR}' ventes.txt

# comptage par clé (équivalent de sort|uniq -c, mais en une passe)
awk '{c[$1]++} END {for (ip in c) print c[ip], ip}' access.log | sort -rn | head

# somme par service (CSV avec en-tête)
awk -F';' 'NR>1 {s[$3]+=$4; n[$3]++} END {for (k in s) printf "%-10s %8.2f\n", k, s[k]/n[k]}' employes.csv

# trouver le max
awk 'NR==1 || $2 > max {max=$2; who=$1} END {print who, max}' f

# jointure de deux fichiers sur une clé
awk 'NR==FNR {nom[$1]=$2; next} {print $0, nom[$1]}' noms.txt valeurs.txt

# formatage
awk '{printf "%-15s %5d %8.2f\n", $1, $2, $3}' f
```

Fonctions utiles : `length()`, `substr(s,i,n)`, `index()`, `split(s,tab,sep)`, `sub()/gsub(/re/,"rep")`, `toupper()`, `tolower()`, `sprintf()`, `systime()`, `strftime()` (gawk).

Exemple concret — Top 5 des URL les plus lentes (nginx avec temps en dernier champ) :

```bash
awk '{u[$7]+=$NF; n[$7]++} END{for(k in u) printf "%.3f %s\n", u[k]/n[k], k}' access.log | sort -rn | head -5
```

## 4. `cut`, `tr`, `sort`, `join`, `comm`, `paste`, `column` — rappel du coffre à outils

```bash
cut -d';' -f1,3 employes.csv
tr -s ' ' < f | cut -d' ' -f2
sort -t';' -k4,4nr employes.csv | head -3        # tri numérique décroissant sur le 4e champ
join -t';' <(sort a.csv) <(sort b.csv)           # jointure sur le 1er champ
comm -12 <(sort a) <(sort b)                     # lignes communes (-23 : propres à a)
paste -d, a.txt b.txt
column -t -s';' employes.csv                     # joli tableau
```

## 5. `jq` — JSON en ligne de commande

Les API et les outils modernes (`docker inspect`, `kubectl -o json`, `aws`, `ip -j`, `journalctl -o json`) parlent JSON.

```bash
cat << 'EOF' > inv.json
{"items":[{"nom":"clou","stock":120,"prix":0.05},{"nom":"vis","stock":3,"prix":0.1}]}
EOF

jq . inv.json                                 # mise en forme (pretty-print) + validation
jq '.items[0].nom' inv.json                   # "clou"
jq -r '.items[].nom' inv.json                 # -r : sans guillemets  → clou \n vis
jq '.items | length' inv.json                 # 2
jq '.items[] | select(.stock < 5)' inv.json   # filtre
jq -r '.items[] | "\(.nom): \(.stock)"' inv.json            # interpolation
jq '[.items[] | .stock * .prix] | add' inv.json             # valeur totale du stock
jq '.items |= map(.stock += 10)' inv.json                   # modifie
jq -c '.items[]' inv.json                                   # une ligne JSON par objet
jq -r '.items[] | [.nom,.stock] | @csv' inv.json            # export CSV
ip -j addr | jq -r '.[] | select(.ifname!="lo") | .ifname'
```

Autres : `yq` (YAML), `xmlstarlet` (XML), `csvkit`/`miller` (CSV), `pup` (HTML).

## 6. Choisir son outil

| Besoin | Outil |
|--------|-------|
| Trouver des lignes | `grep` |
| Colonnes simples à séparateur fixe | `cut` |
| Remplacer / supprimer / insérer | `sed` |
| Calculs, regroupements, rapports | `awk` |
| Structure JSON | `jq` |
| Traitement complexe, > 50 lignes, structures imbriquées | **Python** |

## 7. Bonnes pratiques

1. Construire le pipeline **pas à pas**, en vérifiant chaque étape.
2. Ne modifiez jamais en place sans sauvegarde : `sed -i.bak`, ou testez d'abord sans `-i`.
3. Préférez `-E` (ERE) pour des regex lisibles.
4. Attention aux **locales** : `LC_ALL=C` pour des tris/classes prévisibles et plus rapides.
5. Fichiers CSV réels (guillemets, virgules dans les champs) : n'utilisez pas `cut`/`awk -F,` naïfs, mais `csvkit`, `mlr` ou Python `csv`.
6. Documentez les regex complexes dans le script (commentaire + exemple).

## 8. Résumé

- Regex ERE : `[]`, `()`, `|`, `{n,m}`, `^$`, `\b` ; testez avec `grep -Eo`.
- `sed 's/re/rep/g'` + adresses ; `-i` pour modifier en place, `-n … p` pour extraire.
- `awk -F… 'cond {action} END{…}'` : champs `$n`, `NR`, `NF`, tableaux associatifs.
- `jq` : `.champ`, `.[]`, `select()`, `map()`, `-r`.

## 9. Quiz

1. Écrivez la commande sed qui supprime les lignes vides et les commentaires d'un fichier.
2. Comment extraire uniquement la 3ᵉ colonne d'un CSV séparé par `;` avec awk ?
3. Quelle commande donne le total de la colonne 4, en ignorant l'en-tête ?
4. Pourquoi `sed 's/a.*b/X/'` donne-t-il parfois un résultat surprenant ?
5. Comment transformer `2024-03-12` en `12/03/2024` avec sed ?
6. Comment afficher les noms (sans guillemets) du tableau `users` d'un JSON ?
7. Quelle différence entre `awk '/ERROR/'` et `grep ERROR` ? Quand préférer awk ?
8. Comment éviter qu'un `sed -i` ne vous fasse perdre le fichier d'origine ?

<details><summary>Réponses</summary>

1. `sed -E '/^[[:space:]]*(#|$)/d' fichier`
2. `awk -F';' '{print $3}' fichier`
3. `awk -F';' 'NR>1 {s+=$4} END{print s}' fichier`
4. Quantificateur gourmand : `.*` s'étend au dernier `b` de la ligne. Utiliser `[^b]*`.
5. `sed -E 's/([0-9]{4})-([0-9]{2})-([0-9]{2})/\3\/\2\/\1/'`
6. `jq -r '.users[].name' fichier.json`
7. Équivalents ici ; awk devient préférable dès qu'il faut des champs, des conditions numériques ou des calculs.
8. `sed -i.bak …` (sauvegarde) ou versionner avec git.
</details>

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 10` · **Suivant** : [11 — Réseau : fondamentaux](../11-reseau-fondamentaux/README.md)
