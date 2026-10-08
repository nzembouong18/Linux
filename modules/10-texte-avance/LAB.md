# Labo 10 — Atelier de traitement de données

> **Durée** : 2 h 30 · **Difficulté** : ⭐⭐⭐ · **Prérequis** : module 10 · `jq` installé (`sudo apt install jq`)

## Contexte

Le service informatique reçoit chaque jour des fichiers de toutes sortes : export RH, journal applicatif, configuration SSH, inventaire JSON… À vous de produire les résultats attendus **avec `grep`, `sed`, `awk` et `jq`**, sans modifier les fichiers sources.

## Mise en place

```bash
./lab setup 10
cd ~/labs/10 && ls
```

## Tâches

### A. `awk` sur `employes.csv` (séparateur `;`, 1ʳᵉ ligne = en-tête : `id;nom;service;salaire;ville`)
1. `total_it.txt` : somme des salaires du service **IT** (un nombre seul).
2. `moyennes.txt` : une ligne par service au format `service moyenne` (moyenne avec **2 décimales**, point décimal), ordre libre.
3. `ville_top.txt` : le nom de la **ville** qui compte le plus d'employés (un mot).

### B. `sed` sur `config.conf`
4. `config_propre.conf` : la configuration **sans commentaires** (lignes commençant par `#`, espaces éventuels) **ni lignes vides**.
5. `config_modifiee.conf` : copie de `config.conf` avec `Port 22` → `Port 2222`, `PermitRootLogin yes` → `no`, `PasswordAuthentication yes` → `no` (le reste, y compris les commentaires, est inchangé).
6. `dates_iso.txt` : `dates.txt` dont toutes les dates `JJ/MM/AAAA` sont converties en `AAAA-MM-JJ`.

### C. `grep` / regex
7. `ips_uniques.txt` : les adresses **IPv4 valides** (chaque octet 0–255) de `app.log`, triées, sans doublon. (`999.12.3.4` n'est pas valide.)
8. `emails_valides.txt` : les lignes de `emails.txt` qui sont des adresses e-mail valides.

### D. `jq` sur `inventaire.json`
9. `rupture.txt` : le nom des articles dont le **stock est inférieur à 5**, un par ligne, sans guillemets.
10. `valeur_stock.txt` : la valeur totale du stock (somme de `stock × prix`), un nombre seul.

## Validation

```bash
./lab check 10
```

<details><summary>💡 Indices</summary>

- A2 : `awk -F';' 'NR>1 {s[$3]+=$4; n[$3]++} END {for (k in s) printf "%s %.2f\n", k, s[k]/n[k]}'`
- A3 : `cut -d';' -f5 | tail -n +2 | sort | uniq -c | sort -rn | head -1`
- B5 : `sed -e 's/^Port 22$/Port 2222/' -e …`
- C7 : `grep -Eo '\b((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\b' | sort -u`
- D10 : `jq '[.items[] | .stock * .prix] | add'`
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/10
awk -F';' '$3=="IT" {s+=$4} END{print s}' employes.csv > total_it.txt
awk -F';' 'NR>1 {s[$3]+=$4; n[$3]++} END {for (k in s) printf "%s %.2f\n", k, s[k]/n[k]}' employes.csv > moyennes.txt
awk -F';' 'NR>1 {c[$5]++} END {for (v in c) print c[v], v}' employes.csv | sort -rn | head -1 | cut -d' ' -f2 > ville_top.txt
sed -E '/^[[:space:]]*(#|$)/d' config.conf > config_propre.conf
sed -e 's/^Port 22$/Port 2222/' -e 's/^PermitRootLogin yes/PermitRootLogin no/' -e 's/^PasswordAuthentication yes/PasswordAuthentication no/' config.conf > config_modifiee.conf
sed -E 's#([0-9]{2})/([0-9]{2})/([0-9]{4})#\3-\2-\1#g' dates.txt > dates_iso.txt
grep -Eo '\b((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\b' app.log | sort -u > ips_uniques.txt
grep -E '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' emails.txt > emails_valides.txt
jq -r '.items[] | select(.stock < 5) | .nom' inventaire.json > rupture.txt
jq '[.items[] | .stock * .prix] | add' inventaire.json > valeur_stock.txt
```
</details>

## Pour aller plus loin

- Produisez avec `awk` un rapport aligné (`printf "%-10s %8.2f"`) du salaire moyen par ville.
- Avec `sed`, insérez la ligne `# Géré par la formation Linux` en tête de `config.conf`.
- Transformez `employes.csv` en JSON avec `jq -R` / `awk`.

## Nettoyage

```bash
./lab reset 10
```
